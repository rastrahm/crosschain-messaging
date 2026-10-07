# Planning — Module 16: Cross-Chain Messaging & Interoperability

**Language:** English · [Español](./planificacion-ES.md)

**Status:** Phases **0–7** ✅ (module v1 closed).  
**Note:** The per-phase authorization rule applied during construction; v1 has no pending phases.

---

## 1. Goal

Build a multi-chain **arbitrary message passing (AMP)** protocol that can:

- Send ABI-encoded payloads from a source chain to a destination chain.
- Synchronize state (e.g. balances / flags) between authorized peers.
- Execute controlled remote calls (demo: staking / liquidity rebalancing).
- Integrate two transport standards: **LayerZero Endpoint V2** and **Chainlink CCIP** (`IRouterClient`), plus a **mock relayer** for local tests.
- Apply security controls: `srcChainId` + `srcAddress` verification, anti-replay by message hash, native fee quoting, and refund of the excess to `msg.sender`.

Stack: **Foundry + Solidity `0.8.24`** (fixed pragma). A Next.js frontend is **out of v1 scope**.

---

## 2. Scope

| Included (v1) | Excluded (v1) |
|---------------|---------------|
| `CrossChainMessenger` — send / receive / peers / idempotency | Lock/mint token bridge (module 09) |
| On-chain trusted peers (`peers[chainId]`) | Light client / SPV / zk proofs |
| `PacketCodec` — ABI + packed Yul + `messageHash` | Production off-chain relayer |
| LayerZero V2 adapter (interfaces + mock endpoint) | Custom LZ DVN / Executor on mainnet |
| Chainlink CCIP adapter (`ICCIPRouter` + mock router) | CCIP token pools / complex ERC-20 fee tokens |
| Demo app: `RemoteStakeReceiver` (remote stake via message) | Next.js frontend (App Router) |
| `MockRelayer` + dual-fork / in-process | DAO governance of the peer set |
| Tests: unauthorized, replay, quote/refund, gas ABI vs Yul | Automatic multi-hop routing / dedicated `Messaging.fuzz.t.sol` |

---

## 3. Stack and technical constraints

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- **Exact** Solidity `0.8.24` (no floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20` if applicable).
- Foundry: unit + fuzz (`runs >= 1000`) + multi-fork + gas reports.
- **Custom errors** (no `require` with strings).
- Strict CEI; ETH via `.call{value: ...}("")` or Yul `call` (never `transfer`/`send`).
- NatSpec on every public/external API.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests first in contract phases; explicit logic branch coverage.

### Module 16 (local `.cursorrules`)

- Standards: LayerZero Endpoint V2, CCIP `IRouterClient`-like, custom packets (ABI + packed).
- Spoofing: verify `srcChainId` + `srcAddress`; revert `InvalidSourceSender()`.
- Fees: `quote` before dispatch; safe refund of unused ETH to `msg.sender` (`refundExcessAssembly`).
- Idempotency: `mapping(bytes32 => bool) processedMessages`.
- Payloads: app-side `abi.encode` / `abi.decode`; adapter wire with `encodePacked` / `decodeYul`.

### Next.js (`nextjs.cursorrules`) — post-v1

- If a UI is added: App Router, Zod, Vitest + RTL, JSDoc, no `any`, no prop drilling.
- Not part of phases 0–7.

---

## 4. Architecture (v1 implemented)

```
16-crosschain-messaging/
├── README-ES.md / README-EN.md
├── doc/
│   ├── README-{ES,EN}.md
│   ├── planificacion-{ES,EN}.md
│   ├── diagrama-de-clases-{ES,EN}.md
│   ├── diagrama-de-flujo-{ES,EN}.md
│   ├── flujograma-{ES,EN}.md
│   ├── SWC-AUDIT-{ES,EN}.md
│   ├── GAS-{ES,EN}.md
│   └── DECISIONES-Y-LOGICA-{ES,EN}.md
├── src/
│   ├── CrossChainMessenger.sol          # AMP core + peers + idempotency
│   ├── apps/
│   │   └── RemoteStakeReceiver.sol      # remote execution demo
│   ├── adapters/
│   │   ├── LayerZeroV2Adapter.sol       # packed Yul wire
│   │   └── CCIPAdapter.sol              # packed Yul wire
│   ├── interfaces/
│   │   ├── ICrossChainMessenger.sol
│   │   ├── IMessageReceiver.sol
│   │   ├── ITransportAdapter.sol
│   │   ├── ILayerZeroEndpointV2.sol     # + ILayerZeroReceiver
│   │   └── ICCIPRouter.sol              # + IAny2EVMMessageReceiver
│   ├── libraries/
│   │   ├── PacketCodec.sol              # ABI + packed + messageHash(Calldata)
│   │   ├── PeerLib.sol
│   │   └── FeeRefundLib.sol             # refundExcess + refundExcessAssembly
│   ├── errors/
│   │   └── MessagingErrors.sol
│   └── mocks/
│       ├── MockTransportAdapter.sol
│       ├── MockLayerZeroEndpoint.sol
│       ├── MockCCIPRouter.sol
│       ├── MockRelayer.sol
│       ├── MockMessageReceiver.sol
│       └── RejectETH.sol
├── test/
│   ├── helpers/{MessagingTestBase,ForkHelper,LibHarnesses}.sol
│   ├── libraries/{PacketCodec,PeerLib,FeeRefundLib}.t.sol
│   ├── CrossChainMessenger.t.sol
│   ├── UnauthorizedSender.t.sol
│   ├── ReplayProtection.t.sol
│   ├── adapters/{LayerZeroV2,CCIP}.t.sol
│   ├── apps/RemoteStakeReceiver.t.sol
│   ├── fork/DualFork.t.sol
│   └── gas/Codec.gas.t.sol
├── script/
│   ├── Deploy.s.sol
│   └── SimulateRelay.s.sol
├── foundry.toml
├── remappings.txt
├── .env.example
├── .gitignore
└── .gas-snapshot
```

### Contracts and responsibilities

| Artifact | Responsibility |
|----------|----------------|
| `CrossChainMessenger` | Quote, send, receive; peers; `processedMessages`; `_selfPeer`; CEI + reentrancy |
| `ITransportAdapter` | LZ / CCIP / mock transport abstraction |
| `LayerZeroV2Adapter` | Endpoint V2 dispatch/receive; `encodePacked`/`decodeYul` wire |
| `CCIPAdapter` | CCIP router dispatch/receive; same packed wire |
| `PacketCodec` | ABI + packed + `messageHash` / `messageHashCalldata` |
| `PeerLib` | address↔bytes32; `requirePeer` / `requireConfiguredPeer` |
| `FeeRefundLib` | `refundExcess` (`.call`) + `refundExcessAssembly` (Yul, send) |
| `RemoteStakeReceiver` | Remote stake/unstake from the decoded payload |
| `MockTransportAdapter` | Fixed fee + last packet (unit / dual-fork) |
| `MockRelayer` | In-process delivery to `receivePacket` |
| `MessagingErrors` | Module custom errors |

---

## 5. Custom errors (module)

```solidity
error InvalidSourceSender();      // mandatory (.cursorrules)
error MessageAlreadyProcessed();  // replay / idempotency
error InsufficientFee();          // msg.value < quote
error EthRefundFailed();          // failed refund .call
error ZeroAddress();
error InvalidPeer();
error InvalidPayload();
error UnauthorizedCaller();       // unauthorized adapter/endpoint
error UnsupportedChain();
error ZeroAmount();
```

Mandatory for the module: `InvalidSourceSender()`. The rest support fees, peers, and idempotency.

---

## 6. Phase governance (mandatory authorization)

| Rule | Detail |
|------|--------|
| **Gate** | No code for a phase is written until: *"I authorize Phase N"*. |
| **Delivery** | On close: acceptance checklist + touched files. |
| **Block** | New scope → document it and wait for a new authorization. |
| **TDD** | In contract phases: tests first, then implementation. |

### Phase board

| Phase | Name | Status | Authorization |
|-------|------|--------|---------------|
| 0 | Foundry setup + structure + deps | ✅ Completed | ✅ Authorized |
| 1 | Errors + libs (`PacketCodec`, `PeerLib`, `FeeRefundLib`) | ✅ Completed | ✅ Authorized |
| 2 | `CrossChainMessenger` + mock relayer (unit) | ✅ Completed | ✅ Authorized |
| 3 | LayerZero V2 adapter + mocks | ✅ Completed | ✅ Authorized |
| 4 | Chainlink CCIP adapter + mocks | ✅ Completed | ✅ Authorized |
| 5 | `RemoteStakeReceiver` + Unauthorized + Replay | ✅ Completed | ✅ Authorized |
| 6 | Dual-fork / multi-fork + `SimulateRelay` | ✅ Completed | ✅ Authorized |
| 7 | Gas ABI vs Yul + Deploy + NatSpec / SWC | ✅ Completed | ✅ Authorized |

---

## 7. Phase details

### Phase 0 — Foundry setup ✅

**Goal:** a compilable repo aligned with the suite.

1. Foundry scaffold (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`, `[rpc_endpoints]` for forks).
2. Dependencies: `forge-std`, OpenZeppelin v5; minimal LZ V2 and CCIP stubs/interfaces (no full SDK unless needed).
3. Folders `src/{adapters,apps,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas,adapters,apps}`, `script/`, `doc/`.
4. Minimal stub + smoke test; `.env.example` (source/destination RPCs); `README.md`.

**Exit criterion:** `forge build` and `forge test` green.

**Done (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, RPC `mainnet` / `src` / `dst`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencies in `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copied from module 15).
- Folders `src/{adapters,apps,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas,adapters,apps}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + IERC20 remapping).
- Stub `script/Deploy.s.sol` (Phase 7), `.env.example`, `README.md`, existing `doc/`.
- `forge build` OK; `forge test` → **2 PASS**.

---

### Phase 1 — Errors + libraries ✅

**Goal:** packet, peer, and refund primitives.

1. TDD: `PacketCodec` (encode/decode round-trip, stable `messageHash`).
2. `PeerLib`: pack address → bytes32; zero validation.
3. `FeeRefundLib`: refund the excess; revert `EthRefundFailed` if the recipient rejects it.
4. `MessagingErrors.sol` with all custom errors from §5.

**Exit criterion:** libs green; encode/decode fuzz ≥ 1000 where applicable.

**Done (2026-09-13):**
- `src/errors/MessagingErrors.sol` — 10 custom errors (incl. `InvalidSourceSender`).
- `src/libraries/PacketCodec.sol` — `Packet`, ABI `encode`/`decode`, `messageHash`, `encodePacked` + `decodeYul`.
- `src/libraries/PeerLib.sol` — pack/unpack, `requireNonZero`, `requireConfiguredPeer`, `requirePeer`.
- `src/libraries/FeeRefundLib.sol` — `refundExcess` with `.call` + `InsufficientFee` / `EthRefundFailed`.
- `RejectETH` mock; harnesses in `test/helpers/LibHarnesses.sol`.
- Tests: `PacketCodec.t.sol`, `PeerLib.t.sol`, `FeeRefundLib.t.sol` (1000-run fuzz each where applicable).
- `Placeholder` stub removed.
- **`forge test` → 27 PASS**.

---

### Phase 2 — CrossChainMessenger + mock relayer ✅

**Goal:** local AMP core without real LZ/CCIP.

1. Tests: `quote` → `send` with fee; receive from a valid peer; invalid peer → `InvalidSourceSender`.
2. Idempotency: second `receive` of the same hash → `MessageAlreadyProcessed`.
3. Refund of unused ETH to `msg.sender`.
4. `MockRelayer` delivers in-process between two instances (source/destination).

**Exit criterion:** messenger unit + refund + peer check green.

**Done (2026-09-13):**
- Interfaces: `ICrossChainMessenger`, `IMessageReceiver`, `ITransportAdapter`.
- `CrossChainMessenger`: Ownable2Step + ReentrancyGuard; peers; `processedMessages`; quote/send/receive; setPeer/Adapter/Deliverer/Receiver.
- Mocks: `MockTransportAdapter` (fixed fee), `MockRelayer`, `MockMessageReceiver`.
- In-process dual-messenger `MessagingTestBase` (CHAIN_A ↔ CHAIN_B).
- `CrossChainMessenger.t.sol`: refund, e2e relay, unauthorized, spoof, replay, dst checks.
- **`forge test` → 39 PASS**.

---

### Phase 3 — LayerZero V2 adapter ✅

**Goal:** wire an Endpoint V2-style transport with a mock.

1. Minimal interfaces + `MockLayerZeroEndpoint`.
2. Adapter: send with options/fees; mocked `_lzReceive` / equivalent.
3. Only the configured endpoint can invoke the receive path (`UnauthorizedCaller`).

**Exit criterion:** LZ adapter tests + messenger integration green.

**Done (2026-09-13):**
- `ILayerZeroEndpointV2` + structs `Origin` / `MessagingParams` / `MessagingFee` / `MessagingReceipt` + `ILayerZeroReceiver`.
- `MockLayerZeroEndpoint`: fixed fee, `registerOApp`, `pending` queue, `deliver` / `deliverLast`.
- `LayerZeroV2Adapter`: `quote`/`dispatch` (messenger only), `lzReceive` (endpoint only), `lzPeers` per eid.
- `test/adapters/LayerZeroV2.t.sol`: e2e send→deliver, endpoint/messenger auth, LZ peer spoof, replay.
- **`forge test` → 47 PASS**.

---

### Phase 4 — Chainlink CCIP adapter ✅

**Goal:** wire an `IRouterClient`-style transport with a mock.

1. `MockCCIPRouter` + CCIP-like message (selector, sender, data).
2. Adapter: mocked `ccipSend` / `ccipReceive`; fee quote + refund.
3. Remote sender verification against `ccipPeers` / messenger peers.

**Exit criterion:** CCIP adapter tests + integration green.

**Done (2026-09-13):**
- `ICCIPRouter` + `EVM2AnyMessage` / `Any2EVMMessage` + `IAny2EVMMessageReceiver`.
- `MockCCIPRouter`: fixed fee, `registerOApp`, `pending` queue, `deliver` / `deliverLast`.
- `CCIPAdapter`: `quote`/`dispatch` (messenger only), `ccipReceive` (router only), `ccipPeers` per selector.
- `test/adapters/CCIP.t.sol`: e2e send→deliver, router/messenger auth, peer spoof, replay.
- **`forge test` → 55 PASS**.

---

### Phase 5 — RemoteStakeReceiver + Unauthorized + Replay ✅

**Goal:** remote execution demo and the module security matrix.

| Type | What it validates |
|------|-------------------|
| Unauthorized sender | Valid payload, `srcAddress` not a peer → `InvalidSourceSender` |
| Replay | Same `messageHash` twice → `MessageAlreadyProcessed` |
| App | Remote stake payload decoded and applied exactly once |

**Exit criterion:** `UnauthorizedSender.t.sol`, `ReplayProtection.t.sol`, app e2e green.

**Done (2026-09-13):**
- `RemoteStakeReceiver`: stake/unstake via `abi.encode(user, amount, isStake)`; `messenger` only.
- `UnauthorizedSender.t.sol`: peer spoof, chain without peer, caller not deliverer.
- `ReplayProtection.t.sol`: same packet/hash, different nonces OK.
- `RemoteStakeReceiver.t.sol`: e2e stake/unstake, zero checks, no double-stake.
- **`forge test` → 70 PASS**.

---

### Phase 6 — Dual-fork + SimulateRelay ✅

**Goal:** simulate source dispatch and destination execution with forks (or skip without RPC).

1. `DualFork.t.sol`: two forks (e.g. Sepolia / another) or an Anvil multi-chain helper.
2. `SimulateRelay.s.sol`: documents the event → relay → receive path.
3. Clean skip if `SRC_RPC_URL` / `DST_RPC_URL` are missing.

**Exit criterion:** optional fork pass; documented script.

**Done (2026-09-13):**
- `ForkHelper`: creates a dual-fork from `SRC_RPC_URL` / `DST_RPC_URL`; `_skipIfNoDualFork`.
- `test/fork/DualFork.t.sol`: send on source + stake on destination; replay on destination; **2 SKIP** without RPC.
- `script/SimulateRelay.s.sol`: in-process simulation send → relay → `RemoteStakeReceiver` (documented).
- `.env.example` updated (`STAKE_AMOUNT`).
- **`forge test` → 70 PASS + 2 SKIP**. Script: `forge script script/SimulateRelay.s.sol:SimulateRelay -vvv` OK.

---

### Phase 7 — Gas + Deploy + hardening ✅

**Goal:** profiling and v1 close.

1. `Codec.gas.t.sol`: ABI decode vs Yul memory decode; snapshot in `.gas-snapshot` / `doc/GAS-EN.md`.
2. `Deploy.s.sol` + full NatSpec.
3. `doc/SWC-AUDIT-EN.md` (SWC matrix relevant to messaging).
4. Update diagrams / planning to "implemented".

**Exit criterion:** gas documented; full suite green; module v1 ready to close.

**Done (2026-09-13):**
- Optimizations: packed LZ/CCIP wire, `messageHashCalldata`, immutable `_selfPeer`, `refundExcessAssembly`, Yul `encodePacked`.
- `test/gas/Codec.gas.t.sol` + `.gas-snapshot` (decodeYul −1040 vs ABI; Yul refund −64).
- `script/Deploy.s.sol`: messengers + transports + relayer + stake + LZ/CCIP adapters.
- `doc/GAS-EN.md`, `doc/SWC-AUDIT-EN.md` (SWC-100–136 matrix, 0 vulnerable; aligned with module 15).
- **`forge test` → 81 PASS + 2 SKIP**.

---

## 8. Packet format (v1)

### Logical struct

```text
Packet {
  uint64  srcChainId;      // lab eid / selector
  uint64  dstChainId;
  bytes32 srcAddress;      // source peer (left-padded address)
  bytes32 dstAddress;      // destination peer
  uint64  nonce;           // per-route sequence (outboundNonces)
  bytes   payload;         // app-specific (e.g. abi.encode user,amount,isStake)
}

messageHash = keccak256(abi.encode(
  srcChainId, dstChainId, srcAddress, dstAddress, nonce, keccak256(payload)
))
```

`processedMessages[messageHash] = true` **before** the `IMessageReceiver` hook (CEI / idempotency).  
On receive, `PacketCodec.messageHashCalldata` is used.

### Adapter wire (LZ / CCIP) — packed 120 B + payload

```text
[0:8) srcChainId | [8:16) dstChainId | [16:48) srcAddress | [48:80) dstAddress
| [80:88) nonce | [88:120) payloadLen | [120:) payload
```

`encodePacked` / `decodeYul` in adapters. ABI `encode`/`decode` remains for tests and portability.

---

## 9. Global acceptance criteria (v1)

- [x] Fixed pragma `0.8.24` in all contracts.
- [x] `InvalidSourceSender` on unauthorized receives.
- [x] Anti-replay via `processedMessages`.
- [x] `quote` + native fee refund.
- [x] LZ V2 and CCIP adapters (mocks) integrated.
- [x] Working `RemoteStakeReceiver` demo.
- [x] Unauthorized + replay + dual-fork (or skip) + gas ABI vs Yul tests.
- [x] NatSpec + custom errors + CEI / ReentrancyGuard.
- [x] Documentation (`doc/`) aligned with the final code.

> **Module v1 closed.** Future extensions: deliverer allowlist, real LZ/CCIP fork, ERC-20 stake.

---

## 10. Post-v1 status

Module **v1 is closed** (phases 0–7). Extensions (deliverer allowlist, real LZ/CCIP fork, ERC-20 stake, dedicated fuzz) require a new scope authorization.

Reference suite: `forge test` → **81 PASS / 2 SKIP**.
