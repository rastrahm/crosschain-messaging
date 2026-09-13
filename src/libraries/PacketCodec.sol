// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../errors/MessagingErrors.sol";

/**
 * @title Packet
 * @notice Paquete AMP cross-chain (header fijo + payload app-specific).
 */
struct Packet {
    uint64 srcChainId;
    uint64 dstChainId;
    bytes32 srcAddress;
    bytes32 dstAddress;
    uint64 nonce;
    bytes payload;
}

/**
 * @title PacketCodec
 * @notice Encode/decode ABI, hash idempotente y decode packed en Yul.
 * @dev Canonical wire format: `abi.encode` de los campos del `Packet`.
 *      Packed (gas / Fase 7): header 120 B + payload
 *      [0:8) srcChainId | [8:16) dstChainId | [16:48) srcAddress | [48:80) dstAddress
 *      | [80:88) nonce | [88:120) payloadLen | [120:) payload
 *      Tradeoff: ABI es portable; Yul packed evita overhead de decode dinamico en hot path.
 */
library PacketCodec {
    uint256 internal constant PACKED_HEADER_SIZE = 120;

    /**
     * @notice Serializa un `Packet` con `abi.encode` (formato canonical).
     * @param packet Paquete a serializar.
     * @return data Bytes ABI-encoded.
     */
    function encode(Packet memory packet) internal pure returns (bytes memory data) {
        return abi.encode(
            packet.srcChainId,
            packet.dstChainId,
            packet.srcAddress,
            packet.dstAddress,
            packet.nonce,
            packet.payload
        );
    }

    /**
     * @notice Deserializa bytes ABI-encoded a `Packet`.
     * @param data Bytes producidos por `encode`.
     * @return packet Paquete decodificado.
     */
    function decode(bytes memory data) internal pure returns (Packet memory packet) {
        if (data.length == 0) revert MessagingErrors.InvalidPayload();
        (
            uint64 srcChainId,
            uint64 dstChainId,
            bytes32 srcAddress,
            bytes32 dstAddress,
            uint64 nonce,
            bytes memory payload
        ) = abi.decode(data, (uint64, uint64, bytes32, bytes32, uint64, bytes));

        packet = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
    }

    /**
     * @notice Hash idempotente del mensaje (payload hasheado por separado).
     * @param packet Paquete a hashear.
     * @return hash Identificador unico para `processedMessages`.
     */
    function messageHash(Packet memory packet) internal pure returns (bytes32 hash) {
        return keccak256(
            abi.encode(
                packet.srcChainId,
                packet.dstChainId,
                packet.srcAddress,
                packet.dstAddress,
                packet.nonce,
                keccak256(packet.payload)
            )
        );
    }

    /**
     * @notice Empaqueta header+payload en layout fijo (perfil gas / `decodeYul`).
     * @param packet Paquete a serializar.
     * @return data Bytes packed (120 + payload.length).
     */
    function encodePacked(Packet memory packet) internal pure returns (bytes memory data) {
        bytes memory payload = packet.payload;
        data = bytes.concat(
            bytes8(packet.srcChainId),
            bytes8(packet.dstChainId),
            packet.srcAddress,
            packet.dstAddress,
            bytes8(packet.nonce),
            bytes32(payload.length),
            payload
        );
    }

    /**
     * @notice Decodifica layout packed con Yul (hot path / gas profiling).
     * @param data Bytes de `encodePacked`.
     * @return packet Paquete decodificado.
     */
    function decodeYul(bytes memory data) internal pure returns (Packet memory packet) {
        if (data.length < PACKED_HEADER_SIZE) revert MessagingErrors.InvalidPayload();

        uint64 srcChainId;
        uint64 dstChainId;
        bytes32 srcAddress;
        bytes32 dstAddress;
        uint64 nonce;
        uint256 payloadLen;

        assembly ("memory-safe") {
            let p := add(data, 0x20)
            srcChainId := shr(192, mload(p))
            dstChainId := shr(192, mload(add(p, 8)))
            srcAddress := mload(add(p, 16))
            dstAddress := mload(add(p, 48))
            nonce := shr(192, mload(add(p, 80)))
            payloadLen := mload(add(p, 88))
        }

        if (data.length != PACKED_HEADER_SIZE + payloadLen) revert MessagingErrors.InvalidPayload();

        bytes memory payload = new bytes(payloadLen);
        if (payloadLen > 0) {
            assembly ("memory-safe") {
                mcopy(add(payload, 0x20), add(add(data, 0x20), PACKED_HEADER_SIZE), payloadLen)
            }
        }

        packet = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
    }
}
