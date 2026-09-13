// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ICCIPRouter, IAny2EVMMessageReceiver, EVM2AnyMessage, Any2EVMMessage} from "../interfaces/ICCIPRouter.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";

/**
 * @title MockCCIPRouter
 * @notice Router CCIP de laboratorio: fee fijo + cola entregable a adapters.
 * @dev Router compartido; cada OApp registra su `chainSelector` con `registerOApp`.
 */
contract MockCCIPRouter is ICCIPRouter {
    /// @notice Fee nativo fijo por mensaje.
    uint256 public immutable nativeFee;

    /// @notice Selector registrado por OApp (adapter).
    mapping(address oapp => uint64 selector) public selectorOf;

    /// @notice Nonce outbound por (sender, dstSelector).
    mapping(address sender => mapping(uint64 dst => uint64 nonce)) public outboundNonce;

    struct Pending {
        uint64 sourceChainSelector;
        address sender;
        uint64 destinationChainSelector;
        address receiver;
        bytes32 messageId;
        bytes data;
        bool delivered;
    }

    /// @notice Cola de mensajes pendientes.
    Pending[] public pending;

    /**
     * @notice Crea el mock router.
     * @param nativeFee_ Fee en wei.
     */
    constructor(uint256 nativeFee_) {
        nativeFee = nativeFee_;
    }

    /**
     * @notice Registra el chain selector del OApp llamante.
     * @param chainSelector Selector local del adapter.
     */
    function registerOApp(uint64 chainSelector) external {
        if (chainSelector == 0) revert MessagingErrors.UnsupportedChain();
        selectorOf[msg.sender] = chainSelector;
    }

    /// @inheritdoc ICCIPRouter
    function getFee(uint64, EVM2AnyMessage memory) external view override returns (uint256 fee) {
        return nativeFee;
    }

    /// @inheritdoc ICCIPRouter
    function ccipSend(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external
        payable
        override
        returns (bytes32 messageId)
    {
        uint64 srcSelector = selectorOf[msg.sender];
        if (srcSelector == 0) revert MessagingErrors.UnauthorizedCaller();
        if (message.receiver.length != 32 && message.receiver.length != 20) {
            // CCIP usually abi.encode(address) => 32 bytes
            if (message.receiver.length == 0) revert MessagingErrors.InvalidPeer();
        }
        if (msg.value < nativeFee) revert MessagingErrors.InsufficientFee();
        if (message.feeToken != address(0)) revert MessagingErrors.InvalidPayload();

        address receiver = _decodeReceiver(message.receiver);
        if (receiver == address(0)) revert MessagingErrors.InvalidPeer();

        uint64 nonce;
        unchecked {
            nonce = ++outboundNonce[msg.sender][destinationChainSelector];
        }

        messageId = keccak256(
            abi.encode(srcSelector, msg.sender, destinationChainSelector, nonce, keccak256(message.data))
        );

        pending.push(
            Pending({
                sourceChainSelector: srcSelector,
                sender: msg.sender,
                destinationChainSelector: destinationChainSelector,
                receiver: receiver,
                messageId: messageId,
                data: message.data,
                delivered: false
            })
        );

        uint256 excess;
        unchecked {
            excess = msg.value - nativeFee;
        }
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            if (!ok) revert MessagingErrors.EthRefundFailed();
        }
    }

    /**
     * @notice Cantidad de mensajes en cola.
     * @return count Longitud de `pending`.
     */
    function pendingLength() external view returns (uint256 count) {
        return pending.length;
    }

    /**
     * @notice Entrega el mensaje en `index` al adapter destino.
     * @param index Indice en `pending`.
     */
    function deliver(uint256 index) external {
        if (index >= pending.length) revert MessagingErrors.InvalidPayload();
        Pending storage p = pending[index];
        if (p.delivered) revert MessagingErrors.MessageAlreadyProcessed();
        p.delivered = true;

        IAny2EVMMessageReceiver(p.receiver).ccipReceive(
            Any2EVMMessage({
                messageId: p.messageId,
                sourceChainSelector: p.sourceChainSelector,
                sender: abi.encode(p.sender),
                data: p.data
            })
        );
    }

    /**
     * @notice Entrega el ultimo mensaje encolado.
     */
    function deliverLast() external {
        if (pending.length == 0) revert MessagingErrors.InvalidPayload();
        this.deliver(pending.length - 1);
    }

    function _decodeReceiver(bytes memory receiver) private pure returns (address addr) {
        if (receiver.length == 32) {
            addr = abi.decode(receiver, (address));
        } else if (receiver.length == 20) {
            assembly ("memory-safe") {
                addr := shr(96, mload(add(receiver, 0x20)))
            }
        } else {
            revert MessagingErrors.InvalidPeer();
        }
    }

    receive() external payable {}
}
