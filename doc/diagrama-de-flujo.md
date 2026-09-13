# Diagrama de flujo — Quote, send, verify y execute

Flujos de decisión internos del messenger y adapters (módulo 16, **v1 implementado**).

## 1. quoteSend + send (cadena origen)

```mermaid
flowchart TD
    A[Usuario: send dstChainId, payload + msg.value] --> B{¿dst peer configurado?}
    B -->|No| Z1[Revert UnsupportedChain / InvalidPeer]
    B -->|Sí| C[fee = adapter.quote]
    C --> D{¿msg.value >= fee?}
    D -->|No| Z2[Revert InsufficientFee]
    D -->|Sí| E[nonce++ / armar Packet]
    E --> F[messageHash = PacketCodec.messageHash]
    F --> G[adapter.dispatch packet]
    G --> H[FeeRefundLib.refundExcess]
    H --> I{¿refund OK?}
    I -->|No| Z3[Revert EthRefundFailed]
    I -->|Sí| J[Emit MessageSent / return messageHash]
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    J --> Ok([Fin — OK])
```

> El refund usa `.call{value: ...}("")` hacia `msg.sender` (o `refundTo` explícito).

---

## 2. receivePacket (cadena destino)

```mermaid
flowchart TD
    A[Adapter / MockRelayer: receivePacket] --> B{¿caller autorizado? endpoint/router/relayer}
    B -->|No| Z1[Revert UnauthorizedCaller]
    B -->|Sí| C{¿peers srcChainId == srcAddress?}
    C -->|No| Z2[Revert InvalidSourceSender]
    C -->|Sí| D[hash = PacketCodec.messageHash]
    D --> E{¿processedMessages hash?}
    E -->|Sí| Z3[Revert MessageAlreadyProcessed]
    E -->|No| F[processedMessages hash = true]
    F --> G{¿payload válido?}
    G -->|No| Z4[Revert InvalidPayload]
    G -->|Sí| H[IMessageReceiver.onMessageReceived opcional]
    H --> I[Emit MessageReceived]
    Z1 --> End([Fin — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    I --> Ok([Fin — OK])
```

> Orden CEI: checks → effect (`processedMessages`) → interaction (receiver).

---

## 3. LayerZero V2 path (mock / real)

```mermaid
flowchart TD
    A[dispatch vía LayerZeroV2Adapter] --> B[endpoint.quote / send]
    B --> C[Relayer / MockEndpoint.deliver]
    C --> D[lzReceive en adapter destino]
    D --> E{¿msg.sender == endpoint?}
    E -->|No| R[UnauthorizedCaller]
    E -->|Sí| F[decode message → Packet]
    F --> G[messenger.receivePacket]
    G --> H{¿InvalidSourceSender / replay?}
    H -->|Sí| Fail([Revert])
    H -->|No| Ok([Mensaje ejecutado])
    R --> Fail
```

---

## 4. Chainlink CCIP path (mock / real)

```mermaid
flowchart TD
    A[dispatch vía CCIPAdapter] --> B[router.getFee / ccipSend]
    B --> C[MockRouter.deliver / red CCIP]
    C --> D[ccipReceive en adapter destino]
    D --> E{¿msg.sender == router?}
    E -->|No| R[UnauthorizedCaller]
    E -->|Sí| F[extraer sender + data → Packet]
    F --> G[messenger.receivePacket]
    G --> H{¿peer + idempotencia OK?}
    H -->|No| Fail([InvalidSourceSender / MessageAlreadyProcessed])
    H -->|Sí| Ok([Mensaje ejecutado])
    R --> Fail
```

---

## 5. RemoteStakeReceiver — ejecución remota

```mermaid
flowchart TD
    A[onMessageReceived srcChainId, srcAddress, payload] --> B[abi.decode: user, amount, isStake]
    B --> C{¿amount > 0?}
    C -->|No| Z[Revert ZeroAmount / InvalidPayload]
    C -->|Sí| D{¿isStake?}
    D -->|Sí| E[staked user += amount]
    D -->|No| F{¿staked user >= amount?}
    F -->|No| Z2[Revert InvalidPayload]
    F -->|Sí| G[staked user -= amount]
    E --> H[Emit StakeUpdated]
    G --> H
    Z --> End([Fin])
    Z2 --> End
    H --> Ok([Fin — OK])
```

> El receiver **no** re-verifica peers: confía en que solo el messenger autenticado lo invoca.

---

## 6. Anti-replay transversal

```mermaid
flowchart TD
    A[Cualquier receive del mismo Packet] --> B[hash = messageHash]
    B --> C{¿ya processed?}
    C -->|Sí| D[MessageAlreadyProcessed]
    C -->|No| E[Marcar processed + ejecutar]
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
