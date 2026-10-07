# Technical decisions, logic, and gas — Module 16

**Language:** English · [Español](./DECISIONES-Y-LOGICA-ES.md)

A guide to understand **what was built**, **why** it was designed this way, **how** a message flows, and **what can still be improved in gas** without rewriting the module.

References: [`GAS-EN.md`](./GAS-EN.md) · [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md) · [`planificacion-EN.md`](./planificacion-EN.md)

---

## 1. What this is (in one sentence)

An **arbitrary message passing (AMP)** protocol: you send a `payload` (bytes) from a messenger on chain A; a transport (mock / LayerZero V2 / CCIP) carries it to chain B; the destination messenger validates source + peer + anti-replay and optionally calls an app (`RemoteStakeReceiver`).

It is not a token bridge (that is module 09). The value here is the **authenticated message**, not ERC-20 mint/burn.

---

## 2. Technical decisions (and why)

### 2.1 Own core + adapters, not "just LZ/CCIP"

| Decision | Discarded alternative | Why |
|----------|-----------------------|-----|
| `CrossChainMessenger` as the AMP core | Logic only inside each adapter | A single source of truth for peers, fees, idempotency, and the app hook |
| `ITransportAdapter` (`quote` / `dispatch`) | Coupling send to LZ or CCIP | Local tests with `MockTransportAdapter` / `MockRelayer` without real endpoints |
| Thin LZ V2 and CCIP adapters | Reimplementing DVNs / CCIP fee tokens | Lab/v1 scope: interfaces + mocks; packed wire towards the messenger |

**Idea:** the messenger does not know whether the packet traveled over LZ, CCIP, or a test relayer. It only talks to the adapter and to an authorized `deliverer`.

### 2.2 Trust: peers + deliverer (no light client)

| Decision | Why |
|----------|-----|
| `peers[chainId] → bytes32` | Anti-spoofing of `srcAddress`: only the configured remote messenger can "sign" the logical source |
| Only `deliverer` calls `receivePacket` | Separates "who pushes the packet on-chain" from "who the remote peer is" |
| `Ownable2Step` owner rotates peers / adapter / deliverer / receiver | Safe admin rotation without accidental single-step transfers |

**Conscious tradeoff:** v1 **trusts** the deliverer (and the endpoint/router on LZ/CCIP paths). There is no SPV/zk. This is documented as informational in the SWC audit (trust / ops).

### 2.3 Dual packet format: ABI for tests, packed Yul for the wire

| Format | Use |
|--------|-----|
| `abi.encode` / `abi.decode` | Portable codec, tests, clarity |
| `encodePacked` + `decodeYul` (fixed 120 B + payload) | LZ/CCIP adapter wire (less gas) |

**Tradeoff:** packed requires the exact same layout on source and destination; ABI is safer for interoperating with third parties, but more expensive.

### 2.4 Message operational security

| Mechanism | Error / effect |
|-----------|----------------|
| `srcChainId` + `srcAddress` vs `peers` | `InvalidSourceSender` |
| Local `dstChainId` / `dstAddress` | `UnsupportedChain` / `InvalidPeer` |
| `processedMessages[messageHash]` | `MessageAlreadyProcessed` (anti-replay) |
| `quote` + `msg.value >= fee` + refund | `InsufficientFee` / `EthRefundFailed` |
| `nonReentrant` on send/receive | SWC-107 |
| Custom errors | Gas + clarity (suite rule) |
| Fixed pragma `0.8.24` | No floating pragma |

Order in `receivePacket` (CEI): validate → hash → mark processed → call app → event.  
If the app reverts, the **whole** tx reverts and the hash is **not** marked (retry possible).

### 2.5 Decoupled app

`IMessageReceiver.onMessageReceived(...)` is optional (`receiver` may be `address(0)`).  
Demo: `RemoteStakeReceiver` interprets the payload (remote stake). The messenger knows nothing about staking.

### 2.6 Tooling

- Foundry, fuzz ≥ 1000 on libs, optional dual-fork, `Deploy` + `SimulateRelay`.
- Optimizer `runs = 10_000` + `via_ir` (send/receive hot path).

---

## 3. System logic

### 3.1 Pieces and roles

```
User / dApp
    │  send(dstChainId, payload) + ETH fee
    ▼
CrossChainMessenger (source)
    │  builds Packet, quote, dispatch(fee)
    ▼
ITransportAdapter  ──►  LZ endpoint / CCIP router / MockRelayer
    │
    │  (off-chain or mock deliver)
    ▼
Deliverer / Adapter (destination)  ──►  receivePacket(Packet)
    ▼
CrossChainMessenger (destination)
    │  auth + peers + anti-replay
    ▼
IMessageReceiver (optional)  ──►  e.g. RemoteStakeReceiver
```

### 3.2 Send (source chain) — step by step

1. Does `peers[dstChainId]` exist? If not → `UnsupportedChain`.
2. Is there an `adapter`? If not → `ZeroAddress`.
3. `fee = adapter.quote(...)`; if `msg.value < fee` → `InsufficientFee`.
4. `outboundNonces[dst]++` (unchecked after safe logic).
5. Build the `Packet`: `src = localChainId / _selfPeer`, `dst = dstChainId / remote peer`, `nonce`, `payload`.
6. `messageHash = PacketCodec.messageHash(packet)` (for the event / correlation).
7. `adapter.dispatch{value: fee}(...)`.
8. `FeeRefundLib.refundExcessAssembly(msg.sender, fee)` — excess back to whoever paid.
9. Emit `MessageSent`.

### 3.3 Receive (destination chain) — step by step

1. Only if `msg.sender == deliverer` → otherwise `UnauthorizedCaller`.
2. `packet.dstChainId == localChainId` and `dstAddress == _selfPeer`.
3. `peers[srcChainId] == packet.srcAddress` → otherwise `InvalidSourceSender`.
4. `messageHashCalldata(packet)` (hash without copying the struct to memory).
5. If already processed → `MessageAlreadyProcessed`.
6. **Effects:** `processedMessages[hash] = true`.
7. **Interactions:** if there is a `receiver`, `onMessageReceived(srcChainId, srcAddress, payload)`.
8. Emit `MessageReceived`.

### 3.4 Transport paths

| Path | Who delivers | Extra check in adapter |
|------|--------------|------------------------|
| Mock | `MockRelayer` / deliverer | Nothing beyond the messenger |
| LayerZero V2 | `lzReceive` → decodeYul → `receivePacket` | `msg.sender == endpoint` + LZ peer (`lzPeers`) |
| CCIP | `ccipReceive` → decodeYul → `receivePacket` | `msg.sender == router` + CCIP peer |

Double auth layer on LZ/CCIP: transport (endpoint/router + adapter peer) **and** messenger (deliverer + AMP peers).

### 3.5 RemoteStake demo

The source sends an ABI payload with a stake action; the destination `RemoteStakeReceiver` updates local balances after a message **already authenticated** by the messenger. It does not move tokens cross-chain by itself: it demonstrates **controlled remote execution**.

---

## 4. Gas: what has already been done

Baseline in [`GAS-EN.md`](./GAS-EN.md) (Phase 7):

| Technique | Approximate effect |
|-----------|--------------------|
| `decodeYul` vs `abi.decode` | ~**−1 040** gas (adapter wire) |
| `refundExcessAssembly` vs `.call` | ~**−64** gas (isolated refund) |
| `messageHashCalldata` on receive | Avoids a memory copy of the `Packet` |
| Immutable `_selfPeer` | No `addressToBytes32(this)` per tx |
| `encodePacked` in Yul | No multi-alloc `bytes.concat` |
| Cached `adapter_` / `receiver_` | Fewer SLOADs |
| Custom errors + optimizer 10k + via_ir | Cheaper reverts and inlining |

Send exact fee ~**294 919**; e2e receive (with mocks) ~**362 756** (includes send + relay + mock app in the test).

---

## 5. Can gas be improved further?

Yes, but with clear tradeoffs. Ordered from **most realistic** to **most aggressive / risky**.

### 5.1 Reasonable improvements (v1.1)

| Idea | Where | Note |
|------|-------|------|
| Skip the internal `quote` if the caller passes `maxFee` / a signed fee | `send` | Today every `send` calls `quote` again (an extra external/view call). A `sendWithFee(fee)` or trusting the client fee + checking `msg.value >= fee` saves one call if the adapter quote is expensive |
| Do not emit the full `payload` in events | `MessageSent` / `MessageReceived` | Index only `messageHash` + lengths; the payload is read off-chain. Large savings with big payloads |
| Packed also on the mock path (if ABI is not needed) | MockRelayer | Consistency and less ABI decoding in the lab |
| `transient storage` (Cancun) for ephemeral flags | Only if the protocol needs it | Does not apply to `processedMessages` (must be permanent) |
| Reduce `processedMessages` SSTOREs with a bitmap / packing | Current mapping is clear | Bitmaps per `(srcChain, nonce)` can save gas if the id model changes; today the id is the hash of the full packet |

### 5.2 Medium improvements (more design)

| Idea | Tradeoff |
|------|----------|
| Message identity = `(srcChainId, srcAddress, nonce)` instead of the hash of the whole packet | Less hashing; nonce uniqueness must be guaranteed and the payload is left out of the id (replaying the same nonce with another payload becomes impossible if the nonce is monotonic per peer) |
| A single messenger+adapter contract in the lab | Fewer external calls; worse separation and testing |
| Remove `ReentrancyGuard` and rely only on CEI | Saves the guard SLOAD/SSTORE; **not recommended** while there is a callback to `receiver` |
| End-to-end `calldata` without `Packet memory` in `send` | Today a `Packet memory` is built for hash + dispatch; streaming the encoding to the adapter could reduce memory usage |

### 5.3 Aggressive improvements (only if measured and the complexity is accepted)

| Idea | Risk |
|------|------|
| Custom storage layout / Yul for the whole `receivePacket` | Harder to read and audit |
| Remove the second peer check in the adapter *or* in the messenger | Savings, but defense in depth is lost |
| Fee cached in storage per destination | Stale fees / economic griefing |

### 5.4 What **not** to "optimize" blindly

- **Removing anti-replay or peers** for gas → breaks the security model.
- **Marking processed after** the app → opens reentrancy / double execution if the receiver is malicious.
- **Using `transfer`/`send` for the refund** → 2300 gas limit; forbidden by the suite.
- Misreading the gas harness: `messageHashCalldata` may look "more expensive" in the test because it re-encodes the struct; in production, receive already gets `calldata`.

### 5.5 Where the real cost is

On LZ/CCIP e2e paths, most of the gas is not the Yul codec: it is **storage** (`processedMessages`, nonces, peers), **external calls** (endpoint/router/messenger/app), and **payload size**. Optimizing only the decode without touching events/storage/external calls has diminishing returns.

Practical recommendation: measure with `forge snapshot` / `--gas-report` after each change; prioritize **events without payload** and **avoiding the double quote** if you are after the next realistic −5–15% on `send`.

---

## 6. Quick mental map

| Question | Short answer |
|----------|--------------|
| Who can send? | Anyone who pays the fee; the message source is **this** messenger (`_selfPeer`) |
| Who can receive? | Only the `deliverer` (or the adapter configured as such) |
| What prevents spoofing? | `peers[srcChainId] == srcAddress` (+ LZ/CCIP peers in the adapters) |
| What prevents replay? | `processedMessages[messageHash]` |
| Where does business logic live? | In `IMessageReceiver`, not in the messenger |
| LZ vs CCIP vs mock? | Same core; only the adapter and who acts as deliverer change |

---

## 7. Key files for reading the code

| File | Role |
|------|------|
| `src/CrossChainMessenger.sol` | Send / receive / peers / fees |
| `src/libraries/PacketCodec.sol` | ABI + packed + hashes |
| `src/libraries/FeeRefundLib.sol` | Refund `.call` vs Yul |
| `src/libraries/PeerLib.sol` | Peer / address checks |
| `src/adapters/LayerZeroV2Adapter.sol` | Packed LZ wire |
| `src/adapters/CCIPAdapter.sol` | Packed CCIP wire |
| `src/apps/RemoteStakeReceiver.sol` | Remote execution demo |
| `test/UnauthorizedSender.t.sol` | Spoofing must revert |
| `test/ReplayProtection.t.sol` | Replay must revert |
| `test/gas/Codec.gas.t.sol` | Gas baseline |

---

*Human-oriented reading guide for the closed v1 (phases 0–7). Gas figures: 2026-09-13 baseline in `doc/GAS-EN.md`.*
