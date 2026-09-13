// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../errors/MessagingErrors.sol";

/**
 * @title PeerLib
 * @notice Conversion address <-> bytes32 y validacion de peers trusted.
 * @dev Peers se almacenan left-padded en `bytes32` (estandar LZ / bytes32 path).
 */
library PeerLib {
    /**
     * @notice Empaqueta una address EVM en bytes32 (left-padded).
     * @param addr Direccion a empaquetar.
     * @return peer Representacion bytes32.
     */
    function addressToBytes32(address addr) internal pure returns (bytes32 peer) {
        return bytes32(uint256(uint160(addr)));
    }

    /**
     * @notice Extrae address EVM desde bytes32 left-padded.
     * @param peer Bytes32 peer.
     * @return addr Direccion (20 bytes bajos).
     */
    function bytes32ToAddress(bytes32 peer) internal pure returns (address addr) {
        return address(uint160(uint256(peer)));
    }

    /**
     * @notice Requiere address no cero.
     * @param addr Direccion a validar.
     */
    function requireNonZero(address addr) internal pure {
        if (addr == address(0)) revert MessagingErrors.ZeroAddress();
    }

    /**
     * @notice Requiere peer bytes32 no cero (config / setPeer).
     * @param peer Peer a validar.
     */
    function requireConfiguredPeer(bytes32 peer) internal pure {
        if (peer == bytes32(0)) revert MessagingErrors.InvalidPeer();
    }

    /**
     * @notice Verifica que el remitente remoto coincide con el peer esperado.
     * @param expected Peer configurado en `peers[srcChainId]`.
     * @param actual `srcAddress` del paquete entrante.
     * @dev Si `expected` es cero o no coincide -> `InvalidSourceSender` (anti-spoofing).
     */
    function requirePeer(bytes32 expected, bytes32 actual) internal pure {
        if (expected == bytes32(0) || expected != actual) {
            revert MessagingErrors.InvalidSourceSender();
        }
    }
}
