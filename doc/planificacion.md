# Planificación — Módulo 16: Cross-Chain Messaging & Interoperability

**Estado:** Fases **0–7** ✅ (módulo v1 cerrado).  
**Nota:** La regla de autorización por fase aplicó durante la construcción; v1 ya no tiene fases pendientes.

---

## 1. Objetivo

Construir un protocolo de **arbitrary message passing (AMP)** multi-cadena que permita:

- Enviar payloads ABI-encoded desde una cadena origen a una destino.
- Sincronizar estado (p. ej. balances / flags) entre peers autorizados.
- Ejecutar llamadas remotas controladas (demo: staking / rebalanceo de liquidez).
- Integrar dos estándares de transporte: **LayerZero Endpoint V2** y **Chainlink CCIP** (`IRouterClient`), más un **mock relayer** para tests locales.
- Aplicar controles de seguridad: verificación de `srcChainId` + `srcAddress`, anti-replay por hash de mensaje, quote de fees nativos y refund del sobrante a `msg.sender`.

Stack: **Foundry + Solidity `0.8.24`** (pragma fijo). Frontend Next.js queda **fuera de alcance v1**.

---

## 2. Alcance

| Incluido (v1) | Excluido (v1) |
|---------------|---------------|
| `CrossChainMessenger` — send / receive / peers / idempotencia | Bridge de tokens lock/mint (módulo 09) |
| Peers trusted on-chain (`peers[chainId]`) | Light client / SPV / zk proofs |
| `PacketCodec` — ABI + packed Yul + `messageHash` | Relayer off-chain en producción |
| Adapter LayerZero V2 (interfaces + mock endpoint) | DVN / Executor custom LZ en mainnet |
| Adapter Chainlink CCIP (`ICCIPRouter` + mock router) | Token pools CCIP / fee tokens ERC-20 complejos |
| Demo app: `RemoteStakeReceiver` (stake remoto vía mensaje) | Frontend Next.js (App Router) |
| `MockRelayer` + dual-fork / in-process | Gobernanza DAO del set de peers |
| Tests: unauthorized, replay, quote/refund, gas ABI vs Yul | Multi-hop routing automático / `Messaging.fuzz.t.sol` dedicado |

---

## 3. Stack y restricciones técnicas

### Suite (`evm-smart-contracts-suite` + `solidity.cursorrules`)

- Solidity **exacto** `0.8.24` (sin floating pragma).
- OpenZeppelin Contracts v5.x (`ReentrancyGuard`, `Ownable2Step`, `SafeERC20` si aplica).
- Foundry: unit + fuzz (`runs >= 1000`) + multi-fork + gas reports.
- **Custom errors** (no `require` con strings).
- CEI estricto; ETH vía `.call{value: ...}("")` o Yul `call` (nunca `transfer`/`send`).
- NatSpec en toda API pública/externa.
- Layout: Interfaces → Libraries → Contracts → State → Events → Errors → Modifiers → Functions.
- TDD: tests primero en fases de contratos; cobertura de ramas de lógica explícita.

### Módulo 16 (`.cursorrules` local)

- Estándares: LayerZero Endpoint V2, CCIP `IRouterClient`-like, paquetes propios (ABI + packed).
- Spoofing: verificar `srcChainId` + `srcAddress`; revert `InvalidSourceSender()`.
- Fees: `quote` antes de dispatch; refund seguro del ETH no usado a `msg.sender` (`refundExcessAssembly`).
- Idempotencia: `mapping(bytes32 => bool) processedMessages`.
- Payloads: `abi.encode` / `abi.decode` app-side; wire adapters con `encodePacked` / `decodeYul`.

### Next.js (`nextjs.cursorrules`) — post-v1

- Si se añade UI: App Router, Zod, Vitest + RTL, JSDoc, sin `any`, sin prop drilling.
- No forma parte de las fases 0–7.

---

## 4. Arquitectura (v1 implementado)

```
16-crosschain-messaging/
├── README.md
├── doc/
│   ├── README.md
│   ├── planificacion.md
│   ├── diagrama-de-clases.md
│   ├── diagrama-de-flujo.md
│   ├── flujograma.md
│   ├── SWC-AUDIT.md
│   └── GAS.md
├── src/
│   ├── CrossChainMessenger.sol          # núcleo AMP + peers + idempotencia
│   ├── apps/
│   │   └── RemoteStakeReceiver.sol      # demo ejecución remota
│   ├── adapters/
│   │   ├── LayerZeroV2Adapter.sol       # wire packed Yul
│   │   └── CCIPAdapter.sol              # wire packed Yul
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

### Contratos y responsabilidades

| Artefacto | Responsabilidad |
|-----------|-----------------|
| `CrossChainMessenger` | Quote, send, receive; peers; `processedMessages`; `_selfPeer`; CEI + reentrancy |
| `ITransportAdapter` | Abstracción LZ / CCIP / mock transport |
| `LayerZeroV2Adapter` | Dispatch/receive Endpoint V2; wire `encodePacked`/`decodeYul` |
| `CCIPAdapter` | Dispatch/receive router CCIP; mismo wire packed |
| `PacketCodec` | ABI + packed + `messageHash` / `messageHashCalldata` |
| `PeerLib` | address↔bytes32; `requirePeer` / `requireConfiguredPeer` |
| `FeeRefundLib` | `refundExcess` (`.call`) + `refundExcessAssembly` (Yul, send) |
| `RemoteStakeReceiver` | Stake/unstake remoto desde payload decodificado |
| `MockTransportAdapter` | Fee fijo + último packet (unit / dual-fork) |
| `MockRelayer` | Entrega in-process a `receivePacket` |
| `MessagingErrors` | Custom errors del módulo |

---

## 5. Errores custom (módulo)

```solidity
error InvalidSourceSender();      // obligatorio (.cursorrules)
error MessageAlreadyProcessed();  // replay / idempotencia
error InsufficientFee();          // msg.value < quote
error EthRefundFailed();          // refund .call fallido
error ZeroAddress();
error InvalidPeer();
error InvalidPayload();
error UnauthorizedCaller();       // adapter/endpoint no autorizado
error UnsupportedChain();
error ZeroAmount();
```

Obligatorio del módulo: `InvalidSourceSender()`. El resto soporta fees, peers e idempotencia.

---

## 6. Gobernanza de fases (autorización obligatoria)

| Regla | Detalle |
|-------|---------|
| **Gate** | No se escribe código de una fase hasta: *“autorizo Fase N”*. |
| **Entrega** | Al cerrar: checklist de aceptación + archivos tocados. |
| **Bloqueo** | Alcance nuevo → documentar y esperar nueva autorización. |
| **TDD** | En fases de contratos: tests primero, luego implementación. |

### Tablero de fases

| Fase | Nombre | Estado | Autorización |
|------|--------|--------|--------------|
| 0 | Setup Foundry + estructura + deps | ✅ Completada | ✅ Autorizada |
| 1 | Errors + libs (`PacketCodec`, `PeerLib`, `FeeRefundLib`) | ✅ Completada | ✅ Autorizada |
| 2 | `CrossChainMessenger` + mock relayer (unit) | ✅ Completada | ✅ Autorizada |
| 3 | Adapter LayerZero V2 + mocks | ✅ Completada | ✅ Autorizada |
| 4 | Adapter Chainlink CCIP + mocks | ✅ Completada | ✅ Autorizada |
| 5 | `RemoteStakeReceiver` + Unauthorized + Replay | ✅ Completada | ✅ Autorizada |
| 6 | Dual-fork / multi-fork + `SimulateRelay` | ✅ Completada | ✅ Autorizada |
| 7 | Gas ABI vs Yul + Deploy + NatSpec / SWC | ✅ Completada | ✅ Autorizada |

---

## 7. Detalle por fase

### Fase 0 — Setup Foundry ✅

**Objetivo:** repo compilable alineado a la suite.

1. Scaffold Foundry (`foundry.toml`: solc `0.8.24`, optimizer, fuzz `runs >= 1000`, `[rpc_endpoints]` para forks).
2. Dependencias: `forge-std`, OpenZeppelin v5; stubs/interfaces mínimas LZ V2 y CCIP (sin SDK completo si no hace falta).
3. Carpetas `src/{adapters,apps,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas,adapters,apps}`, `script/`, `doc/`.
4. Stub mínimo + smoke test; `.env.example` (RPCs origen/destino); `README.md`.

**Criterio de salida:** `forge build` y `forge test` en verde.

**Hecho (2026-09-13):**
- `foundry.toml` (solc `0.8.24`, Cancun, optimizer `10_000`, `via_ir`, fuzz `runs = 1000`, RPC `mainnet` / `src` / `dst`).
- `remappings.txt`: `forge-std/`, `@openzeppelin/contracts/`.
- Dependencias en `lib/` (gitignored): `forge-std` **v1.16.2**, OpenZeppelin **v5.2.0** (copiadas del módulo 15).
- Carpetas `src/{adapters,apps,interfaces,libraries,errors,mocks}`, `test/{helpers,fuzz,fork,gas,adapters,apps}`, `script/`.
- Stub `src/Placeholder.sol` + `test/Placeholder.t.sol` (ping + remapping IERC20).
- Stub `script/Deploy.s.sol` (Fase 7), `.env.example`, `README.md`, `doc/` ya existente.
- `forge build` OK; `forge test` → **2 PASS**.

---

### Fase 1 — Errors + libraries ✅

**Objetivo:** primitives de paquete, peers y refund.

1. TDD: `PacketCodec` (encode/decode round-trip, `messageHash` estable).
2. `PeerLib`: pack address → bytes32; validación zero.
3. `FeeRefundLib`: refund sobrante; revert `EthRefundFailed` si el receptor rechaza.
4. `MessagingErrors.sol` con todos los custom errors del §5.

**Criterio de salida:** libs en verde; fuzz de encode/decode ≥ 1000 donde aplique.

**Hecho (2026-09-13):**
- `src/errors/MessagingErrors.sol` — 10 custom errors (incl. `InvalidSourceSender`).
- `src/libraries/PacketCodec.sol` — `Packet`, `encode`/`decode` ABI, `messageHash`, `encodePacked` + `decodeYul`.
- `src/libraries/PeerLib.sol` — pack/unpack, `requireNonZero`, `requireConfiguredPeer`, `requirePeer`.
- `src/libraries/FeeRefundLib.sol` — `refundExcess` con `.call` + `InsufficientFee` / `EthRefundFailed`.
- Mock `RejectETH`; harnesses en `test/helpers/LibHarnesses.sol`.
- Tests: `PacketCodec.t.sol`, `PeerLib.t.sol`, `FeeRefundLib.t.sol` (fuzz 1000 c/u donde aplica).
- Stub `Placeholder` eliminado.
- **`forge test` → 27 PASS**.

---

### Fase 2 — CrossChainMessenger + mock relayer ✅

**Objetivo:** núcleo AMP local sin LZ/CCIP reales.

1. Tests: `quote` → `send` con fee; receive desde peer válido; peer inválido → `InvalidSourceSender`.
2. Idempotencia: segundo `receive` del mismo hash → `MessageAlreadyProcessed`.
3. Refund del ETH no usado a `msg.sender`.
4. `MockRelayer` entrega in-process entre dos instancias (origen/destino).

**Criterio de salida:** unit messenger + refund + peer check en verde.

**Hecho (2026-09-13):**
- Interfaces: `ICrossChainMessenger`, `IMessageReceiver`, `ITransportAdapter`.
- `CrossChainMessenger`: Ownable2Step + ReentrancyGuard; peers; `processedMessages`; quote/send/receive; setPeer/Adapter/Deliverer/Receiver.
- Mocks: `MockTransportAdapter` (fee fijo), `MockRelayer`, `MockMessageReceiver`.
- `MessagingTestBase` dual-messenger in-process (CHAIN_A ↔ CHAIN_B).
- `CrossChainMessenger.t.sol`: refund, relay e2e, unauthorized, spoof, replay, dst checks.
- **`forge test` → 39 PASS**.

---

### Fase 3 — LayerZero V2 adapter ✅

**Objetivo:** cablear transporte estilo Endpoint V2 con mock.

1. Interfaces mínimas + `MockLayerZeroEndpoint`.
2. Adapter: send con options/fees; `_lzReceive` / equivalente mockeado.
3. Solo endpoint configurado puede invocar el path de recepción (`UnauthorizedCaller`).

**Criterio de salida:** tests adapter LZ + integración con messenger en verde.

**Hecho (2026-09-13):**
- `ILayerZeroEndpointV2` + structs `Origin` / `MessagingParams` / `MessagingFee` / `MessagingReceipt` + `ILayerZeroReceiver`.
- `MockLayerZeroEndpoint`: fee fijo, `registerOApp`, cola `pending`, `deliver` / `deliverLast`.
- `LayerZeroV2Adapter`: `quote`/`dispatch` (solo messenger), `lzReceive` (solo endpoint), `lzPeers` por eid.
- `test/adapters/LayerZeroV2.t.sol`: e2e send→deliver, auth endpoint/messenger, spoof LZ peer, replay.
- **`forge test` → 47 PASS**.

---

### Fase 4 — Chainlink CCIP adapter ✅

**Objetivo:** cablear transporte estilo `IRouterClient` con mock.

1. `MockCCIPRouter` + mensaje CCIP-like (selector, sender, data).
2. Adapter: `ccipSend` / `ccipReceive` mockeados; fee quote + refund.
3. Verificación de sender remoto contra `ccipPeers` / peers del messenger.

**Criterio de salida:** tests adapter CCIP + integración en verde.

**Hecho (2026-09-13):**
- `ICCIPRouter` + `EVM2AnyMessage` / `Any2EVMMessage` + `IAny2EVMMessageReceiver`.
- `MockCCIPRouter`: fee fijo, `registerOApp`, cola `pending`, `deliver` / `deliverLast`.
- `CCIPAdapter`: `quote`/`dispatch` (solo messenger), `ccipReceive` (solo router), `ccipPeers` por selector.
- `test/adapters/CCIP.t.sol`: e2e send→deliver, auth router/messenger, spoof peer, replay.
- **`forge test` → 55 PASS**.

---

### Fase 5 — RemoteStakeReceiver + Unauthorized + Replay ✅

**Objetivo:** demo de ejecución remota y matriz de seguridad del módulo.

| Tipo | Qué valida |
|------|------------|
| Unauthorized sender | Payload válido, `srcAddress` no peer → `InvalidSourceSender` |
| Replay | Mismo `messageHash` dos veces → `MessageAlreadyProcessed` |
| App | Payload stake remoto decodificado y aplicado una sola vez |

**Criterio de salida:** `UnauthorizedSender.t.sol`, `ReplayProtection.t.sol`, app e2e en verde.

**Hecho (2026-09-13):**
- `RemoteStakeReceiver`: stake/unstake via `abi.encode(user, amount, isStake)`; solo `messenger`.
- `UnauthorizedSender.t.sol`: spoof peer, chain sin peer, caller no deliverer.
- `ReplayProtection.t.sol`: mismo packet/hash, nonces distintos OK.
- `RemoteStakeReceiver.t.sol`: e2e stake/unstake, zero checks, no double-stake.
- **`forge test` → 70 PASS**.

---

### Fase 6 — Dual-fork + SimulateRelay ✅

**Objetivo:** simular dispatch origen y ejecución destino con forks (o skip sin RPC).

1. `DualFork.t.sol`: dos forks (p. ej. Sepolia / another) o Anvil multi-chain helper.
2. `SimulateRelay.s.sol`: documenta el camino evento → relay → receive.
3. Skip limpio si faltan `SRC_RPC_URL` / `DST_RPC_URL`.

**Criterio de salida:** fork pass opcional; script documentado.

**Hecho (2026-09-13):**
- `ForkHelper`: crea dual-fork desde `SRC_RPC_URL` / `DST_RPC_URL`; `_skipIfNoDualFork`.
- `test/fork/DualFork.t.sol`: send en origen + stake en destino; replay en destino; **2 SKIP** sin RPC.
- `script/SimulateRelay.s.sol`: simulación in-process send → relay → `RemoteStakeReceiver` (documentado).
- `.env.example` actualizado (`STAKE_AMOUNT`).
- **`forge test` → 70 PASS + 2 SKIP**. Script: `forge script script/SimulateRelay.s.sol:SimulateRelay -vvv` OK.

---

### Fase 7 — Gas + Deploy + hardening ✅

**Objetivo:** profiling y cierre v1.

1. `Codec.gas.t.sol`: ABI decode vs Yul memory decode; snapshot en `.gas-snapshot` / `doc/GAS.md`.
2. `Deploy.s.sol` + NatSpec completo.
3. `doc/SWC-AUDIT.md` (matriz SWC relevante a messaging).
4. Actualizar diagramas / planificación a “implementado”.

**Criterio de salida:** gas documentado; suite completa en verde; módulo v1 listo para cierre.

**Hecho (2026-09-13):**
- Optimizaciones: packed wire LZ/CCIP, `messageHashCalldata`, `_selfPeer` immutable, `refundExcessAssembly`, `encodePacked` Yul.
- `test/gas/Codec.gas.t.sol` + `.gas-snapshot` (decodeYul −1040 vs ABI; refund Yul −64).
- `script/Deploy.s.sol`: messengers + transports + relayer + stake + adapters LZ/CCIP.
- `doc/GAS.md`, `doc/SWC-AUDIT.md` (matriz SWC-100–136, 0 vulnerables; alineado a módulo 15).
- **`forge test` → 81 PASS + 2 SKIP**.

---

## 8. Formato de paquete (v1)

### Struct lógico

```text
Packet {
  uint64  srcChainId;      // eid / selector de laboratorio
  uint64  dstChainId;
  bytes32 srcAddress;      // peer origen (address left-padded)
  bytes32 dstAddress;      // peer destino
  uint64  nonce;           // secuencia por ruta (outboundNonces)
  bytes   payload;         // app-specific (p. ej. abi.encode user,amount,isStake)
}

messageHash = keccak256(abi.encode(
  srcChainId, dstChainId, srcAddress, dstAddress, nonce, keccak256(payload)
))
```

`processedMessages[messageHash] = true` **antes** del hook `IMessageReceiver` (CEI / idempotencia).  
En receive se usa `PacketCodec.messageHashCalldata`.

### Wire adapters (LZ / CCIP) — packed 120 B + payload

```text
[0:8) srcChainId | [8:16) dstChainId | [16:48) srcAddress | [48:80) dstAddress
| [80:88) nonce | [88:120) payloadLen | [120:) payload
```

`encodePacked` / `decodeYul` en adapters. ABI `encode`/`decode` queda para tests y portabilidad.

---

## 9. Criterios de aceptación globales (v1)

- [x] Pragma fijo `0.8.24` en todos los contratos.
- [x] `InvalidSourceSender` en receives no autorizados.
- [x] Anti-replay por `processedMessages`.
- [x] `quote` + refund de fee nativo.
- [x] Adapters LZ V2 y CCIP (mocks) integrados.
- [x] Demo `RemoteStakeReceiver` funcional.
- [x] Tests unauthorized + replay + dual-fork (o skip) + gas ABI vs Yul.
- [x] NatSpec + custom errors + CEI / ReentrancyGuard.
- [x] Documentación (`doc/`) alineada al código final.

> **Módulo v1 cerrado.** Extensiones futuras: allowlist deliverer, fork LZ/CCIP real, stake ERC-20.

---

## 10. Estado post-v1

El módulo **v1 está cerrado** (fases 0–7). Extensiones (allowlist deliverer, fork LZ/CCIP real, stake ERC-20, fuzz dedicado) requieren nueva autorización de alcance.

Suite de referencia: `forge test` → **81 PASS / 2 SKIP**.
