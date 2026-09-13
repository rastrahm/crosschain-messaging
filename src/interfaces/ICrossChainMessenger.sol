// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Packet} from "../libraries/PacketCodec.sol";

/**
 * @title ICrossChainMessenger
 * @notice Nucleo AMP: quote/send en origen y receive autenticado en destino.
 */
interface ICrossChainMessenger {
    /// @notice Peer trusted por chain id remoto.
    function peers(uint64 chainId) external view returns (bytes32);

    /// @notice True si el `messageHash` ya fue ejecutado.
    function processedMessages(bytes32 messageHash) external view returns (bool);

    /// @notice Chain id local de esta instancia.
    function localChainId() external view returns (uint64);

    /**
     * @notice Cotiza el fee nativo del transporte para un envio.
     * @param dstChainId Cadena destino.
     * @param payload Datos app-specific.
     * @return fee Fee en wei.
     */
    function quoteSend(uint64 dstChainId, bytes calldata payload) external view returns (uint256 fee);

    /**
     * @notice Envia un mensaje cross-chain pagando el fee en `msg.value`.
     * @param dstChainId Cadena destino (debe tener peer).
     * @param payload Datos app-specific.
     * @return messageHash Hash idempotente del paquete.
     */
    function send(uint64 dstChainId, bytes calldata payload) external payable returns (bytes32 messageHash);

    /**
     * @notice Recibe y ejecuta un paquete (solo deliverer autorizado).
     * @param packet Paquete firmado/entregado por el transporte.
     */
    function receivePacket(Packet calldata packet) external;
}
