# Flujograma — Ciclo completo Cross-Chain Messaging

Flujo extremo a extremo entre actores, messenger, adapters y relayer (módulo 16, **v1 implementado**).

## Actores

| Actor | Rol |
|-------|-----|
| Usuario / dApp | Paga fee nativo; llama `send` con payload |
| CrossChainMessenger (origen) | Quote, arma `Packet`, dispatch, `refundExcessAssembly` |
| Transport adapter (LZ / CCIP / mock) | Habla con endpoint/router; wire packed Yul en LZ/CCIP |
| Relayer / MockRelayer / red LZ-CCIP | Entrega el mensaje a destino |
| CrossChainMessenger (destino) | Deliverer + peer + `messageHashCalldata` + anti-replay |
| RemoteStakeReceiver | Aplica stake/unstake del payload |
| Admin / owner | setPeer / setAdapter / setDeliverer / setReceiver |
| CI / Foundry | Unit, fuzz libs, dual-fork skip, gas snapshot |

---

## Flujograma — Deploy + peers

```mermaid
flowchart TD
    Start([Inicio]) --> Dep[Deploy.s.sol: messengers + mock transport + relayer + stake]
    Dep --> Own[Ownable2Step]
    Own --> Peer[setPeer src ↔ dst]
    Peer --> Del[setDeliverer MockRelayer o adapter]
    Del --> Adapt[setAdapter mock; opcional LZ/CCIP cableados]
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
    Disp --> Ref[refundExcessAssembly a msg.sender]
    Ref --> Net[Red LZ / CCIP / MockRelayer]
    Net --> Rec[receive en destino: adapter o deliverer]
    Rec --> Auth{¿caller autorizado?}
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
    A[Mensaje entrante] --> B[1. Caller = deliverer]
    B --> C[2. dstChainId / dstAddress = local]
    C --> D[3. Peer srcChainId / srcAddress]
    D --> E[4. messageHash no procesado]
    E --> F[5. Hook app opcional]
    B -.->|fail| X1[UnauthorizedCaller]
    C -.->|fail| X2[UnsupportedChain / InvalidPeer]
    D -.->|fail| X3[InvalidSourceSender]
    E -.->|fail| X4[MessageAlreadyProcessed]
    F -.->|fail| X5[Errores app p.ej. ZeroAmount]
    F --> Ok([Éxito])
```

---

## Flujograma — Fees y refund

```mermaid
flowchart TD
    Start([msg.value en send]) --> Q[fee = quote]
    Q --> Pay[adapter.dispatch value fee]
    Pay --> Diff[excess = msg.value - fee]
    Diff --> Z{¿excess > 0?}
    Z -->|No| Done([Sin refund])
    Z -->|Sí| Call[Yul call value excess a msg.sender]
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
| Caller ≠ deliverer (o ≠ endpoint/router en adapter) | `UnauthorizedCaller` |
| Receptor de refund rechaza ETH | `EthRefundFailed` (send revierte) |

---

## Relación con otros diagramas

- Estructura de tipos: [`diagrama-de-clases.md`](./diagrama-de-clases.md)
- Decisiones internas detalladas: [`diagrama-de-flujo.md`](./diagrama-de-flujo.md)
- Fases / gas / SWC: [`planificacion.md`](./planificacion.md) · [`GAS.md`](./GAS.md) · [`SWC-AUDIT.md`](./SWC-AUDIT.md)
