# Auditoría SWC — Cross-Chain Messaging & Interoperability

Verificación del protocolo AMP contra el [SWC Registry](https://swcregistry.io/) (EIP-1470) y principios del monorepo (custom errors, pragma fijo, CEI, ReentrancyGuard, refund ETH seguro, anti-replay). Estilo alineado a [`15-mev-hft-infra/doc/SWC-AUDIT.md`](../../15-mev-hft-infra/doc/SWC-AUDIT.md).

> **Nota:** El SWC Registry no se mantiene activamente desde ~2020. Complementar con [SCSVS](https://github.com/ComposableSecurity/SCSVS) y [EEA EthTrust](https://entethalliance.org/specs/ethtrust/).

**Contratos auditados (prod / core):**  
`src/CrossChainMessenger.sol`,  
`src/adapters/{LayerZeroV2Adapter,CCIPAdapter}.sol`,  
`src/apps/RemoteStakeReceiver.sol`,  
`src/libraries/{PacketCodec,PeerLib,FeeRefundLib}.sol`,  
`src/interfaces/{ICrossChainMessenger,IMessageReceiver,ITransportAdapter,ILayerZeroEndpointV2,ICCIPRouter}.sol`,  
`src/errors/MessagingErrors.sol`

**Dependencias de confianza (fuera de alcance de bugs propios):**  
OpenZeppelin Contracts v5.2.0 (`Ownable2Step`, `ReentrancyGuard`)

**Mocks (fuera de prod):** `MockTransportAdapter`, `MockRelayer`, `MockMessageReceiver`, `MockLayerZeroEndpoint`, `MockCCIPRouter`, `RejectETH`  
**Fecha:** 2026-09-13  
**Referencia tests:** `test/*.t.sol`, `test/libraries/`, `test/adapters/`, `test/apps/`, `test/fork/`, `test/gas/`  
**Índice docs:** [`README.md`](./README.md) · README módulo: [`../README.md`](../README.md)

---

## Resumen ejecutivo

| Estado | Cantidad |
|--------|----------|
| ✅ Mitigado / No aplicable | 30 |
| ⚠️ Informativo (diseño / trust / ops) | 6 |
| ❌ Vulnerable | 0 |

**Conclusión:** Sin vulnerabilidades SWC explotables en el alcance v1. El messenger usa **`ReentrancyGuard`**, verificación de **`srcChainId`/`srcAddress`** (`InvalidSourceSender`), **`processedMessages`** (anti-replay), **custom errors**, **pragma fijo `0.8.24`**, refund ETH vía Yul con chequeo de success, y adapters que solo aceptan endpoint/router. Riesgos informativos: trust del `deliverer`/owner, gas griefing del receiver app, dependencia de mocks vs endpoints reales, packed wire layout.

**Principios del suite / módulo 16 verificados:**

| Principio | Estado |
|-----------|--------|
| Custom errors (no `require` strings) | ✅ `MessagingErrors` |
| Pragma fijo `0.8.24` | ✅ |
| CEI + `ReentrancyGuard` | ✅ |
| ETH `.call` / Yul (no `transfer`/`send`) | ✅ `FeeRefundLib` |
| `InvalidSourceSender` + peers | ✅ |
| `processedMessages` anti-replay | ✅ |
| Quote + refund a `msg.sender` | ✅ |
| Fuzz ≥ 1000 runs | ✅ `foundry.toml` + libs |
| Dual-fork opcional + SimulateRelay | ✅ Fase 6 |
| Gas ABI vs Yul | ✅ `doc/GAS.md` |

---

## Matriz completa SWC-100 — SWC-136

| ID | Título | Aplica | Estado | Evidencia en messaging |
|----|--------|--------|--------|------------------------|
| SWC-100 | Function Default Visibility | Sí | ✅ | Visibilidad explícita en `src/` |
| SWC-101 | Integer Overflow and Underflow | Sí | ✅ | Solidity `0.8.24`; `unchecked` solo en `nonce++` / `msg.value - fee` / unstake tras check |
| SWC-102 | Outdated Compiler Version | Sí | ✅ | `pragma solidity 0.8.24` + `foundry.toml` |
| SWC-103 | Floating Pragma | Sí | ✅ | Pragma exacto (sin `^`) |
| SWC-104 | Unchecked Call Return Value | Sí | ✅ | Refund: chequeo `ok` → `EthRefundFailed`; mocks endpoint/router igual |
| SWC-105 | Unprotected Ether Withdrawal | Parcial | ✅ | Messenger no expone withdraw genérico; fees van al adapter; owner no drena user funds vía send |
| SWC-106 | Unprotected SELFDESTRUCT | No | N/A | Sin `selfdestruct` |
| SWC-107 | Reentrancy | Sí | ✅ | `nonReentrant` en `send` / `receivePacket` / adapters dispatch+receive; CEI marca hash antes del app hook |
| SWC-108 | State Variable Default Visibility | Sí | ✅ | State `public` / `private immutable` explícitos |
| SWC-109 | Uninitialized Storage Pointer | No | N/A | Sin punteros storage legacy |
| SWC-110 | Assert Violation | No | N/A | Sin `assert` de producción |
| SWC-111 | Deprecated Solidity Functions | Sí | ✅ | Sin `suicide` / `throw` / `tx.origin` / ETH `transfer`/`send` |
| SWC-112 | Delegatecall to Untrusted Callee | No | N/A | Sin `delegatecall` |
| SWC-113 | DoS with Failed Call | Parcial | ✅ | Refund/adapter fallidos revierten el send; receiver app fallido revierte receive (retry posible) |
| SWC-114 | Transaction Order Dependence | Parcial | ⚠️ | Nonces outbound; relayer ordering off-chain — ver riesgos |
| SWC-115 | Authorization through tx.origin | No | N/A | Auth por `msg.sender` (deliverer / endpoint / router / messenger) |
| SWC-116 | Block values as a proxy for time | No | N/A | Sin timestamps de auth |
| SWC-117 | Signature Malleability | No | N/A | Sin firmas on-chain (transporte mock/LZ/CCIP) |
| SWC-118 | Incorrect Constructor Name | No | N/A | `constructor` 0.8+ |
| SWC-119 | Shadowing State Variables | Sí | ✅ | Sin shadowing material |
| SWC-120 | Weak Sources of Randomness | No | N/A | Sin RNG |
| SWC-121 | Missing Protection against Signature Replay | Sí | ✅ | Equivalente: `processedMessages[messageHash]` + tests Replay |
| SWC-122 | Lack of Proper Signature Verification | Parcial | ⚠️ | Confianza en deliverer/endpoint/router; peers on-chain — ver trust |
| SWC-123 | Requirement Violation | Sí | ✅ | Custom errors + Unauthorized / Replay / app tests |
| SWC-124 | Write to Arbitrary Storage Location | Parcial | ✅ | Assembly `memory-safe` en codec/refund; sin SSTORE arbitrario |
| SWC-125 | Incorrect Inheritance Order | Sí | ✅ | Interface + Ownable2Step + ReentrancyGuard |
| SWC-126 | Insufficient Gas Griefing | Parcial | ⚠️ | `IMessageReceiver` malicioso puede OOG al deliverer — ver riesgos |
| SWC-127 | Arbitrary Jump with Function Type Variable | No | N/A | Sin function types dinámicos |
| SWC-128 | DoS With Block Gas Limit | Parcial | ⚠️ | Payload grande / app costosa — responsabilidad del emisor/relayer |
| SWC-129 | Typographical Error | Sí | ✅ | Revisión + `forge build` / suite PASS |
| SWC-130 | Right-To-Left-Override | No | N/A | ASCII en `src/` |
| SWC-131 | Presence of unused variables | Sí | ✅ | Sin dead code material en hot paths |
| SWC-132 | Unexpected Ether balance | Parcial | ✅ | `receive` en messenger; fees al adapter; refund exacto |
| SWC-133 | Hash Collisions (var-length args) | Parcial | ✅ | `messageHash` usa `keccak256(payload)` separado + campos tipados |
| SWC-134 | Message call with hardcoded gas | No | N/A | Refund/adapters usan `gas()` completo |
| SWC-135 | Code With No Effects | No | N/A | Refund `excess == 0` = no-op intencional |
| SWC-136 | Unencrypted Private Data On-Chain | Parcial | ✅ | Peers/owner públicos; secretos en `.gitignore` |

---

## Riesgos informativos

### SWC-114 — Orden / relayer

El relayer elige cuándo entregar. Nonces y `messageHash` evitan doble ejecución; no hay guarantee de liveness on-chain (ops).

### SWC-122 — Trust del transporte

v1 confía en `deliverer` (mock relayer o adapter) y en que endpoint/router solo llaman al adapter. Peers mitigan spoofing del `srcAddress` del packet. Endpoints LZ/CCIP reales quedan fuera del mock lab.

### SWC-126 / SWC-128 — receiver app

`RemoteStakeReceiver` / cualquier `IMessageReceiver` puede consumir gas. El deliverer asume el costo; un app OOG revierte el receive (hash no queda marcado).

### Centralización / trust post-deploy

| Tema | Riesgo | Tratamiento v1 |
|------|--------|----------------|
| `owner` | setPeer / setAdapter / setDeliverer / setReceiver | `Ownable2Step` |
| `deliverer` | Puede intentar delivers; peers bloquean spoof | Solo owner rota deliverer |
| Adapter endpoint/router | Fuente de `lzReceive` / `ccipReceive` | Immutable + auth `msg.sender` |
| Packed wire | Decode incorrecto si layout diverge | Tests codec + adapters |

---

## Checklist principios monorepo (+ módulo 16)

| Principio | ¿Cumple? | Notas |
|-----------|----------|--------|
| Custom errors | ✅ | `InvalidSourceSender`, `MessageAlreadyProcessed`, … |
| CEI + ReentrancyGuard | ✅ | Hash marked before app callback |
| ETH seguro | ✅ | Refund Yul + chequeo |
| NatSpec públicas/externas | ✅ | Messenger, adapters, libs, app |
| Fuzz ≥ 1000 | ✅ | PacketCodec / PeerLib / FeeRefund |
| Unauthorized + Replay | ✅ | Fases 2–5 |
| Sin floating pragma | ✅ | `0.8.24` |
| Gas ABI vs Yul | ✅ | `doc/GAS.md` |

---

## Hallazgos de verificación (código)

### Mitigaciones confirmadas

1. **Spoofing:** `PeerLib.requirePeer` → `InvalidSourceSender` (`UnauthorizedSender.t.sol`).
2. **Replay:** `processedMessages` → `MessageAlreadyProcessed` (`ReplayProtection.t.sol`).
3. **Auth receive:** solo `deliverer`; adapters solo endpoint/router.
4. **Reentrancy:** `nonReentrant` + CEI en receive.
5. **Fees:** `InsufficientFee` + refund assembly; `RejectETH` → `EthRefundFailed`.
6. **PacketCodec:** packed length checks; assembly `memory-safe`.
7. **Suite:** unit + adapters + app + fork skip + gas.

### Hardening Fase 7

| # | Cambio | Motivo |
|---|--------|--------|
| 1 | Wire packed Yul en LZ/CCIP | Menos gas decode |
| 2 | `messageHashCalldata` + `_selfPeer` | Hot path receive/send |
| 3 | `refundExcessAssembly` | Hot path send |
| 4 | `script/Deploy.s.sol` completo | Deploy local reproducible |
| 5 | `test/gas/Codec.gas.t.sol` + `.gas-snapshot` | Baseline ABI vs Yul |
| 6 | `doc/SWC-AUDIT.md` / `doc/GAS.md` | Matriz SWC-100–136 + benchmarks |

### Observaciones no bloqueantes (v2)

| # | Observación | Severidad | Acción sugerida |
|---|-------------|-----------|-----------------|
| 1 | Deliverer es single-address | Info | Allowlist / role |
| 2 | Sin rate-limit de payload size | Info | Cap on-chain |
| 3 | Mocks ≠ mainnet LZ/CCIP | Info | Fork integration real |
| 4 | App stake sin token custody | Info | Extender a ERC-20 |
| 5 | Invariantes Foundry formales | Mejora | Handler peers/nonces |

---

## Mapeo SWC → tests

| SWC | Test(s) |
|-----|---------|
| SWC-101 | FeeRefund / unstake checks, fuzz |
| SWC-103 | `forge build` pragma fijo |
| SWC-104 / refund | `FeeRefundLib.t.sol`, RejectETH |
| SWC-107 | `nonReentrant` + e2e send/receive |
| SWC-115 / auth | `UnauthorizedSender.t.sol`, adapters |
| SWC-121 / replay | `ReplayProtection.t.sol` |
| SWC-123 | suite completa |
| Gas | `test/gas/Codec.gas.t.sol` |

---

## Resultado de ejecución

```text
forge test --summary
# 2026-09-13 — Fase 7
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
DualForkTest                 2 SKIP (sin SRC/DST RPC)
Total: 81 PASS / 0 FAIL / 2 SKIP
```

Gas snapshot (`.gas-snapshot`): decodeYul **30 829** vs ABI **31 869**; refund Yul **24 019** vs `.call` **24 083**.

---

## Referencias

- [SWC Registry](https://swcregistry.io/)
- [EIP-1470](https://eips.ethereum.org/EIPS/eip-1470)
- Módulo 15: [`15-mev-hft-infra/doc/SWC-AUDIT.md`](../../15-mev-hft-infra/doc/SWC-AUDIT.md)
- Gas: [`GAS.md`](./GAS.md)
- Plan: [`planificacion.md`](./planificacion.md)
