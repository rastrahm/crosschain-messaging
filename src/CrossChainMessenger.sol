// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICrossChainMessenger} from "./interfaces/ICrossChainMessenger.sol";
import {IMessageReceiver} from "./interfaces/IMessageReceiver.sol";
import {ITransportAdapter} from "./interfaces/ITransportAdapter.sol";
import {MessagingErrors} from "./errors/MessagingErrors.sol";
import {Packet, PacketCodec} from "./libraries/PacketCodec.sol";
import {PeerLib} from "./libraries/PeerLib.sol";
import {FeeRefundLib} from "./libraries/FeeRefundLib.sol";

/**
 * @title CrossChainMessenger
 * @notice Nucleo AMP: peers trusted, quote/send, receive idempotente y hook de app.
 * @dev CEI + `ReentrancyGuard`. Solo `deliverer` puede llamar `receivePacket`.
 *      El fee se paga al `adapter`; el sobrante se refund a `msg.sender`.
 */
contract CrossChainMessenger is ICrossChainMessenger, Ownable2Step, ReentrancyGuard {
    /// @inheritdoc ICrossChainMessenger
    uint64 public immutable override localChainId;

    /// @notice Adapter de transporte actual.
    ITransportAdapter public adapter;

    /// @notice Unico caller autorizado a entregar paquetes (relayer o adapter).
    address public deliverer;

    /// @notice Receptor opcional de payloads autenticados.
    IMessageReceiver public receiver;

    /// @inheritdoc ICrossChainMessenger
    mapping(uint64 chainId => bytes32 peer) public override peers;

    /// @inheritdoc ICrossChainMessenger
    mapping(bytes32 messageHash => bool processed) public override processedMessages;

    /// @notice Nonce outbound por cadena destino.
    mapping(uint64 dstChainId => uint64 nonce) public outboundNonces;

    /// @notice Peer configurado para una cadena remota.
    event PeerSet(uint64 indexed chainId, bytes32 peer);

    /// @notice Adapter actualizado.
    event AdapterUpdated(address indexed adapter);

    /// @notice Deliverer actualizado.
    event DelivererUpdated(address indexed deliverer);

    /// @notice Receiver de app actualizado.
    event ReceiverUpdated(address indexed receiver);

    /// @notice Mensaje despachado en origen.
    event MessageSent(
        bytes32 indexed messageHash, uint64 indexed dstChainId, uint64 nonce, bytes payload
    );

    /// @notice Mensaje ejecutado en destino.
    event MessageReceived(bytes32 indexed messageHash, uint64 indexed srcChainId, bytes payload);

    /**
     * @notice Despliega el messenger en una cadena local.
     * @param localChainId_ Identificador local (eid / chain id de laboratorio).
     * @param owner_ Owner administrativo (`Ownable2Step`).
     */
    constructor(uint64 localChainId_, address owner_) Ownable(owner_) {
        PeerLib.requireNonZero(owner_);
        localChainId = localChainId_;
    }

    /// @inheritdoc ICrossChainMessenger
    function quoteSend(uint64 dstChainId, bytes calldata payload) external view override returns (uint256 fee) {
        if (peers[dstChainId] == bytes32(0)) revert MessagingErrors.UnsupportedChain();
        ITransportAdapter adapter_ = adapter;
        if (address(adapter_) == address(0)) revert MessagingErrors.ZeroAddress();
        return adapter_.quote(dstChainId, payload);
    }

    /// @inheritdoc ICrossChainMessenger
    function send(uint64 dstChainId, bytes calldata payload)
        external
        payable
        override
        nonReentrant
        returns (bytes32 messageHash)
    {
        bytes32 dstPeer = peers[dstChainId];
        if (dstPeer == bytes32(0)) revert MessagingErrors.UnsupportedChain();

        ITransportAdapter adapter_ = adapter;
        if (address(adapter_) == address(0)) revert MessagingErrors.ZeroAddress();

        uint256 fee = adapter_.quote(dstChainId, payload);
        if (msg.value < fee) revert MessagingErrors.InsufficientFee();

        uint64 nonce;
        unchecked {
            nonce = ++outboundNonces[dstChainId];
        }

        Packet memory packet = Packet({
            srcChainId: localChainId,
            dstChainId: dstChainId,
            srcAddress: PeerLib.addressToBytes32(address(this)),
            dstAddress: dstPeer,
            nonce: nonce,
            payload: payload
        });

        messageHash = PacketCodec.messageHash(packet);

        // Effects before external adapter call: nonce already incremented.
        adapter_.dispatch{value: fee}(dstChainId, packet, msg.sender);
        FeeRefundLib.refundExcess(msg.sender, fee);

        emit MessageSent(messageHash, dstChainId, nonce, payload);
    }

    /// @inheritdoc ICrossChainMessenger
    function receivePacket(Packet calldata packet) external override nonReentrant {
        if (msg.sender != deliverer) revert MessagingErrors.UnauthorizedCaller();
        if (packet.dstChainId != localChainId) revert MessagingErrors.UnsupportedChain();
        if (packet.dstAddress != PeerLib.addressToBytes32(address(this))) {
            revert MessagingErrors.InvalidPeer();
        }

        PeerLib.requirePeer(peers[packet.srcChainId], packet.srcAddress);

        bytes32 messageHash = PacketCodec.messageHash(packet);
        if (processedMessages[messageHash]) revert MessagingErrors.MessageAlreadyProcessed();

        // Effects
        processedMessages[messageHash] = true;

        // Interactions
        IMessageReceiver receiver_ = receiver;
        if (address(receiver_) != address(0)) {
            receiver_.onMessageReceived(packet.srcChainId, packet.srcAddress, packet.payload);
        }

        emit MessageReceived(messageHash, packet.srcChainId, packet.payload);
    }

    /**
     * @notice Configura el peer trusted de una cadena remota.
     * @param chainId Cadena remota.
     * @param peer Direccion del messenger remoto en bytes32.
     */
    function setPeer(uint64 chainId, bytes32 peer) external onlyOwner {
        PeerLib.requireConfiguredPeer(peer);
        peers[chainId] = peer;
        emit PeerSet(chainId, peer);
    }

    /**
     * @notice Configura el adapter de transporte.
     * @param adapter_ Contrato `ITransportAdapter`.
     */
    function setAdapter(address adapter_) external onlyOwner {
        PeerLib.requireNonZero(adapter_);
        adapter = ITransportAdapter(adapter_);
        emit AdapterUpdated(adapter_);
    }

    /**
     * @notice Configura quien puede llamar `receivePacket`.
     * @param deliverer_ Relayer o adapter autorizado.
     */
    function setDeliverer(address deliverer_) external onlyOwner {
        PeerLib.requireNonZero(deliverer_);
        deliverer = deliverer_;
        emit DelivererUpdated(deliverer_);
    }

    /**
     * @notice Configura el hook de aplicacion (cero para desactivar).
     * @param receiver_ Implementacion de `IMessageReceiver` o `address(0)`.
     */
    function setReceiver(address receiver_) external onlyOwner {
        receiver = IMessageReceiver(receiver_);
        emit ReceiverUpdated(receiver_);
    }

    receive() external payable {}
}
