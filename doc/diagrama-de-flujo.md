# Diagrama de flujo — Quote, send, verify y execute

Flujos de decisión internos del messenger y adapters (módulo 16, **v1 implementado**).

## 1. quoteSend + send (cadena origen)

```mermaid
flowchart TD
    A[Usuario: send dstChainId, payload + msg.value] --> B{¿peers dstChainId != 0?}
    B -->|No| Z1[Revert UnsupportedChain]
    B -->|Sí| C{¿adapter configurado?}
    C -->|No| Z0[Revert ZeroAddress]
    C -->|Sí| D[fee = adapter.quote]
    D --> E{¿msg.value >= fee?}
    E -->|No| Z2[Revert InsufficientFee]
    E -->|Sí| F[nonce++ / Packet con _selfPeer]
    F --> G[messageHash = PacketCodec.messageHash]
    G --> H[adapter.dispatch value fee]
    H --> I[FeeRefundLib.refundExcessAssembly]
    I --> J{¿refund OK?}
    J -->|No| Z3[Revert EthRefundFailed]
    J -->|Sí| K[Emit MessageSent / return messageHash]
    Z0 --> End([Fin — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    K --> Ok([Fin — OK])
```

> Producción: `refundExcessAssembly` (Yul). Tests comparan vs `refundExcess` (`.call`) — ver [`GAS.md`](./GAS.md).

---

## 2. receivePacket (cadena destino)

```mermaid
flowchart TD
    A[Deliverer: receivePacket] --> B{¿msg.sender == deliverer?}
    B -->|No| Z1[Revert UnauthorizedCaller]
    B -->|Sí| C{¿dstChainId == localChainId?}
    C -->|No| Z2[Revert UnsupportedChain]
    C -->|Sí| D{¿dstAddress == _selfPeer?}
    D -->|No| Z3[Revert InvalidPeer]
    D -->|Sí| E{¿peers srcChainId == srcAddress?}
    E -->|No| Z4[Revert InvalidSourceSender]
    E -->|Sí| F[hash = messageHashCalldata]
    F --> G{¿ya processed?}
    G -->|Sí| Z5[Revert MessageAlreadyProcessed]
    G -->|No| H[processedMessages hash = true]
    H --> I{¿receiver != 0?}
    I -->|Sí| J[onMessageReceived]
    I -->|No| K[Emit MessageReceived]
    J --> K
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    K --> Ok([Fin — OK])
```

> Validación de payload app (`ZeroAmount`, etc.) ocurre **dentro** del receiver; si revierte, toda la tx revierte y el hash no queda marcado.

---

## 3. LayerZero V2 path (mock / lab)

```mermaid
flowchart TD
    A[dispatch vía LayerZeroV2Adapter] --> B[encodePacked packet]
    B --> C[endpoint.send]
    C --> D[MockEndpoint.deliver]
    D --> E[lzReceive en adapter destino]
    E --> F{¿msg.sender == endpoint?}
    F -->|No| R[UnauthorizedCaller]
    F -->|Sí| G{¿origin.sender == lzPeers srcEid?}
    G -->|No| S[InvalidSourceSender]
    G -->|Sí| H[decodeYul → receivePacket]
    H --> Ok([Mensaje ejecutado])
    R --> Fail([Revert])
    S --> Fail
```

---

## 4. Chainlink CCIP path (mock / lab)

```mermaid
flowchart TD
    A[dispatch vía CCIPAdapter] --> B[encodePacked en data]
    B --> C[router.ccipSend]
    C --> D[MockRouter.deliver]
    D --> E[ccipReceive en adapter destino]
    E --> F{¿msg.sender == router?}
    F -->|No| R[UnauthorizedCaller]
    F -->|Sí| G{¿sender == ccipPeers selector?}
    G -->|No| S[InvalidSourceSender]
    G -->|Sí| H[decodeYul → receivePacket]
    H --> Ok([Mensaje ejecutado])
    R --> Fail([Revert])
    S --> Fail
```

---

## 5. RemoteStakeReceiver — ejecución remota

```mermaid
flowchart TD
    A[onMessageReceived] --> B{¿msg.sender == messenger?}
    B -->|No| Z0[UnauthorizedCaller]
    B -->|Sí| C[abi.decode: user, amount, isStake]
    C --> D{¿user != 0 y amount > 0?}
    D -->|No| Z[ZeroAddress / ZeroAmount]
    D -->|Sí| E{¿isStake?}
    E -->|Sí| F[staked user += amount]
    E -->|No| G{¿staked >= amount?}
    G -->|No| Z2[InvalidPayload]
    G -->|Sí| H[staked user -= amount]
    F --> I[Emit StakeUpdated]
    H --> I
    Z0 --> End([Fin])
    Z --> End
    Z2 --> End
    I --> Ok([Fin — OK])
```

---

## 6. Anti-replay

```mermaid
flowchart TD
    A[Receive del mismo Packet] --> B[hash = messageHashCalldata]
    B --> C{¿processedMessages?}
    C -->|Sí| D[MessageAlreadyProcessed]
    C -->|No| E[Marcar + ejecutar]
    D --> Fail([Revert])
    E --> Ok([Una sola ejecución])
```

---

## 7. Unauthorized sender

```mermaid
flowchart TD
    A[Packet con payload válido] --> B[srcAddress vs peers srcChainId]
    B --> C{¿match?}
    C -->|No| D[InvalidSourceSender]
    C -->|Sí| E[Continuar a idempotencia]
    D --> Fail([Revert — spoofing bloqueado])
    E --> Ok([Path legítimo])
```
