// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Packet} from "../libraries/PacketCodec.sol";

/**
 * @title ITransportAdapter
 * @notice Abstraccion de transporte (Mock / LayerZero V2 / CCIP).
 */
interface ITransportAdapter {
    /**
     * @notice Cotiza fee nativo para despachar `payload` a `dstChainId`.
     * @param dstChainId Cadena destino.
     * @param payload Bytes del mensaje (sin header completo si el adapter lo arma).
     * @return fee Fee en wei.
     */
    function quote(uint64 dstChainId, bytes calldata payload) external view returns (uint256 fee);

    /**
     * @notice Despacha el paquete al transporte.
     * @param dstChainId Cadena destino.
     * @param packet Paquete completo.
     * @param refundTo Direccion de refund del transporte (si aplica).
     * @return receiptId Identificador opaco del envio (p. ej. messageHash).
     */
    function dispatch(uint64 dstChainId, Packet calldata packet, address refundTo)
        external
        payable
        returns (bytes32 receiptId);
}
