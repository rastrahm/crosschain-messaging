// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ITransportAdapter} from "../interfaces/ITransportAdapter.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";
import {Packet, PacketCodec} from "../libraries/PacketCodec.sol";

/**
 * @title MockTransportAdapter
 * @notice Transporte local de fee fijo; guarda el ultimo paquete para tests.
 * @dev No entrega on-chain: `MockRelayer` lee `lastPacket` / eventos del messenger.
 */
contract MockTransportAdapter is ITransportAdapter {
    /// @notice Fee fijo en wei por mensaje.
    uint256 public immutable fee;

    /// @notice Ultimo paquete despachado.
    Packet public lastPacket;

    /// @notice Ultimo receipt (messageHash).
    bytes32 public lastReceiptId;

    /// @notice Contador de dispatches.
    uint256 public dispatchCount;

    /**
     * @notice Fija el fee del mock.
     * @param fee_ Fee en wei (`0` permitido para tests sin valor).
     */
    constructor(uint256 fee_) {
        fee = fee_;
    }

    /// @inheritdoc ITransportAdapter
    function quote(uint64, bytes calldata) external view override returns (uint256) {
        return fee;
    }

    /// @inheritdoc ITransportAdapter
    function dispatch(uint64 dstChainId, Packet calldata packet, address)
        external
        payable
        override
        returns (bytes32 receiptId)
    {
        if (packet.dstChainId != dstChainId) revert MessagingErrors.InvalidPayload();
        if (msg.value < fee) revert MessagingErrors.InsufficientFee();

        lastPacket = packet;
        receiptId = PacketCodec.messageHash(packet);
        lastReceiptId = receiptId;
        unchecked {
            ++dispatchCount;
        }
    }

    /**
     * @notice Retira fees acumulados (tests / mop-up).
     * @param to Receptor.
     */
    function withdraw(address to) external {
        if (to == address(0)) revert MessagingErrors.ZeroAddress();
        (bool ok,) = to.call{value: address(this).balance}("");
        if (!ok) revert MessagingErrors.EthRefundFailed();
    }

    receive() external payable {}
}
