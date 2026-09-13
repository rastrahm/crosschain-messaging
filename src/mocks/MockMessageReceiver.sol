// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IMessageReceiver} from "../interfaces/IMessageReceiver.sol";

/**
 * @title MockMessageReceiver
 * @notice Registra el ultimo mensaje autenticado (tests Fase 2).
 */
contract MockMessageReceiver is IMessageReceiver {
    uint64 public lastSrcChainId;
    bytes32 public lastSrcAddress;
    bytes public lastPayload;
    uint256 public receiveCount;

    /// @inheritdoc IMessageReceiver
    function onMessageReceived(uint64 srcChainId, bytes32 srcAddress, bytes calldata payload) external override {
        lastSrcChainId = srcChainId;
        lastSrcAddress = srcAddress;
        lastPayload = payload;
        unchecked {
            ++receiveCount;
        }
    }
}
