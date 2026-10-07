# Decisiones técnicas, lógica y gas — Módulo 16

**Idioma:** Español · [English](./DECISIONES-Y-LOGICA-EN.md)

Guía para entender **qué se construyó**, **por qué** se eligió así, **cómo fluye** un mensaje y **qué se puede mejorar en gas** sin reescribir el módulo.

Referencias: [`GAS-ES.md`](./GAS-ES.md) · [`diagrama-de-flujo-ES.md`](./diagrama-de-flujo-ES.md) · [`SWC-AUDIT-ES.md`](./SWC-AUDIT-ES.md) · [`planificacion-ES.md`](./planificacion-ES.md)

---

## 1. Qué es esto (en una frase)

Un protocolo de **arbitrary message passing (AMP)**: envías un `payload` (bytes) desde un messenger en la cadena A; un transporte (mock / LayerZero V2 / CCIP) lo lleva a la cadena B; el messenger destino valida origen + peer + anti-replay y opcionalmente llama a una app (`RemoteStakeReceiver`).

No es un bridge de tokens (eso es el módulo 09). Aquí el valor está en el **mensaje autenticado**, no en mint/burn de ERC-20.

---

## 2. Decisiones técnicas (y el porqué)

### 2.1 Núcleo propio + adapters, no “solo LZ/CCIP”

| Decisión | Alternativa descartada | Porqué |
|----------|------------------------|--------|
| `CrossChainMessenger` como núcleo AMP | Lógica solo dentro de cada adapter | Una sola fuente de verdad para peers, fees, idempotencia y hook de app |
| `ITransportAdapter` (`quote` / `dispatch`) | Acoplar send a LZ o CCIP | Tests locales con `MockTransportAdapter` / `MockRelayer` sin endpoints reales |
| Adapters LZ V2 y CCIP delgados | Reimplementar DVN / fee tokens CCIP | Alcance lab/v1: interfaces + mocks; wire packed hacia el messenger |

**Idea:** el messenger no sabe si el paquete viajó por LZ, CCIP o un relayer de prueba. Solo habla con el adapter y con un `deliverer` autorizado.

### 2.2 Confianza: peers + deliverer (no light client)

| Decisión | Porqué |
|----------|--------|
| `peers[chainId] → bytes32` | Anti-spoofing de `srcAddress`: solo el messenger remoto configurado puede “firmar” el origen lógico |
| Solo `deliverer` llama `receivePacket` | Separar “quién empuja el paquete on-chain” de “quién es el peer remoto” |
| Owner `Ownable2Step` rota peers / adapter / deliverer / receiver | Rotación segura de admin sin single-step accidental |

**Tradeoff consciente:** v1 **confía** en el deliverer (y en endpoint/router en paths LZ/CCIP). No hay SPV/zk. Eso está documentado como informativo en SWC (trust / ops).

### 2.3 Paquete dual: ABI para tests, packed Yul para wire

| Formato | Uso |
|---------|-----|
| `abi.encode` / `abi.decode` | Codec portable, tests, claridad |
| `encodePacked` + `decodeYul` (120 B fijos + payload) | Wire de adapters LZ/CCIP (menos gas) |

**Tradeoff:** packed exige layout exacto entre origen y destino; ABI es más seguro para interoperar con terceros, pero más caro.

### 2.4 Seguridad operativa del mensaje

| Mecanismo | Error / efecto |
|-----------|----------------|
| `srcChainId` + `srcAddress` vs `peers` | `InvalidSourceSender` |
| `dstChainId` / `dstAddress` locales | `UnsupportedChain` / `InvalidPeer` |
| `processedMessages[messageHash]` | `MessageAlreadyProcessed` (anti-replay) |
| `quote` + `msg.value >= fee` + refund | `InsufficientFee` / `EthRefundFailed` |
| `nonReentrant` en send/receive | SWC-107 |
| Custom errors | Gas + claridad (suite rule) |
| Pragma fijo `0.8.24` | Sin floating pragma |

Orden en `receivePacket` (CEI): validar → hash → marcar processed → llamar app → evento.  
Si la app revierte, **toda** la tx revierte y el hash **no** queda marcado (retry posible).

### 2.5 App desacoplada

`IMessageReceiver.onMessageReceived(...)` es opcional (`receiver` puede ser `address(0)`).  
Demo: `RemoteStakeReceiver` interpreta el payload (stake remoto). El messenger no conoce staking.

### 2.6 Tooling

- Foundry, fuzz ≥ 1000 en libs, dual-fork opcional, `Deploy` + `SimulateRelay`.
- Optimizer `runs = 10_000` + `via_ir` (hot path de envío/recepción).

---

## 3. Lógica que sigue el sistema

### 3.1 Piezas y roles

```
Usuario / dApp
    │  send(dstChainId, payload) + ETH fee
    ▼
CrossChainMessenger (origen)
    │  arma Packet, quote, dispatch(fee)
    ▼
ITransportAdapter  ──►  LZ endpoint / CCIP router / MockRelayer
    │
    │  (off-chain o mock deliver)
    ▼
Deliverer / Adapter (destino)  ──►  receivePacket(Packet)
    ▼
CrossChainMessenger (destino)
    │  auth + peers + anti-replay
    ▼
IMessageReceiver (opcional)  ──►  p.ej. RemoteStakeReceiver
```

### 3.2 Send (cadena origen) — paso a paso

1. ¿Existe `peers[dstChainId]`? Si no → `UnsupportedChain`.
2. ¿Hay `adapter`? Si no → `ZeroAddress`.
3. `fee = adapter.quote(...)`; si `msg.value < fee` → `InsufficientFee`.
4. `outboundNonces[dst]++` (unchecked tras lógica segura).
5. Construye `Packet`: `src = localChainId / _selfPeer`, `dst = dstChainId / peer remoto`, `nonce`, `payload`.
6. `messageHash = PacketCodec.messageHash(packet)` (para evento / correlacionar).
7. `adapter.dispatch{value: fee}(...)`.
8. `FeeRefundLib.refundExcessAssembly(msg.sender, fee)` — sobrante a quien pagó.
9. Emite `MessageSent`.

### 3.3 Receive (cadena destino) — paso a paso

1. Solo si `msg.sender == deliverer` → si no `UnauthorizedCaller`.
2. `packet.dstChainId == localChainId` y `dstAddress == _selfPeer`.
3. `peers[srcChainId] == packet.srcAddress` → si no `InvalidSourceSender`.
4. `messageHashCalldata(packet)` (hash sin copiar el struct a memory).
5. Si ya procesado → `MessageAlreadyProcessed`.
6. **Effects:** `processedMessages[hash] = true`.
7. **Interactions:** si hay `receiver`, `onMessageReceived(srcChainId, srcAddress, payload)`.
8. Emite `MessageReceived`.

### 3.4 Paths de transporte

| Path | Quién entrega | Extra check en adapter |
|------|---------------|------------------------|
| Mock | `MockRelayer` / deliverer | Ninguno más allá del messenger |
| LayerZero V2 | `lzReceive` → decodeYul → `receivePacket` | `msg.sender == endpoint` + peer LZ (`lzPeers`) |
| CCIP | `ccipReceive` → decodeYul → `receivePacket` | `msg.sender == router` + peer CCIP |

Doble capa de auth en LZ/CCIP: transporte (endpoint/router + peer del adapter) **y** messenger (deliverer + peers AMP).

### 3.5 Demo RemoteStake

Origen envía payload ABI con acción de stake; destino `RemoteStakeReceiver` actualiza balances locales tras un mensaje **ya autenticado** por el messenger. No mueve tokens cross-chain por sí mismo: demuestra **ejecución remota controlada**.

---

## 4. Gas: qué ya se hizo

Baseline en [`GAS-ES.md`](./GAS-ES.md) (Fase 7):

| Técnica | Efecto aproximado |
|---------|-------------------|
| `decodeYul` vs `abi.decode` | ~**−1 040** gas (wire adapters) |
| `refundExcessAssembly` vs `.call` | ~**−64** gas (refund aislado) |
| `messageHashCalldata` en receive | Evita copia memory del `Packet` |
| `_selfPeer` immutable | Sin `addressToBytes32(this)` por tx |
| `encodePacked` en Yul | Sin `bytes.concat` multi-alloc |
| Cache `adapter_` / `receiver_` | Menos SLOAD |
| Custom errors + optimizer 10k + via_ir | Reverts e inlining más baratos |

Send exact fee ~**294 919**; receive e2e (con mocks) ~**362 756** (incluye send + relay + mock app en el test).

---

## 5. ¿Se puede mejorar más el gas?

Sí, pero con tradeoffs claros. Ordenado de **más realista** a **más agresivo / riesgoso**.

### 5.1 Mejoras razonables (v1.1)

| Idea | Dónde | Nota |
|------|-------|------|
| Evitar `quote` interno si el caller pasa `maxFee` / fee firmado | `send` | Hoy cada `send` llama otra vez a `quote` (extra external/view). Un `sendWithFee(fee)` o confiar en fee del cliente + check `msg.value >= fee` ahorra una llamada si el adapter quote es caro |
| No emitir `payload` completo en eventos | `MessageSent` / `MessageReceived` | Indexar solo `messageHash` + longitudes; el payload se lee off-chain. Ahorro grande si payloads son grandes |
| Packed también en el path mock (si no se usa ABI) | MockRelayer | Consistencia y menos decode ABI en lab |
| `transient storage` (Cancun) para flags efímeros | Solo si el protocolo lo necesita | No aplica a `processedMessages` (debe ser permanente) |
| Reducir SSTORE de `processedMessages` a bitmap / packing | Mapping actual es claro | Bitmaps por `(srcChain, nonce)` pueden ahorrar si el modelo de id cambia; hoy el id es hash del paquete completo |

### 5.2 Mejoras medias (más diseño)

| Idea | Tradeoff |
|------|----------|
| Identidad de mensaje = `(srcChainId, srcAddress, nonce)` en vez de hash de todo el packet | Menos hashing; hay que garantizar unicidad de nonce y no incluir payload en el id (replay de mismo nonce con otro payload queda imposible si el nonce es monotónico por peer) |
| Un solo contrato messenger+adapter en lab | Menos calls externos; peor separación y tests |
| Quitar `ReentrancyGuard` y confiar solo en CEI | Ahorro de SLOAD/SSTORE del guard; **no recomendado** mientras haya callback a `receiver` |
| `calldata` end-to-end sin `Packet memory` en `send` | Hoy se arma `Packet memory` para hash + dispatch; un encode streaming a adapter podría reducir memory |

### 5.3 Mejoras agresivas (solo si se mide y se acepta complejidad)

| Idea | Riesgo |
|------|--------|
| Custom storage layout / Yul en `receivePacket` entero | Legibilidad y auditoría más difíciles |
| Eliminar segundo check de peer en adapter *o* en messenger | Ahorro, pero se pierde defensa en profundidad |
| Fee en storage cacheado por destino | Stale fees / griefing económico |

### 5.4 Qué **no** conviene “optimizar” a ciegas

- **Borrar anti-replay o peers** por gas → rompe el modelo de seguridad.
- **Marcar processed después** de la app → abre reentrancy / doble ejecución si el receiver es malicioso.
- **Usar `transfer`/`send` para refund** → límite 2300 gas; suite lo prohíbe.
- Confundir el harness de gas: `messageHashCalldata` puede verse “más caro” en el test si re-encodea el struct; en producción el receive ya recibe `calldata`.

### 5.5 Dónde está el verdadero coste

En paths LZ/CCIP e2e, la mayor parte del gas no es el codec Yul: es **storage** (`processedMessages`, nonces, peers), **calls externos** (endpoint/router/messenger/app) y **tamaño del payload**. Optimizar solo el decode sin tocar eventos/storage/external calls tiene retorno decreciente.

Recomendación práctica: medir con `forge snapshot` / `--gas-report` tras cada cambio; priorizar **eventos sin payload** y **evitar doble quote** si se busca el siguiente −5–15% realista en `send`.

---

## 6. Mapa mental rápido

| Pregunta | Respuesta corta |
|----------|-----------------|
| ¿Quién puede enviar? | Cualquiera que pague el fee; el origen del mensaje es **este** messenger (`_selfPeer`) |
| ¿Quién puede recibir? | Solo el `deliverer` (o adapter configurado como tal) |
| ¿Qué evita spoofing? | `peers[srcChainId] == srcAddress` (+ peers LZ/CCIP en adapters) |
| ¿Qué evita replay? | `processedMessages[messageHash]` |
| ¿Dónde vive la lógica de negocio? | En `IMessageReceiver`, no en el messenger |
| ¿LZ vs CCIP vs mock? | Mismo núcleo; cambia solo el adapter y quién es deliverer |

---

## 7. Archivos clave para leer el código

| Archivo | Rol |
|---------|-----|
| `src/CrossChainMessenger.sol` | Send / receive / peers / fees |
| `src/libraries/PacketCodec.sol` | ABI + packed + hashes |
| `src/libraries/FeeRefundLib.sol` | Refund `.call` vs Yul |
| `src/libraries/PeerLib.sol` | Checks de peer / address |
| `src/adapters/LayerZeroV2Adapter.sol` | Wire LZ packed |
| `src/adapters/CCIPAdapter.sol` | Wire CCIP packed |
| `src/apps/RemoteStakeReceiver.sol` | Demo ejecución remota |
| `test/UnauthorizedSender.t.sol` | Spoofing debe revertir |
| `test/ReplayProtection.t.sol` | Replay debe revertir |
| `test/gas/Codec.gas.t.sol` | Baseline de gas |

---

*Documento orientado a lectura humana del v1 cerrado (fases 0–7). Cifras de gas: baseline 2026-09-13 en `doc/GAS-ES.md`.*
