# SWC Audit — Cross-Chain Messaging & Interoperability

**Language:** English · [Español](./SWC-AUDIT-ES.md)

Verification of the AMP protocol against the [SWC Registry](https://swcregistry.io/) (EIP-1470) and monorepo principles (custom errors, fixed pragma, CEI, ReentrancyGuard, safe ETH refund, anti-replay). Style aligned with [`15-mev-hft-infra/doc/SWC-AUDIT.md`](../../15-mev-hft-infra/doc/SWC-AUDIT.md).

> **Note:** The SWC Registry has not been actively maintained since ~2020. Complement it with [SCSVS](https://github.com/ComposableSecurity/SCSVS) and [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Audited contracts (prod / core):**  
`src/CrossChainMessenger.sol`,  
`src/adapters/{LayerZeroV2Adapter,CCIPAdapter}.sol`,  
`src/apps/RemoteStakeReceiver.sol`,  
`src/libraries/{PacketCodec,PeerLib,FeeRefundLib}.sol`,  
`src/interfaces/{ICrossChainMessenger,IMessageReceiver,ITransportAdapter,ILayerZeroEndpointV2,ICCIPRouter}.sol`,  
`src/errors/MessagingErrors.sol`

**Trusted dependencies (out of scope for our own bugs):**  
OpenZeppelin Contracts v5.2.0 (`Ownable2Step`, `ReentrancyGuard`)

**Mocks (not prod):** `MockTransportAdapter`, `MockRelayer`, `MockMessageReceiver`, `MockLayerZeroEndpoint`, `MockCCIPRouter`, `RejectETH`  
**Date:** 2026-09-13  
**Test reference:** `test/*.t.sol`, `test/libraries/` (fuzz ≥ 1000), `test/adapters/`, `test/apps/`, `test/fork/`, `test/gas/`  
**Docs index:** [`README-EN.md`](./README-EN.md) · Module README: [`../README-EN.md`](../README-EN.md)

---

## Executive summary

| Status | Count |
|--------|-------|
| ✅ Mitigated / Not applicable | 30 |
| ⚠️ Informational (design / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusion:** No exploitable SWC vulnerabilities in the v1 scope. The messenger uses **`ReentrancyGuard`**, **`srcChainId`/`srcAddress`** verification (`InvalidSourceSender`), **`processedMessages`** (anti-replay), **custom errors**, **fixed pragma `0.8.24`**, ETH refund via Yul with a success check, and adapters that only accept the endpoint/router. Informational risks: trust in the `deliverer`/owner, gas griefing by the receiver app, reliance on mocks vs real endpoints, packed wire layout.

**Suite / module 16 principles verified:**

| Principle | Status |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `MessagingErrors` |
| Fixed pragma `0.8.24` | ✅ |
| CEI + `ReentrancyGuard` | ✅ |
| ETH `.call` / Yul (no `transfer`/`send`) | ✅ `FeeRefundLib` |
| `InvalidSourceSender` + peers | ✅ |
| `processedMessages` anti-replay | ✅ |
| Quote + refund to `msg.sender` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + libs |
| Optional dual-fork + SimulateRelay | ✅ Phase 6 |
| Gas ABI vs Yul | ✅ `doc/GAS-EN.md` |

---

## Full matrix SWC-100 — SWC-136

| ID | Title | Applies | Status | Evidence in messaging |
|----|-------|---------|--------|-----------------------|
| SWC-100 | Function Default Visibility | Yes | ✅ | Explicit visibility in `src/` |
| SWC-101 | Integer Overflow and Underflow | Yes | ✅ | Solidity `0.8.24`; `unchecked` only on `nonce++` / `msg.value - fee` / unstake after check |
| SWC-102 | Outdated Compiler Version | Yes | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Yes | ✅ | Exact pragma (no `^`) |
| SWC-104 | Unchecked Call Return Value | Yes | ✅ | Refund: `ok` check → `EthRefundFailed`; endpoint/router mocks the same |
| SWC-105 | Unprotected Ether Withdrawal | Partial | ✅ | Messenger exposes no generic withdraw; fees go to the adapter; owner cannot drain user funds via send |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | No `selfdestruct` |
| SWC-107 | Reentrancy | Yes | ✅ | `nonReentrant` on `send` / `receivePacket` / adapter dispatch+receive; CEI marks the hash before the app hook |
| SWC-108 | State Variable Default Visibility | Yes | ✅ | Explicit `public` / `private immutable` state |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | No legacy storage pointers |
| SWC-110 | Assert Violation | No | N/A | No production `assert` |
| SWC-111 | Deprecated Solidity Functions | Yes | ✅ | No `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | No `delegatecall` |
| SWC-113 | DoS with Failed Call | Partial | ✅ | Failed refund/adapter reverts the send; failed receiver app reverts the receive (retry possible) |
| SWC-114 | Transaction Order Dependence | Partial | ⚠️ | Outbound nonces; off-chain relayer ordering — see risks |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth by `msg.sender` (deliverer / endpoint / router / messenger) |
| SWC-116 | Block values as a proxy for time | No | N/A | No auth timestamps |
| SWC-117 | Signature Malleability | No | N/A | No on-chain signatures (mock/LZ/CCIP transport) |
| SWC-118 | Incorrect Constructor Name | No | N/A | 0.8+ `constructor` |
| SWC-119 | Shadowing State Variables | Yes | ✅ | No material shadowing |
| SWC-120 | Weak Sources of Randomness | No | N/A | No RNG |
| SWC-121 | Missing Protection against Signature Replay | Yes | ✅ | Equivalent: `processedMessages[messageHash]` + Replay tests |
| SWC-122 | Lack of Proper Signature Verification | Partial | ⚠️ | Trust in deliverer/endpoint/router; on-chain peers — see trust |
| SWC-123 | Requirement Violation | Yes | ✅ | Custom errors + Unauthorized / Replay / app tests |
| SWC-124 | Write to Arbitrary Storage Location | Partial | ✅ | `memory-safe` assembly in codec/refund; no arbitrary SSTORE |
| SWC-125 | Incorrect Inheritance Order | Yes | ✅ | Interface + Ownable2Step + ReentrancyGuard |
| SWC-126 | Insufficient Gas Griefing | Partial | ⚠️ | A malicious `IMessageReceiver` can OOG the deliverer — see risks |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | No dynamic function types |
| SWC-128 | DoS With Block Gas Limit | Partial | ⚠️ | Large payload / expensive app — sender/relayer responsibility |
| SWC-129 | Typographical Error | Yes | ✅ | Review + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII in `src/` |
| SWC-131 | Presence of unused variables | Yes | ✅ | No material dead code in hot paths |
| SWC-132 | Unexpected Ether balance | Partial | ✅ | `receive` on messenger; fees to adapter; exact refund |
| SWC-133 | Hash Collisions (var-length args) | Partial | ✅ | `messageHash` uses separate `keccak256(payload)` + typed fields |
| SWC-134 | Message call with hardcoded gas | No | N/A | Refund/adapters forward full `gas()` |
| SWC-135 | Code With No Effects | No | N/A | Refund with `excess == 0` = intentional no-op |
| SWC-136 | Unencrypted Private Data On-Chain | Partial | ✅ | Peers/owner are public; secrets in `.gitignore` |

---

## Informational risks

### SWC-114 — Ordering / relayer

The relayer chooses when to deliver. Nonces and `messageHash` prevent double execution; there is no on-chain liveness guarantee (ops).

### SWC-122 — Transport trust

v1 trusts the `deliverer` (mock relayer or adapter) and that the endpoint/router only call the adapter. Peers mitigate spoofing of the packet `srcAddress`. Real LZ/CCIP endpoints are outside the mock lab.

### SWC-126 / SWC-128 — receiver app

`RemoteStakeReceiver` / any `IMessageReceiver` can consume gas. The deliverer bears the cost; an app OOG reverts the receive (the hash is not marked).

### Centralization / post-deploy trust

| Topic | Risk | v1 treatment |
|-------|------|--------------|
| `owner` | setPeer / setAdapter / setDeliverer / setReceiver | `Ownable2Step` |
| `deliverer` | Can attempt deliveries; peers block spoofing | Only owner rotates deliverer |
| Adapter endpoint/router | Source of `lzReceive` / `ccipReceive` | Immutable + `msg.sender` auth |
| Packed wire | Wrong decode if layout diverges | Codec + adapter tests |

---

## Monorepo principles checklist (+ module 16)

| Principle | Compliant? | Notes |
|-----------|------------|-------|
| Custom errors | ✅ | `InvalidSourceSender`, `MessageAlreadyProcessed`, … |
| CEI + ReentrancyGuard | ✅ | Hash marked before app callback |
| Safe ETH | ✅ | Yul refund + check |
| NatSpec on public/external | ✅ | Messenger, adapters, libs, app |
| Fuzz ≥ 1000 | ✅ | PacketCodec / PeerLib / FeeRefund |
| Unauthorized + Replay | ✅ | Phases 2–5 |
| No floating pragma | ✅ | `0.8.24` |
| Gas ABI vs Yul | ✅ | `doc/GAS-EN.md` |

---

## Verification findings (code)

### Confirmed mitigations

1. **Spoofing:** `PeerLib.requirePeer` → `InvalidSourceSender` (`UnauthorizedSender.t.sol`).
2. **Replay:** `processedMessages` → `MessageAlreadyProcessed` (`ReplayProtection.t.sol`).
3. **Receive auth:** only `deliverer`; adapters only endpoint/router.
4. **Reentrancy:** `nonReentrant` + CEI on receive.
5. **Fees:** `InsufficientFee` + assembly refund; `RejectETH` → `EthRefundFailed`.
6. **PacketCodec:** packed length checks; `memory-safe` assembly.
7. **Suite:** unit + adapters + app + fork skip + gas.

### Phase 7 hardening

| # | Change | Reason |
|---|--------|--------|
| 1 | Packed Yul wire in LZ/CCIP | Less decode gas |
| 2 | `messageHashCalldata` + `_selfPeer` | Receive/send hot path |
| 3 | `refundExcessAssembly` | Send hot path |
| 4 | Full `script/Deploy.s.sol` | Reproducible local deploy |
| 5 | `test/gas/Codec.gas.t.sol` + `.gas-snapshot` | ABI vs Yul baseline |
| 6 | `doc/SWC-AUDIT-EN.md` / `doc/GAS-EN.md` | SWC-100–136 matrix + benchmarks |

### Non-blocking observations (v2)

| # | Observation | Severity | Suggested action |
|---|-------------|----------|------------------|
| 1 | Deliverer is a single address | Info | Allowlist / role |
| 2 | No payload size rate-limit | Info | On-chain cap |
| 3 | Mocks ≠ mainnet LZ/CCIP | Info | Real fork integration |
| 4 | Stake app without token custody | Info | Extend to ERC-20 |
| 5 | Formal Foundry invariants | Improvement | Peers/nonces handler |

---

## SWC → tests mapping

| SWC | Test(s) |
|-----|---------|
| SWC-101 | FeeRefund / unstake checks, fuzz |
| SWC-103 | `forge build` fixed pragma |
| SWC-104 / refund | `FeeRefundLib.t.sol`, RejectETH |
| SWC-107 | `nonReentrant` + e2e send/receive |
| SWC-115 / auth | `UnauthorizedSender.t.sol`, adapters |
| SWC-121 / replay | `ReplayProtection.t.sol` |
| SWC-123 | full suite |
| Gas | `test/gas/Codec.gas.t.sol` |

---

## Execution result

```text
forge test --summary
# 2026-09-13 — Phase 7
CrossChainMessengerTest     12 PASS
UnauthorizedSenderTest       4 PASS
ReplayProtectionTest         4 PASS
RemoteStakeReceiverTest      7 PASS
LayerZeroV2AdapterTest       8 PASS
CCIPAdapterTest              8 PASS
PacketCodecTest             10 PASS
PeerLibTest                 10 PASS
FeeRefundLibTest             9 PASS
CodecGasTest                 9 PASS
DualForkTest                 2 SKIP (no SRC/DST RPC)
Total: 81 PASS / 0 FAIL / 2 SKIP
```

Gas snapshot (`.gas-snapshot`): decodeYul **30 829** vs ABI **31 869**; Yul refund **24 019** vs `.call` **24 083**.

---

## References

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Module 15: [`15-mev-hft-infra/doc/SWC-AUDIT.md`](../../15-mev-hft-infra/doc/SWC-AUDIT.md)
- Gas: [`GAS-EN.md`](./GAS-EN.md)
- Plan: [`planificacion-EN.md`](./planificacion-EN.md)
