# Flowchart — Full Cross-Chain Messaging cycle

**Language:** English · [Español](./flujograma-ES.md)

End-to-end flow between actors, messenger, adapters, and relayer (module 16, **v1 implemented**).

## Actors

| Actor | Role |
|-------|------|
| User / dApp | Pays the native fee; calls `send` with a payload |
| CrossChainMessenger (source) | Quote, builds the `Packet`, dispatch, `refundExcessAssembly` |
| Transport adapter (LZ / CCIP / mock) | Talks to endpoint/router; packed Yul wire on LZ/CCIP |
| Relayer / MockRelayer / LZ-CCIP network | Delivers the message to the destination |
| CrossChainMessenger (destination) | Deliverer + peer + `messageHashCalldata` + anti-replay |
| RemoteStakeReceiver | Applies the stake/unstake from the payload |
| Admin / owner | setPeer / setAdapter / setDeliverer / setReceiver |
| CI / Foundry | Unit, lib fuzz, dual-fork skip, gas snapshot |

---

## Flowchart — Deploy + peers

```mermaid
flowchart TD
    Start([Start]) --> Dep[Deploy.s.sol: messengers + mock transport + relayer + stake]
    Dep --> Own[Ownable2Step]
    Own --> Peer[setPeer src ↔ dst]
    Peer --> Del[setDeliverer MockRelayer or adapter]
    Del --> Adapt[setAdapter mock; optional LZ/CCIP wired]
    Adapt --> Ready([Ready: lab / fork / Anvil])
```

---

## Main flowchart — Source → destination

```mermaid
flowchart TD
    Start([User builds payload]) --> Quote[quoteSend dstChainId, payload]
    Quote --> Fee{ETH >= fee?}
    Fee -->|No| Abort[InsufficientFee]
    Fee -->|Yes| Send[send: Packet + nonce]
    Send --> Disp[adapter.dispatch]
    Disp --> Ref[refundExcessAssembly to msg.sender]
    Ref --> Net[LZ / CCIP network / MockRelayer]
    Net --> Rec[receive on destination: adapter or deliverer]
    Rec --> Auth{caller authorized?}
    Auth -->|No| U1[UnauthorizedCaller]
    Auth -->|Yes| Peer{srcAddress = peers srcChainId?}
    Peer -->|No| U2[InvalidSourceSender]
    Peer -->|Yes| Replay{messageHash already seen?}
    Replay -->|Yes| R1[MessageAlreadyProcessed]
    Replay -->|No| Mark[processedMessages = true]
    Mark --> App[RemoteStakeReceiver.onMessageReceived]
    App --> Done([State synced / stake updated])
    Abort --> End([End])
    U1 --> End
    U2 --> End
    R1 --> End
    Done --> End
```

---

## Flowchart — Dual-fork (tests)

```mermaid
flowchart TD
    Start([forge test DualFork]) --> RPC{SRC_RPC and DST_RPC?}
    RPC -->|No| Skip[vm.skip — green CI]
    RPC -->|Yes| F1[createSelectFork source]
    F1 --> S1[sourceMessenger.send]
    S1 --> Cap[Capture Packet / event]
    Cap --> F2[createSelectFork destination]
    F2 --> Rel[MockRelayer / adapter deliver]
    Rel --> Rec[receivePacket on destination]
    Rec --> Assert[Assert state + processedMessages]
    Skip --> End([End])
    Assert --> End
```

---

## Flowchart — Defense layers

```mermaid
flowchart TD
    A[Incoming message] --> B[1. Caller = deliverer]
    B --> C[2. dstChainId / dstAddress = local]
    C --> D[3. Peer srcChainId / srcAddress]
    D --> E[4. messageHash not processed]
    E --> F[5. Optional app hook]
    B -.->|fail| X1[UnauthorizedCaller]
    C -.->|fail| X2[UnsupportedChain / InvalidPeer]
    D -.->|fail| X3[InvalidSourceSender]
    E -.->|fail| X4[MessageAlreadyProcessed]
    F -.->|fail| X5[App errors e.g. ZeroAmount]
    F --> Ok([Success])
```

---

## Flowchart — Fees and refund

```mermaid
flowchart TD
    Start([msg.value in send]) --> Q[fee = quote]
    Q --> Pay[adapter.dispatch value fee]
    Pay --> Diff[excess = msg.value - fee]
    Diff --> Z{excess > 0?}
    Z -->|No| Done([No refund])
    Z -->|Yes| Call[Yul call value excess to msg.sender]
    Call --> Ok{success?}
    Ok -->|No| Err[EthRefundFailed]
    Ok -->|Yes| Done2([Refund OK])
    Err --> Fail([Whole send reverts])
    Done --> End([End])
    Done2 --> End
```

---

## Happy / failure path matrix

| Scenario | Expected result |
|----------|-----------------|
| Correct peer + fee OK + first receive | `MessageReceived` + app effect |
| Wrong peer | `InvalidSourceSender` |
| Same hash twice | `MessageAlreadyProcessed` |
| `msg.value < fee` | `InsufficientFee` |
| Caller ≠ deliverer (or ≠ endpoint/router in adapter) | `UnauthorizedCaller` |
| Refund recipient rejects ETH | `EthRefundFailed` (send reverts) |

---

## Relation to other diagrams

- Type structure: [`diagrama-de-clases-EN.md`](./diagrama-de-clases-EN.md)
- Detailed internal decisions: [`diagrama-de-flujo-EN.md`](./diagrama-de-flujo-EN.md)
- Phases / gas / SWC: [`planificacion-EN.md`](./planificacion-EN.md) · [`GAS-EN.md`](./GAS-EN.md) · [`SWC-AUDIT-EN.md`](./SWC-AUDIT-EN.md)
