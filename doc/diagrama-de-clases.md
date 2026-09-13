# Diagrama de clases — Cross-Chain Messaging & Interoperability

Vista estructural de contratos, adapters, librerías e interfaces (módulo 16, **diseño v1**).

## Diagrama (Mermaid)

```mermaid
classDiagram
    direction TB

    class ICrossChainMessenger {
        <<interface>>
        +quoteSend(dstChainId, payload) uint256 fee
        +send(dstChainId, payload) bytes32 messageHash
        +peers(chainId) bytes32
        +setPeer(chainId, peer)
        +processedMessages(hash) bool
    }

    class IMessageReceiver {
        <<interface>>
        +onMessageReceived(srcChainId, srcAddress, payload)
    }

    class ITransportAdapter {
        <<interface>>
        +quote(dstChainId, payload) uint256 fee
        +dispatch(dstChainId, packet, refundTo) bytes32
    }

    class ILayerZeroEndpointV2 {
        <<interface>>
        +quote(params, payInLzToken) MessagingFee
        +send(params, refundAddress) MessagingReceipt
    }

    class ICCIPRouter {
        <<interface>>
        +getFee(destinationChainSelector, message) uint256
        +ccipSend(destinationChainSelector, message) bytes32
    }

    class MessagingErrors {
        <<errors>>
        +InvalidSourceSender()
        +MessageAlreadyProcessed()
        +InsufficientFee()
        +EthRefundFailed()
        +ZeroAddress()
        +InvalidPeer()
        +InvalidPayload()
        +UnauthorizedCaller()
        +UnsupportedChain()
        +ZeroAmount()
    }

    class Packet {
        <<struct>>
        +srcChainId uint64
        +dstChainId uint64
        +srcAddress bytes32
        +dstAddress bytes32
        +nonce uint64
        +payload bytes
    }

    class PacketCodec {
        <<library>>
        +encode(packet) bytes
        +decode(data) Packet
        +messageHash(packet) bytes32
        +decodeYul(data) Packet
    }

    class PeerLib {
        <<library>>
        +addressToBytes32(addr) bytes32
        +bytes32ToAddress(b) address
        +requirePeer(expected, actual)
    }

    class FeeRefundLib {
        <<library>>
        +refundExcess(refundTo, spent)
    }

    class CrossChainMessenger {
        +endpointOrRouter address
        +peers mapping
        +processedMessages mapping
        +nonces mapping
        +quoteSend(dstChainId, payload) uint256
        +send(dstChainId, payload) bytes32
        +receivePacket(packet)
        +setPeer(chainId, peer)
        +setAdapter(adapter)
    }

    class LayerZeroV2Adapter {
        +endpoint ILayerZeroEndpointV2
        +messenger CrossChainMessenger
        +quote(dstChainId, payload) uint256
        +dispatch(dstChainId, packet, refundTo) bytes32
        +lzReceive(origin, guid, message, executor, extraData)
    }

    class CCIPAdapter {
        +router ICCIPRouter
        +messenger CrossChainMessenger
        +quote(dstChainId, payload) uint256
        +dispatch(dstChainId, packet, refundTo) bytes32
        +ccipReceive(message)
    }

    class RemoteStakeReceiver {
        +staked mapping
        +onMessageReceived(srcChainId, srcAddress, payload)
        +_decodeStake(payload) address, uint256, bool
    }

    class MockLayerZeroEndpoint {
        <<mock>>
        +quote(...) MessagingFee
        +send(...) MessagingReceipt
        +deliver(to, origin, message)
    }

    class MockCCIPRouter {
        <<mock>>
        +getFee(...) uint256
        +ccipSend(...) bytes32
        +deliver(to, message)
    }

    class MockRelayer {
        <<mock>>
        +relay(srcMessenger, dstMessenger, packet)
    }

    ICrossChainMessenger <|.. CrossChainMessenger
    IMessageReceiver <|.. RemoteStakeReceiver
    ITransportAdapter <|.. LayerZeroV2Adapter
    ITransportAdapter <|.. CCIPAdapter
    ILayerZeroEndpointV2 <|.. MockLayerZeroEndpoint
    ICCIPRouter <|.. MockCCIPRouter

    CrossChainMessenger --> ITransportAdapter : uses
    CrossChainMessenger --> PacketCodec : encode/hash
    CrossChainMessenger --> PeerLib : verify peer
    CrossChainMessenger --> FeeRefundLib : refund fee
    CrossChainMessenger --> MessagingErrors : reverts
    CrossChainMessenger o-- Packet : builds
    CrossChainMessenger --> IMessageReceiver : optional hook

    LayerZeroV2Adapter --> ILayerZeroEndpointV2
    LayerZeroV2Adapter --> CrossChainMessenger
    CCIPAdapter --> ICCIPRouter
    CCIPAdapter --> CrossChainMessenger

    MockRelayer --> CrossChainMessenger : deliver
    PacketCodec ..> Packet : manipulates
```

---

## Relaciones clave

| Relación | Descripción |
|----------|-------------|
| Messenger → Adapter | El núcleo no conoce LZ/CCIP; solo `ITransportAdapter` |
| Adapter → Endpoint/Router | Solo el endpoint/router mockeado (o real) puede llamar receive |
| Messenger → PeerLib | `srcAddress` debe coincidir con `peers[srcChainId]` |
| Messenger → PacketCodec | Hash único para `processedMessages` |
| Messenger → FeeRefundLib | Tras `dispatch`, refund de `msg.value - fee` |
| Receiver app | `RemoteStakeReceiver` consume `payload` ya autenticado |

---

## Notas de diseño

- `Ownable2Step` + `ReentrancyGuard` en `CrossChainMessenger` y adapters que muevan ETH.
- Marcar `processedMessages[hash]` **antes** de llamar a `IMessageReceiver` (CEI / anti-reentrancy de mensaje).
- Adapters reales en testnets: mismas interfaces; mocks cubren CI sin RPC.
