// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ICrossChainMessenger} from "../interfaces/ICrossChainMessenger.sol";
import {Packet} from "../libraries/PacketCodec.sol";

/**
 * @title MockRelayer
 * @notice Entrega in-process de un `Packet` al messenger destino.
 * @dev En tests, el owner configura `dst.setDeliverer(address(relayer))`.
 */
contract MockRelayer {
    /**
     * @notice Llama `receivePacket` en el messenger destino.
     * @param dst Messenger en la cadena destino (misma EVM en unit tests).
     * @param packet Paquete a entregar.
     */
    function relay(ICrossChainMessenger dst, Packet calldata packet) external {
        dst.receivePacket(packet);
    }
}
