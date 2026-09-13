// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {Packet} from "../../src/libraries/PacketCodec.sol";
import {PacketCodecHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title PacketCodecTest
 * @notice Unit + fuzz de encode/decode ABI, hash y decodeYul packed.
 */
contract PacketCodecTest is Test {
    PacketCodecHarness internal harness;

    function setUp() public {
        harness = new PacketCodecHarness();
    }

    function _sample() internal pure returns (Packet memory) {
        return Packet({
            srcChainId: 1,
            dstChainId: 42161,
            srcAddress: bytes32(uint256(uint160(address(0xA11CE)))),
            dstAddress: bytes32(uint256(uint160(address(0xB0B)))),
            nonce: 7,
            payload: abi.encode(address(0xBEEF), uint256(1 ether), true)
        });
    }

    function test_encodeDecode_roundtrip() public view {
        Packet memory p = _sample();
        Packet memory decoded = harness.decode(harness.encode(p));
        assertEq(decoded.srcChainId, p.srcChainId);
        assertEq(decoded.dstChainId, p.dstChainId);
        assertEq(decoded.srcAddress, p.srcAddress);
        assertEq(decoded.dstAddress, p.dstAddress);
        assertEq(decoded.nonce, p.nonce);
        assertEq(decoded.payload, p.payload);
    }

    function test_messageHash_stableAndDistinct() public view {
        Packet memory p = _sample();
        bytes32 h1 = harness.messageHash(p);
        bytes32 h2 = harness.messageHash(p);
        assertEq(h1, h2);

        p.nonce = 8;
        assertTrue(harness.messageHash(p) != h1);
    }

    function test_messageHash_payloadContentMatters() public view {
        Packet memory p = _sample();
        bytes32 h1 = harness.messageHash(p);
        p.payload = abi.encode("other");
        assertTrue(harness.messageHash(p) != h1);
    }

    function test_decode_revertsOnEmpty() public {
        vm.expectRevert(MessagingErrors.InvalidPayload.selector);
        harness.decode("");
    }

    function test_encodePacked_decodeYul_roundtrip() public view {
        Packet memory p = _sample();
        bytes memory packed = harness.encodePacked(p);
        assertEq(packed.length, 120 + p.payload.length);

        Packet memory decoded = harness.decodeYul(packed);
        assertEq(decoded.srcChainId, p.srcChainId);
        assertEq(decoded.dstChainId, p.dstChainId);
        assertEq(decoded.srcAddress, p.srcAddress);
        assertEq(decoded.dstAddress, p.dstAddress);
        assertEq(decoded.nonce, p.nonce);
        assertEq(decoded.payload, p.payload);
    }

    function test_decodeYul_revertsOnShortHeader() public {
        vm.expectRevert(MessagingErrors.InvalidPayload.selector);
        harness.decodeYul(hex"deadbeef");
    }

    function test_decodeYul_revertsOnBadPayloadLen() public {
        Packet memory p = _sample();
        bytes memory packed = harness.encodePacked(p);
        // Truncate one byte from payload region
        bytes memory bad = new bytes(packed.length - 1);
        for (uint256 i; i < bad.length; ++i) {
            bad[i] = packed[i];
        }
        vm.expectRevert(MessagingErrors.InvalidPayload.selector);
        harness.decodeYul(bad);
    }

    function testFuzz_abiRoundtrip(
        uint64 srcChainId,
        uint64 dstChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes memory payload
    ) public view {
        Packet memory p = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
        Packet memory decoded = harness.decode(harness.encode(p));
        assertEq(decoded.srcChainId, srcChainId);
        assertEq(decoded.dstChainId, dstChainId);
        assertEq(decoded.srcAddress, srcAddress);
        assertEq(decoded.dstAddress, dstAddress);
        assertEq(decoded.nonce, nonce);
        assertEq(decoded.payload, payload);
    }

    function testFuzz_packedYulRoundtrip(
        uint64 srcChainId,
        uint64 dstChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes memory payload
    ) public view {
        // Bound payload size to keep fuzz gas reasonable
        if (payload.length > 512) {
            assembly ("memory-safe") {
                mstore(payload, 512)
            }
        }
        Packet memory p = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
        Packet memory decoded = harness.decodeYul(harness.encodePacked(p));
        assertEq(decoded.srcChainId, srcChainId);
        assertEq(decoded.dstChainId, dstChainId);
        assertEq(decoded.srcAddress, srcAddress);
        assertEq(decoded.dstAddress, dstAddress);
        assertEq(decoded.nonce, nonce);
        assertEq(decoded.payload, payload);
    }

    function testFuzz_messageHash_deterministic(
        uint64 srcChainId,
        uint64 dstChainId,
        bytes32 srcAddress,
        bytes32 dstAddress,
        uint64 nonce,
        bytes memory payload
    ) public view {
        Packet memory p = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
        assertEq(harness.messageHash(p), harness.messageHash(p));
    }
}
