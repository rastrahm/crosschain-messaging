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
 * @notice Encode/decode ABI, hash idempotente y wire packed en Yul (hot path).
 * @dev Canonical ABI: portable / debug.
 *      Packed (adapters LZ/CCIP v1): header 120 B + payload
 *      [0:8) srcChainId | [8:16) dstChainId | [16:48) srcAddress | [48:80) dstAddress
 *      | [80:88) nonce | [88:120) payloadLen | [120:) payload
 *      Tradeoff: ABI mas claro; Yul packed menos gas en decode del receive path.
 */
library PacketCodec {
    uint256 internal constant PACKED_HEADER_SIZE = 120;

    /**
     * @notice Serializa un `Packet` con `abi.encode` (formato portable).
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
     * @notice Hash idempotente (memory). Preferir `messageHashCalldata` en receive.
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
     * @notice Hash desde calldata (evita copiar el struct a memory).
     * @param packet Paquete en calldata.
     * @return hash Identificador unico.
     * @dev Hot path de `receivePacket`.
     */
    function messageHashCalldata(Packet calldata packet) internal pure returns (bytes32 hash) {
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
     * @notice Empaqueta header+payload en layout fijo (wire adapters / `decodeYul`).
     * @param packet Paquete a serializar.
     * @return data Bytes packed (120 + payload.length).
     */
    function encodePacked(Packet memory packet) internal pure returns (bytes memory data) {
        bytes memory payload = packet.payload;
        uint256 payloadLen = payload.length;
        data = new bytes(PACKED_HEADER_SIZE + payloadLen);

        uint64 srcChainId = packet.srcChainId;
        uint64 dstChainId = packet.dstChainId;
        bytes32 srcAddress = packet.srcAddress;
        bytes32 dstAddress = packet.dstAddress;
        uint64 nonce = packet.nonce;

        assembly ("memory-safe") {
            let dest := add(data, 0x20)
            mstore(dest, shl(192, srcChainId))
            mstore(add(dest, 8), shl(192, dstChainId))
            mstore(add(dest, 16), srcAddress)
            mstore(add(dest, 48), dstAddress)
            mstore(add(dest, 80), shl(192, nonce))
            mstore(add(dest, 88), payloadLen)
            if payloadLen {
                mcopy(add(dest, PACKED_HEADER_SIZE), add(payload, 0x20), payloadLen)
            }
        }
    }

    /**
     * @notice Decodifica layout packed con Yul (hot path adapters).
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
