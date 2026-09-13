// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../src/errors/MessagingErrors.sol";
import {PeerLib} from "../src/libraries/PeerLib.sol";
import {Packet} from "../src/libraries/PacketCodec.sol";
import {MessagingTestBase} from "./helpers/MessagingTestBase.sol";

/**
 * @title UnauthorizedSenderTest
 * @notice Matriz de spoofing / callers no autorizados (Fase 5).
 */
contract UnauthorizedSenderTest is MessagingTestBase {
    function test_receive_revertsWhenSrcAddressNotPeer() public {
        bytes memory payload = abi.encode(user, uint256(1 ether), true);
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(makeAddr("spoofMessenger")),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: payload
        });

        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        relayer.relay(messengerB, packet);
    }

    function test_receive_revertsWhenSrcChainHasNoPeer() public {
        Packet memory packet = Packet({
            srcChainId: 99,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });

        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        relayer.relay(messengerB, packet);
    }

    function test_receive_revertsWhenCallerNotDeliverer() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });

        vm.prank(user);
        vm.expectRevert(MessagingErrors.UnauthorizedCaller.selector);
        messengerB.receivePacket(packet);
    }

    function test_validPayloadStillRejectedIfSpoofedSource() public {
        // Payload bien formado no basta: el peer debe coincidir.
        bytes memory payload = abi.encode(user, uint256(10 ether), true);
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(this)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 42,
            payload: payload
        });

        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        relayer.relay(messengerB, packet);
        assertEq(appB.receiveCount(), 0);
    }
}
