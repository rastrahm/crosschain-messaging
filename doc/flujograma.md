# Flujograma — Ciclo completo Cross-Chain Messaging

Flujo extremo a extremo entre actores, messenger, adapters y relayer (módulo 16, **diseño v1**).

## Actores

| Actor | Rol |
|-------|-----|
| Usuario / dApp | Paga fee nativo; llama `send` con payload |
| CrossChainMessenger (origen) | Quote, arma `Packet`, dispatch, refund |
| Transport adapter (LZ / CCIP / mock) | Habla con endpoint o router |
| Relayer / MockRelayer / red LZ-CCIP | Entrega el mensaje a destino |
| CrossChainMessenger (destino) | Verifica peer, anti-replay, ejecuta |
| RemoteStakeReceiver | Aplica efecto de negocio del payload |
| Admin / owner | Configura peers, adapters, ownership 2-step |
| CI / Foundry | Unit, fuzz, dual-fork, gas ABI vs Yul |

---

## Flujograma — Deploy + peers

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol: messengers + adapters + mocks]
    Dep --> Own[Ownable2Step en messenger / adapters]
    Own --> Peer[setPeer: src ↔ dst addresses por chainId]
    Peer --> Adapt[setAdapter LZ y/o CCIP]
    Adapt --> Ready([Listo lab / fork / Anvil])
```

---

## Flujograma principal — Origen → destino

```mermaid
flowchart TD
    Start([Usuario arma payload]) --> Quote[quoteSend dstChainId, payload]
    Quote --> Fee{¿ETH >= fee?}
    Fee -->|No| Abort[InsufficientFee]
    Fee -->|Sí| Send[send: Packet + nonce]
    Send --> Disp[adapter.dispatch]
    Disp --> Ref[refundExcess a msg.sender]
    Ref --> Net[Red LZ / CCIP / MockRelayer]
    Net --> Rec[adapter receive en destino]
    Rec --> Auth{¿caller = endpoint/router?}
    Auth -->|No| U1[UnauthorizedCaller]
    Auth -->|Sí| Peer{¿srcAddress = peers srcChainId?}
    Peer -->|No| U2[InvalidSourceSender]
    Peer -->|Sí| Replay{¿messageHash ya visto?}
    Replay -->|Sí| R1[MessageAlreadyProcessed]
    Replay -->|No| Mark[processedMessages = true]
    Mark --> App[RemoteStakeReceiver.onMessageReceived]
    App --> Done([Estado sincronizado / stake actualizado])
    Abort --> End([Fin])
    U1 --> End
    U2 --> End
    R1 --> End
    Done --> End
```

---

## Flujograma — Dual-fork (tests)

```mermaid
flowchart TD
    Start([forge test DualFork]) --> RPC{¿SRC_RPC y DST_RPC?}
    RPC -->|No| Skip[vm.skip — CI verde]
    RPC -->|Sí| F1[createSelectFork origen]
    F1 --> S1[messengerOrigen.send]
    S1 --> Cap[Capturar Packet / evento]
    Cap --> F2[createSelectFork destino]
    F2 --> Rel[MockRelayer / deliver adapter]
    Rel --> Rec[receivePacket en destino]
    Rec --> Assert[Assert estado + processedMessages]
    Skip --> End([Fin])
    Assert --> End
```

---

## Flujograma — Capas de defensa

```mermaid
flowchart TD
    A[Mensaje entrante] --> B[1. Caller = transporte autorizado]
    B --> C[2. Peer srcChainId / srcAddress]
    C --> D[3. messageHash no procesado]
    D --> E[4. Payload decodable]
    E --> F[5. Efectos app + eventos]
    B -.->|fail| X1[UnauthorizedCaller]
    C -.->|fail| X2[InvalidSourceSender]
    D -.->|fail| X3[MessageAlreadyProcessed]
    E -.->|fail| X4[InvalidPayload]
    F --> Ok([Éxito])
```

---

## Flujograma — Fees y refund

```mermaid
flowchart TD
    Start([msg.value en send]) --> Q[fee = quote]
    Q --> Pay[adapter cobra fee]
    Pay --> Diff[excess = msg.value - fee]
    Diff --> Z{¿excess > 0?}
    Z -->|No| Done([Sin refund])
    Z -->|Sí| Call[.call value excess a refundTo]
    Call --> Ok{¿success?}
    Ok -->|No| Err[EthRefundFailed]
    Ok -->|Sí| Done2([Refund OK])
    Err --> Fail([Revert total send])
    Done --> End([Fin])
    Done2 --> End
```

---

## Matriz de caminos felices / fallo

| Escenario | Resultado esperado |
|-----------|-------------------|
| Peer correcto + fee OK + primer receive | `MessageReceived` + efecto app |
| Peer incorrecto | `InvalidSourceSender` |
| Mismo hash dos veces | `MessageAlreadyProcessed` |
| `msg.value < fee` | `InsufficientFee` |
| Caller no endpoint/router | `UnauthorizedCaller` |
| Receptor de refund rechaza ETH | `EthRefundFailed` (send revierte) |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas detalladas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases de implementación: [`planificacion.md`](./planificacion.md)
