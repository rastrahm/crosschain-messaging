// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {RemoteStakeReceiver} from "../../src/apps/RemoteStakeReceiver.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../../src/libraries/PacketCodec.sol";
import {MessagingTestBase} from "../helpers/MessagingTestBase.sol";

/**
 * @title RemoteStakeReceiverTest
 * @notice Demo e2e stake/unstake remoto via messenger (Fase 5).
 */
contract RemoteStakeReceiverTest is MessagingTestBase {
    RemoteStakeReceiver internal stakeApp;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        stakeApp = new RemoteStakeReceiver(address(messengerB), owner);
        messengerB.setReceiver(address(stakeApp));
        vm.stopPrank();
    }

    function test_remoteStake_appliesOnce() public {
        bytes memory payload = abi.encode(user, uint256(5 ether), true);
        (, bytes32 hash) = _sendAndRelay(payload, FEE);

        assertTrue(messengerB.processedMessages(hash));
        assertEq(stakeApp.staked(user), 5 ether);
    }

    function test_remoteUnstake_reducesBalance() public {
        _sendAndRelay(abi.encode(user, uint256(5 ether), true), FEE);
        _sendAndRelay(abi.encode(user, uint256(2 ether), false), FEE);

        assertEq(stakeApp.staked(user), 3 ether);
    }

    function test_remoteUnstake_revertsIfInsufficient() public {
        _sendAndRelay(abi.encode(user, uint256(1 ether), true), FEE);

        bytes memory payload = abi.encode(user, uint256(2 ether), false);
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, payload);

        Packet memory packet = _lastPacketA();
        vm.expectRevert(MessagingErrors.InvalidPayload.selector);
        relayer.relay(messengerB, packet);

        assertEq(stakeApp.staked(user), 1 ether);
        // Mensaje no queda processed si el receiver revierte (tx completa revierte)
        assertFalse(messengerB.processedMessages(PacketCodec.messageHash(packet)));
    }

    function test_remoteStake_revertsZeroAmount() public {
        bytes memory payload = abi.encode(user, uint256(0), true);
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, payload);

        Packet memory packet = _lastPacketA();
        vm.expectRevert(MessagingErrors.ZeroAmount.selector);
        relayer.relay(messengerB, packet);
    }

    function test_remoteStake_revertsZeroUser() public {
        bytes memory payload = abi.encode(address(0), uint256(1 ether), true);
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, payload);

        Packet memory packet = _lastPacketA();
        vm.expectRevert(MessagingErrors.ZeroAddress.selector);
        relayer.relay(messengerB, packet);
    }

    function test_onMessageReceived_revertsIfNotMessenger() public {
        bytes memory payload = abi.encode(user, uint256(1 ether), true);
        vm.prank(user);
        vm.expectRevert(MessagingErrors.UnauthorizedCaller.selector);
        stakeApp.onMessageReceived(CHAIN_A, PeerLib.addressToBytes32(address(messengerA)), payload);
    }

    function test_replayDoesNotDoubleStake() public {
        bytes memory payload = abi.encode(user, uint256(5 ether), true);
        (Packet memory packet, bytes32 hash) = _sendAndRelay(payload, FEE);
        assertEq(stakeApp.staked(user), 5 ether);

        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        relayer.relay(messengerB, packet);

        assertTrue(messengerB.processedMessages(hash));
        assertEq(stakeApp.staked(user), 5 ether);
    }
}
