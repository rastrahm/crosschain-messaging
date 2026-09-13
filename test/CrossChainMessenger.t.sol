// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../src/errors/MessagingErrors.sol";
import {PeerLib} from "../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../src/libraries/PacketCodec.sol";
import {MessagingTestBase} from "./helpers/MessagingTestBase.sol";

/**
 * @title CrossChainMessengerTest
 * @notice Unit tests del nucleo AMP + MockRelayer (Fase 2).
 */
contract CrossChainMessengerTest is MessagingTestBase {
    function test_quoteSend_returnsAdapterFee() public view {
        assertEq(messengerA.quoteSend(CHAIN_B, hex"01"), FEE);
    }

    function test_quoteSend_revertsUnsupportedChain() public {
        vm.expectRevert(MessagingErrors.UnsupportedChain.selector);
        messengerA.quoteSend(99, hex"01");
    }

    function test_send_refundsExcessFee() public {
        uint256 beforeUser = user.balance;
        uint256 beforeTransport = address(transportA).balance;

        vm.prank(user);
        bytes32 hash = messengerA.send{value: 1 ether}(CHAIN_B, hex"dead");

        assertTrue(hash != bytes32(0));
        assertEq(user.balance, beforeUser - FEE);
        assertEq(address(transportA).balance, beforeTransport + FEE);
        assertEq(address(messengerA).balance, 0);
        assertEq(messengerA.outboundNonces(CHAIN_B), 1);
    }

    function test_send_revertsInsufficientFee() public {
        vm.prank(user);
        vm.expectRevert(MessagingErrors.InsufficientFee.selector);
        messengerA.send{value: FEE - 1}(CHAIN_B, hex"01");
    }

    function test_sendAndRelay_deliversToReceiver() public {
        bytes memory payload = abi.encode(user, uint256(5 ether), true);
        (, bytes32 hash) = _sendAndRelay(payload, FEE);

        assertTrue(messengerB.processedMessages(hash));
        assertEq(appB.receiveCount(), 1);
        assertEq(appB.lastSrcChainId(), CHAIN_A);
        assertEq(appB.lastSrcAddress(), PeerLib.addressToBytes32(address(messengerA)));
        assertEq(appB.lastPayload(), payload);
    }

    function test_receivePacket_revertsUnauthorizedCaller() public {
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

    function test_receivePacket_revertsInvalidSourceSender() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(makeAddr("spoof")),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });

        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        relayer.relay(messengerB, packet);
    }

    function test_receivePacket_revertsReplay() public {
        (, bytes32 hash) = _sendAndRelay(hex"aabb", FEE);
        assertTrue(messengerB.processedMessages(hash));

        Packet memory packet = _lastPacketA();
        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        relayer.relay(messengerB, packet);
    }

    function test_receivePacket_revertsWrongDstChain() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: 999,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });

        vm.expectRevert(MessagingErrors.UnsupportedChain.selector);
        relayer.relay(messengerB, packet);
    }

    function test_receivePacket_revertsWrongDstAddress() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(makeAddr("other")),
            nonce: 1,
            payload: hex"01"
        });

        vm.expectRevert(MessagingErrors.InvalidPeer.selector);
        relayer.relay(messengerB, packet);
    }

    function test_messageHash_matchesCodec() public {
        vm.prank(user);
        bytes32 hash = messengerA.send{value: FEE}(CHAIN_B, hex"c0ffee");
        Packet memory packet = _lastPacketA();
        assertEq(hash, PacketCodec.messageHash(packet));
    }

    function test_setPeer_revertsZero() public {
        vm.prank(owner);
        vm.expectRevert(MessagingErrors.InvalidPeer.selector);
        messengerA.setPeer(CHAIN_B, bytes32(0));
    }
}
