// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {CrossChainMessenger} from "../../src/CrossChainMessenger.sol";
import {CCIPAdapter} from "../../src/adapters/CCIPAdapter.sol";
import {MockCCIPRouter} from "../../src/mocks/MockCCIPRouter.sol";
import {MockMessageReceiver} from "../../src/mocks/MockMessageReceiver.sol";
import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../../src/libraries/PacketCodec.sol";
import {Any2EVMMessage} from "../../src/interfaces/ICCIPRouter.sol";

/**
 * @title CCIPAdapterTest
 * @notice Unit + integracion del adapter CCIP con messenger (Fase 4).
 */
contract CCIPAdapterTest is Test {
    uint64 internal constant CHAIN_A = 1;
    uint64 internal constant CHAIN_B = 2;
    uint256 internal constant FEE = 0.01 ether;

    MockCCIPRouter internal router;
    CrossChainMessenger internal messengerA;
    CrossChainMessenger internal messengerB;
    CCIPAdapter internal adapterA;
    CCIPAdapter internal adapterB;
    MockMessageReceiver internal appB;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        vm.deal(user, 100 ether);

        router = new MockCCIPRouter(FEE);
        appB = new MockMessageReceiver();

        vm.startPrank(owner);
        messengerA = new CrossChainMessenger(CHAIN_A, owner);
        messengerB = new CrossChainMessenger(CHAIN_B, owner);

        adapterA = new CCIPAdapter(address(router), address(messengerA), owner);
        adapterB = new CCIPAdapter(address(router), address(messengerB), owner);
        vm.stopPrank();

        vm.prank(address(adapterA));
        router.registerOApp(CHAIN_A);
        vm.prank(address(adapterB));
        router.registerOApp(CHAIN_B);

        vm.startPrank(owner);
        adapterA.setCcipPeer(CHAIN_B, address(adapterB));
        adapterB.setCcipPeer(CHAIN_A, address(adapterA));

        messengerA.setAdapter(address(adapterA));
        messengerB.setAdapter(address(adapterB));
        messengerA.setDeliverer(address(adapterA));
        messengerB.setDeliverer(address(adapterB));

        messengerA.setPeer(CHAIN_B, PeerLib.addressToBytes32(address(messengerB)));
        messengerB.setPeer(CHAIN_A, PeerLib.addressToBytes32(address(messengerA)));

        messengerB.setReceiver(address(appB));
        vm.stopPrank();
    }

    function test_quote_returnsRouterFee() public view {
        assertEq(adapterA.quote(CHAIN_B, hex"01"), FEE);
        assertEq(messengerA.quoteSend(CHAIN_B, hex"01"), FEE);
    }

    function test_quote_revertsWithoutCcipPeer() public {
        vm.expectRevert(MessagingErrors.UnsupportedChain.selector);
        adapterA.quote(99, hex"01");
    }

    function test_dispatch_revertsIfNotMessenger() public {
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
        adapterA.dispatch{value: FEE}(CHAIN_B, packet, user);
    }

    function test_ccipReceive_revertsIfNotRouter() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });
        Any2EVMMessage memory message = Any2EVMMessage({
            messageId: bytes32(uint256(1)),
            sourceChainSelector: CHAIN_A,
            sender: abi.encode(address(adapterA)),
            data: PacketCodec.encode(packet)
        });

        vm.prank(user);
        vm.expectRevert(MessagingErrors.UnauthorizedCaller.selector);
        adapterB.ccipReceive(message);
    }

    function test_sendAndDeliver_e2e() public {
        bytes memory payload = abi.encode(user, uint256(4 ether), true);

        uint256 beforeUser = user.balance;
        vm.prank(user);
        bytes32 messageHash = messengerA.send{value: 1 ether}(CHAIN_B, payload);

        assertEq(user.balance, beforeUser - FEE);
        assertEq(router.pendingLength(), 1);

        router.deliverLast();

        assertTrue(messengerB.processedMessages(messageHash));
        assertEq(appB.receiveCount(), 1);
        assertEq(appB.lastPayload(), payload);
        assertEq(appB.lastSrcChainId(), CHAIN_A);
    }

    function test_ccipReceive_revertsInvalidCcipPeer() public {
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, hex"aa");

        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"aa"
        });
        Any2EVMMessage memory message = Any2EVMMessage({
            messageId: bytes32(uint256(1)),
            sourceChainSelector: CHAIN_A,
            sender: abi.encode(makeAddr("evilAdapter")),
            data: PacketCodec.encode(packet)
        });

        vm.prank(address(router));
        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        adapterB.ccipReceive(message);
    }

    function test_replayViaRouter_reverts() public {
        vm.prank(user);
        bytes32 hash = messengerA.send{value: FEE}(CHAIN_B, hex"bb");
        router.deliver(0);
        assertTrue(messengerB.processedMessages(hash));

        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        router.deliver(0);
    }

    function test_secondDeliverSamePacket_revertsAtMessenger() public {
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, hex"cc");
        router.deliverLast();

        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"cc"
        });
        Any2EVMMessage memory message = Any2EVMMessage({
            messageId: bytes32(uint256(2)),
            sourceChainSelector: CHAIN_A,
            sender: abi.encode(address(adapterA)),
            data: PacketCodec.encode(packet)
        });

        vm.prank(address(router));
        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        adapterB.ccipReceive(message);
    }
}
