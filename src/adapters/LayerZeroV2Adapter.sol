// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ITransportAdapter} from "../interfaces/ITransportAdapter.sol";
import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {
    ILayerZeroEndpointV2,
    ILayerZeroReceiver,
    MessagingFee,
    MessagingParams,
    MessagingReceipt,
    Origin
} from "../interfaces/ILayerZeroEndpointV2.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";
import {Packet, PacketCodec} from "../libraries/PacketCodec.sol";
import {PeerLib} from "../libraries/PeerLib.sol";

/**
 * @title LayerZeroV2Adapter
 * @notice Puente `ITransportAdapter` <-> Endpoint V2 (quote/send + `lzReceive`).
 * @dev Solo el `messenger` puede `dispatch`. Solo el `endpoint` puede `lzReceive`.
 *      `lzPeers[eid]` apunta al adapter remoto (receiver LZ), distinto de `messenger.peers`.
 */
contract LayerZeroV2Adapter is ITransportAdapter, ILayerZeroReceiver, Ownable2Step, ReentrancyGuard {
    /// @notice Endpoint V2 (mock o real).
    ILayerZeroEndpointV2 public immutable endpoint;

    /// @notice Messenger local que usa este adapter.
    ICrossChainMessenger public messenger;

    /// @notice Peer LZ (adapter remoto) por eid destino.
    mapping(uint64 eid => bytes32 remoteAdapter) public lzPeers;

    /// @notice Options por defecto pasadas al endpoint.
    bytes public defaultOptions;

    /// @notice Peer LZ configurado.
    event LzPeerSet(uint64 indexed eid, bytes32 remoteAdapter);

    /// @notice Messenger actualizado.
    event MessengerUpdated(address indexed messenger);

    /// @notice Options actualizadas.
    event DefaultOptionsUpdated(bytes options);

    /**
     * @notice Despliega el adapter ligado a un endpoint.
     * @param endpoint_ Endpoint V2.
     * @param messenger_ Messenger local (puede ser cero y setearse luego).
     * @param owner_ Owner administrativo.
     */
    constructor(address endpoint_, address messenger_, address owner_) Ownable(owner_) {
        PeerLib.requireNonZero(endpoint_);
        PeerLib.requireNonZero(owner_);
        endpoint = ILayerZeroEndpointV2(endpoint_);
        if (messenger_ != address(0)) {
            messenger = ICrossChainMessenger(messenger_);
        }
        defaultOptions = hex"0003"; // placeholder options lab
    }

    /// @inheritdoc ITransportAdapter
    function quote(uint64 dstChainId, bytes calldata payload) external view override returns (uint256 fee) {
        bytes32 remoteAdapter = lzPeers[dstChainId];
        if (remoteAdapter == bytes32(0)) revert MessagingErrors.UnsupportedChain();

        MessagingParams memory params = MessagingParams({
            dstEid: uint32(dstChainId),
            receiver: remoteAdapter,
            message: payload,
            options: defaultOptions,
            payInLzToken: false
        });
        MessagingFee memory mf = endpoint.quote(params, address(this));
        return mf.nativeFee;
    }

    /// @inheritdoc ITransportAdapter
    function dispatch(uint64 dstChainId, Packet calldata packet, address refundTo)
        external
        payable
        override
        nonReentrant
        returns (bytes32 receiptId)
    {
        if (msg.sender != address(messenger)) revert MessagingErrors.UnauthorizedCaller();
        if (packet.dstChainId != dstChainId) revert MessagingErrors.InvalidPayload();

        bytes32 remoteAdapter = lzPeers[dstChainId];
        if (remoteAdapter == bytes32(0)) revert MessagingErrors.UnsupportedChain();

        bytes memory message = PacketCodec.encode(packet);
        MessagingParams memory params = MessagingParams({
            dstEid: uint32(dstChainId),
            receiver: remoteAdapter,
            message: message,
            options: defaultOptions,
            payInLzToken: false
        });

        MessagingReceipt memory receipt = endpoint.send{value: msg.value}(params, refundTo);
        return receipt.guid;
    }

    /// @inheritdoc ILayerZeroReceiver
    function lzReceive(
        Origin calldata origin,
        bytes32,
        bytes calldata message,
        address,
        bytes calldata
    ) external payable override nonReentrant {
        if (msg.sender != address(endpoint)) revert MessagingErrors.UnauthorizedCaller();

        bytes32 expectedSender = lzPeers[uint64(origin.srcEid)];
        if (expectedSender == bytes32(0) || expectedSender != origin.sender) {
            revert MessagingErrors.InvalidSourceSender();
        }

        Packet memory packet = PacketCodec.decode(message);
        if (uint64(origin.srcEid) != packet.srcChainId) {
            revert MessagingErrors.InvalidSourceSender();
        }

        ICrossChainMessenger messenger_ = messenger;
        if (address(messenger_) == address(0)) revert MessagingErrors.ZeroAddress();

        // External call: deliverer del messenger debe ser este adapter.
        messenger_.receivePacket(packet);
    }

    /**
     * @notice Configura el messenger local.
     * @param messenger_ Contrato `ICrossChainMessenger`.
     */
    function setMessenger(address messenger_) external onlyOwner {
        PeerLib.requireNonZero(messenger_);
        messenger = ICrossChainMessenger(messenger_);
        emit MessengerUpdated(messenger_);
    }

    /**
     * @notice Configura el adapter remoto (receiver LZ) para un eid.
     * @param eid Endpoint id remoto.
     * @param remoteAdapter Address del adapter remoto en bytes32.
     */
    function setLzPeer(uint64 eid, bytes32 remoteAdapter) external onlyOwner {
        PeerLib.requireConfiguredPeer(remoteAdapter);
        lzPeers[eid] = remoteAdapter;
        emit LzPeerSet(eid, remoteAdapter);
    }

    /**
     * @notice Actualiza options por defecto.
     * @param options_ Bytes de options LZ.
     */
    function setDefaultOptions(bytes calldata options_) external onlyOwner {
        defaultOptions = options_;
        emit DefaultOptionsUpdated(options_);
    }
}
