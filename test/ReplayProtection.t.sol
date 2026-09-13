// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../src/errors/MessagingErrors.sol";
import {PeerLib} from "../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../src/libraries/PacketCodec.sol";
import {MessagingTestBase} from "./helpers/MessagingTestBase.sol";

/**
 * @title ReplayProtectionTest
 * @notice Anti-replay por `processedMessages` / messageHash (Fase 5).
 */
contract ReplayProtectionTest is MessagingTestBase {
    function test_samePacketTwice_revertsMessageAlreadyProcessed() public {
        bytes memory payload = abi.encode(user, uint256(1 ether), true);
        (Packet memory packet, bytes32 hash) = _sendAndRelay(payload, FEE);

        assertTrue(messengerB.processedMessages(hash));
        assertEq(hash, PacketCodec.messageHash(packet));

        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        relayer.relay(messengerB, packet);
    }

    function test_sameHashDifferentDeliveries_stillReverts() public {
        bytes memory payload = hex"c0ffee";
        (, bytes32 hash) = _sendAndRelay(payload, FEE);

        Packet memory clone = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: payload
        });
        assertEq(PacketCodec.messageHash(clone), hash);

        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        relayer.relay(messengerB, clone);
    }

    function test_differentNonce_allowsSecondMessage() public {
        _sendAndRelay(hex"01", FEE);
        (Packet memory packet2, bytes32 hash2) = _sendAndRelay(hex"02", FEE);

        assertEq(packet2.nonce, 2);
        assertTrue(messengerB.processedMessages(hash2));
        assertEq(appB.receiveCount(), 2);
    }

    function test_processedFlagSetBeforeReceiverEffects() public {
        // Tras un receive exitoso el flag queda true aunque re-enviemos el mismo hash.
        (, bytes32 hash) = _sendAndRelay(hex"aa", FEE);
        assertTrue(messengerB.processedMessages(hash));

        Packet memory packet = _lastPacketA();
        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        relayer.relay(messengerB, packet);
        // Receiver no se invoca de nuevo
        assertEq(appB.receiveCount(), 1);
    }
}
