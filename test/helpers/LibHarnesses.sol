// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Packet, PacketCodec} from "../../src/libraries/PacketCodec.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {FeeRefundLib} from "../../src/libraries/FeeRefundLib.sol";

/**
 * @title PacketCodecHarness
 * @notice Expone `PacketCodec` para unit / fuzz tests.
 */
contract PacketCodecHarness {
    function encode(Packet memory packet) external pure returns (bytes memory) {
        return PacketCodec.encode(packet);
    }

    function decode(bytes memory data) external pure returns (Packet memory) {
        return PacketCodec.decode(data);
    }

    function messageHash(Packet memory packet) external pure returns (bytes32) {
        return PacketCodec.messageHash(packet);
    }

    function encodePacked(Packet memory packet) external pure returns (bytes memory) {
        return PacketCodec.encodePacked(packet);
    }

    function decodeYul(bytes memory data) external pure returns (Packet memory) {
        return PacketCodec.decodeYul(data);
    }
}

/**
 * @title PeerLibHarness
 * @notice Expone `PeerLib` para unit tests.
 */
contract PeerLibHarness {
    function addressToBytes32(address addr) external pure returns (bytes32) {
        return PeerLib.addressToBytes32(addr);
    }

    function bytes32ToAddress(bytes32 peer) external pure returns (address) {
        return PeerLib.bytes32ToAddress(peer);
    }

    function requireNonZero(address addr) external pure {
        PeerLib.requireNonZero(addr);
    }

    function requireConfiguredPeer(bytes32 peer) external pure {
        PeerLib.requireConfiguredPeer(peer);
    }

    function requirePeer(bytes32 expected, bytes32 actual) external pure {
        PeerLib.requirePeer(expected, actual);
    }
}

/**
 * @title FeeRefundLibHarness
 * @notice Expone `FeeRefundLib.refundExcess`; debe poder recibir ETH de prueba.
 */
contract FeeRefundLibHarness {
    function refundExcess(address refundTo, uint256 fee) external payable {
        FeeRefundLib.refundExcess(refundTo, fee);
    }

    receive() external payable {}
}
