# Flow diagram — Quote, send, verify, and execute

**Language:** English · [Español](./diagrama-de-flujo-ES.md)

Internal decision flows of the messenger and adapters (module 16, **v1 implemented**).

## 1. quoteSend + send (source chain)

```mermaid
flowchart TD
    A[User: send dstChainId, payload + msg.value] --> B{peers dstChainId != 0?}
    B -->|No| Z1[Revert UnsupportedChain]
    B -->|Yes| C{adapter configured?}
    C -->|No| Z0[Revert ZeroAddress]
    C -->|Yes| D[fee = adapter.quote]
    D --> E{msg.value >= fee?}
    E -->|No| Z2[Revert InsufficientFee]
    E -->|Yes| F[nonce++ / Packet with _selfPeer]
    F --> G[messageHash = PacketCodec.messageHash]
    G --> H[adapter.dispatch value fee]
    H --> I[FeeRefundLib.refundExcessAssembly]
    I --> J{refund OK?}
    J -->|No| Z3[Revert EthRefundFailed]
    J -->|Yes| K[Emit MessageSent / return messageHash]
    Z0 --> End([End — revert])
    Z1 --> End
    Z2 --> End
    Z3 --> End
    K --> Ok([End — OK])
```

> Production: `refundExcessAssembly` (Yul). Tests compare it against `refundExcess` (`.call`) — see [`GAS-EN.md`](./GAS-EN.md).

---

## 2. receivePacket (destination chain)

```mermaid
flowchart TD
    A[Deliverer: receivePacket] --> B{msg.sender == deliverer?}
    B -->|No| Z1[Revert UnauthorizedCaller]
    B -->|Yes| C{dstChainId == localChainId?}
    C -->|No| Z2[Revert UnsupportedChain]
    C -->|Yes| D{dstAddress == _selfPeer?}
    D -->|No| Z3[Revert InvalidPeer]
    D -->|Yes| E{peers srcChainId == srcAddress?}
    E -->|No| Z4[Revert InvalidSourceSender]
    E -->|Yes| F[hash = messageHashCalldata]
    F --> G{already processed?}
    G -->|Yes| Z5[Revert MessageAlreadyProcessed]
    G -->|No| H[processedMessages hash = true]
    H --> I{receiver != 0?}
    I -->|Yes| J[onMessageReceived]
    I -->|No| K[Emit MessageReceived]
    J --> K
    Z1 --> End([End — revert])
    Z2 --> End
    Z3 --> End
    Z4 --> End
    Z5 --> End
    K --> Ok([End — OK])
```

> App payload validation (`ZeroAmount`, etc.) happens **inside** the receiver; if it reverts, the whole tx reverts and the hash is not marked.

---

## 3. LayerZero V2 path (mock / lab)

```mermaid
flowchart TD
    A[dispatch via LayerZeroV2Adapter] --> B[encodePacked packet]
    B --> C[endpoint.send]
    C --> D[MockEndpoint.deliver]
    D --> E[lzReceive on destination adapter]
    E --> F{msg.sender == endpoint?}
    F -->|No| R[UnauthorizedCaller]
    F -->|Yes| G{origin.sender == lzPeers srcEid?}
    G -->|No| S[InvalidSourceSender]
    G -->|Yes| H[decodeYul → receivePacket]
    H --> Ok([Message executed])
    R --> Fail([Revert])
    S --> Fail
```

---

## 4. Chainlink CCIP path (mock / lab)

```mermaid
flowchart TD
    A[dispatch via CCIPAdapter] --> B[encodePacked into data]
    B --> C[router.ccipSend]
    C --> D[MockRouter.deliver]
    D --> E[ccipReceive on destination adapter]
    E --> F{msg.sender == router?}
    F -->|No| R[UnauthorizedCaller]
    F -->|Yes| G{sender == ccipPeers selector?}
    G -->|No| S[InvalidSourceSender]
    G -->|Yes| H[decodeYul → receivePacket]
    H --> Ok([Message executed])
    R --> Fail([Revert])
    S --> Fail
```

---

## 5. RemoteStakeReceiver — remote execution

```mermaid
flowchart TD
    A[onMessageReceived] --> B{msg.sender == messenger?}
    B -->|No| Z0[UnauthorizedCaller]
    B -->|Yes| C[abi.decode: user, amount, isStake]
    C --> D{user != 0 and amount > 0?}
    D -->|No| Z[ZeroAddress / ZeroAmount]
    D -->|Yes| E{isStake?}
    E -->|Yes| F[staked user += amount]
    E -->|No| G{staked >= amount?}
    G -->|No| Z2[InvalidPayload]
    G -->|Yes| H[staked user -= amount]
    F --> I[Emit StakeUpdated]
    H --> I
    Z0 --> End([End])
    Z --> End
    Z2 --> End
    I --> Ok([End — OK])
```

---

## 6. Anti-replay

```mermaid
flowchart TD
    A[Receive of the same Packet] --> B[hash = messageHashCalldata]
    B --> C{processedMessages?}
    C -->|Yes| D[MessageAlreadyProcessed]
    C -->|No| E[Mark + execute]
    D --> Fail([Revert])
    E --> Ok([Single execution])
```

---

## 7. Unauthorized sender

```mermaid
flowchart TD
    A[Packet with valid payload] --> B[srcAddress vs peers srcChainId]
    B --> C{match?}
    C -->|No| D[InvalidSourceSender]
    C -->|Yes| E[Continue to idempotency]
    D --> Fail([Revert — spoofing blocked])
    E --> Ok([Legitimate path])
```
