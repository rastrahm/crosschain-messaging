// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ITransportAdapter} from "../interfaces/ITransportAdapter.sol";
import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {ICCIPRouter, IAny2EVMMessageReceiver, EVM2AnyMessage, Any2EVMMessage} from "../interfaces/ICCIPRouter.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";
import {Packet, PacketCodec} from "../libraries/PacketCodec.sol";
import {PeerLib} from "../libraries/PeerLib.sol";

/**
 * @title CCIPAdapter
 * @notice Puente `ITransportAdapter` <-> CCIP Router (`getFee` / `ccipSend` / `ccipReceive`).
 * @dev Solo el `messenger` puede `dispatch`. Solo el `router` puede `ccipReceive`.
 *      `ccipPeers[selector]` apunta al adapter remoto (receiver CCIP).
 */
contract CCIPAdapter is ITransportAdapter, IAny2EVMMessageReceiver, Ownable2Step, ReentrancyGuard {
    /// @notice Router CCIP (mock o real).
    ICCIPRouter public immutable router;

    /// @notice Messenger local que usa este adapter.
    ICrossChainMessenger public messenger;

    /// @notice Peer CCIP (adapter remoto) por chain selector.
    mapping(uint64 chainSelector => address remoteAdapter) public ccipPeers;

    /// @notice Extra args por defecto.
    bytes public defaultExtraArgs;

    /// @notice Peer CCIP configurado.
    event CcipPeerSet(uint64 indexed chainSelector, address remoteAdapter);

    /// @notice Messenger actualizado.
    event MessengerUpdated(address indexed messenger);

    /// @notice Extra args actualizados.
    event DefaultExtraArgsUpdated(bytes extraArgs);

    /**
     * @notice Despliega el adapter ligado a un router.
     * @param router_ Router CCIP.
     * @param messenger_ Messenger local (puede ser cero y setearse luego).
     * @param owner_ Owner administrativo.
     */
    constructor(address router_, address messenger_, address owner_) Ownable(owner_) {
        PeerLib.requireNonZero(router_);
        PeerLib.requireNonZero(owner_);
        router = ICCIPRouter(router_);
        if (messenger_ != address(0)) {
            messenger = ICrossChainMessenger(messenger_);
        }
        defaultExtraArgs = hex"97a657c9"; // placeholder lab (tag generico)
    }

    /// @inheritdoc ITransportAdapter
    function quote(uint64 dstChainId, bytes calldata payload) external view override returns (uint256 fee) {
        address remoteAdapter = ccipPeers[dstChainId];
        if (remoteAdapter == address(0)) revert MessagingErrors.UnsupportedChain();

        EVM2AnyMessage memory message = EVM2AnyMessage({
            receiver: abi.encode(remoteAdapter),
            data: payload,
            feeToken: address(0),
            extraArgs: defaultExtraArgs
        });
        return router.getFee(dstChainId, message);
    }

    /// @inheritdoc ITransportAdapter
    function dispatch(uint64 dstChainId, Packet calldata packet, address)
        external
        payable
        override
        nonReentrant
        returns (bytes32 messageId)
    {
        if (msg.sender != address(messenger)) revert MessagingErrors.UnauthorizedCaller();
        if (packet.dstChainId != dstChainId) revert MessagingErrors.InvalidPayload();

        address remoteAdapter = ccipPeers[dstChainId];
        if (remoteAdapter == address(0)) revert MessagingErrors.UnsupportedChain();

        EVM2AnyMessage memory message = EVM2AnyMessage({
            receiver: abi.encode(remoteAdapter),
            data: PacketCodec.encode(packet),
            feeToken: address(0),
            extraArgs: defaultExtraArgs
        });

        messageId = router.ccipSend{value: msg.value}(dstChainId, message);
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(Any2EVMMessage calldata message) external override nonReentrant {
        if (msg.sender != address(router)) revert MessagingErrors.UnauthorizedCaller();

        address remoteSender = abi.decode(message.sender, (address));
        address expected = ccipPeers[message.sourceChainSelector];
        if (expected == address(0) || expected != remoteSender) {
            revert MessagingErrors.InvalidSourceSender();
        }

        Packet memory packet = PacketCodec.decode(message.data);
        if (packet.srcChainId != message.sourceChainSelector) {
            revert MessagingErrors.InvalidSourceSender();
        }

        ICrossChainMessenger messenger_ = messenger;
        if (address(messenger_) == address(0)) revert MessagingErrors.ZeroAddress();

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
     * @notice Configura el adapter remoto para un chain selector.
     * @param chainSelector Selector remoto.
     * @param remoteAdapter Address del adapter remoto.
     */
    function setCcipPeer(uint64 chainSelector, address remoteAdapter) external onlyOwner {
        PeerLib.requireNonZero(remoteAdapter);
        ccipPeers[chainSelector] = remoteAdapter;
        emit CcipPeerSet(chainSelector, remoteAdapter);
    }

    /**
     * @notice Actualiza extra args por defecto.
     * @param extraArgs_ Bytes de extraArgs CCIP.
     */
    function setDefaultExtraArgs(bytes calldata extraArgs_) external onlyOwner {
        defaultExtraArgs = extraArgs_;
        emit DefaultExtraArgsUpdated(extraArgs_);
    }

    receive() external payable {}
}
