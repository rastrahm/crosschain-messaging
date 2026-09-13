// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {PeerLibHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title PeerLibTest
 * @notice Unit + fuzz de pack/unpack y validacion de peers.
 */
contract PeerLibTest is Test {
    PeerLibHarness internal harness;

    function setUp() public {
        harness = new PeerLibHarness();
    }

    function test_addressToBytes32_roundtrip() public view {
        address a = address(0xA11CE);
        bytes32 peer = harness.addressToBytes32(a);
        assertEq(harness.bytes32ToAddress(peer), a);
        assertEq(uint256(peer) >> 160, 0);
    }

    function test_requireNonZero_revertsOnZero() public {
        vm.expectRevert(MessagingErrors.ZeroAddress.selector);
        harness.requireNonZero(address(0));
    }

    function test_requireNonZero_ok() public view {
        harness.requireNonZero(address(0x1));
    }

    function test_requireConfiguredPeer_revertsOnZero() public {
        vm.expectRevert(MessagingErrors.InvalidPeer.selector);
        harness.requireConfiguredPeer(bytes32(0));
    }

    function test_requirePeer_revertsOnMismatch() public {
        bytes32 expected = harness.addressToBytes32(address(0xA11CE));
        bytes32 actual = harness.addressToBytes32(address(0xB0B));
        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        harness.requirePeer(expected, actual);
    }

    function test_requirePeer_revertsWhenExpectedZero() public {
        bytes32 actual = harness.addressToBytes32(address(0xA11CE));
        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        harness.requirePeer(bytes32(0), actual);
    }

    function test_requirePeer_ok() public view {
        bytes32 peer = harness.addressToBytes32(address(0xA11CE));
        harness.requirePeer(peer, peer);
    }

    function testFuzz_addressRoundtrip(address addr) public view {
        assertEq(harness.bytes32ToAddress(harness.addressToBytes32(addr)), addr);
    }

    function testFuzz_requirePeer_match(address addr) public view {
        vm.assume(addr != address(0));
        bytes32 peer = harness.addressToBytes32(addr);
        harness.requirePeer(peer, peer);
    }

    function testFuzz_requirePeer_mismatch(address a, address b) public {
        vm.assume(a != b);
        bytes32 expected = harness.addressToBytes32(a);
        bytes32 actual = harness.addressToBytes32(b);
        // Even if expected is zero (a==0), still InvalidSourceSender
        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        harness.requirePeer(expected, actual);
    }
}
