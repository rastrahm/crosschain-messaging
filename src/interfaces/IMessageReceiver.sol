// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title IMessageReceiver
 * @notice Hook de aplicacion invocado tras autenticar un mensaje.
 * @dev Solo debe ser llamado por el `CrossChainMessenger` de confianza.
 */
interface IMessageReceiver {
    /**
     * @notice Callback post-autenticacion.
     * @param srcChainId Cadena origen del paquete.
     * @param srcAddress Peer origen (bytes32).
     * @param payload Datos app-specific ya validados a nivel transporte.
     */
    function onMessageReceived(uint64 srcChainId, bytes32 srcAddress, bytes calldata payload) external;
}
