// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {CrossChainMessenger} from "../../src/CrossChainMessenger.sol";
import {LayerZeroV2Adapter} from "../../src/adapters/LayerZeroV2Adapter.sol";
import {MockLayerZeroEndpoint} from "../../src/mocks/MockLayerZeroEndpoint.sol";
import {MockMessageReceiver} from "../../src/mocks/MockMessageReceiver.sol";
import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../../src/libraries/PacketCodec.sol";
import {Origin} from "../../src/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title LayerZeroV2AdapterTest
 * @notice Unit + integracion del adapter LZ V2 con messenger (Fase 3).
 */
contract LayerZeroV2AdapterTest is Test {
    uint64 internal constant CHAIN_A = 1;
    uint64 internal constant CHAIN_B = 2;
    uint256 internal constant FEE = 0.01 ether;

    MockLayerZeroEndpoint internal endpoint;
    CrossChainMessenger internal messengerA;
    CrossChainMessenger internal messengerB;
    LayerZeroV2Adapter internal adapterA;
    LayerZeroV2Adapter internal adapterB;
    MockMessageReceiver internal appB;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public {
        vm.deal(user, 100 ether);

        endpoint = new MockLayerZeroEndpoint(FEE);
        appB = new MockMessageReceiver();

        vm.startPrank(owner);
        messengerA = new CrossChainMessenger(CHAIN_A, owner);
        messengerB = new CrossChainMessenger(CHAIN_B, owner);

        adapterA = new LayerZeroV2Adapter(address(endpoint), address(messengerA), owner);
        adapterB = new LayerZeroV2Adapter(address(endpoint), address(messengerB), owner);

        // Registrar eids en el endpoint compartido (llamando como cada adapter).
        vm.stopPrank();
        vm.prank(address(adapterA));
        endpoint.registerOApp(uint32(CHAIN_A));
        vm.prank(address(adapterB));
        endpoint.registerOApp(uint32(CHAIN_B));

        vm.startPrank(owner);
        adapterA.setLzPeer(CHAIN_B, PeerLib.addressToBytes32(address(adapterB)));
        adapterB.setLzPeer(CHAIN_A, PeerLib.addressToBytes32(address(adapterA)));

        messengerA.setAdapter(address(adapterA));
        messengerB.setAdapter(address(adapterB));
        messengerA.setDeliverer(address(adapterA));
        messengerB.setDeliverer(address(adapterB));

        messengerA.setPeer(CHAIN_B, PeerLib.addressToBytes32(address(messengerB)));
        messengerB.setPeer(CHAIN_A, PeerLib.addressToBytes32(address(messengerA)));

        messengerB.setReceiver(address(appB));
        vm.stopPrank();
    }

    function test_quote_returnsEndpointFee() public view {
        assertEq(adapterA.quote(CHAIN_B, hex"01"), FEE);
        assertEq(messengerA.quoteSend(CHAIN_B, hex"01"), FEE);
    }

    function test_quote_revertsWithoutLzPeer() public {
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

    function test_lzReceive_revertsIfNotEndpoint() public {
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"01"
        });
        bytes memory message = PacketCodec.encode(packet);
        Origin memory origin = Origin({
            srcEid: uint32(CHAIN_A),
            sender: PeerLib.addressToBytes32(address(adapterA)),
            nonce: 1
        });

        vm.prank(user);
        vm.expectRevert(MessagingErrors.UnauthorizedCaller.selector);
        adapterB.lzReceive(origin, bytes32(0), message, address(0), "");
    }

    function test_sendAndDeliver_e2e() public {
        bytes memory payload = abi.encode(user, uint256(3 ether), true);

        uint256 beforeUser = user.balance;
        vm.prank(user);
        bytes32 messageHash = messengerA.send{value: 1 ether}(CHAIN_B, payload);

        assertEq(user.balance, beforeUser - FEE);
        assertEq(endpoint.pendingLength(), 1);

        endpoint.deliverLast();

        assertTrue(messengerB.processedMessages(messageHash));
        assertEq(appB.receiveCount(), 1);
        assertEq(appB.lastPayload(), payload);
        assertEq(appB.lastSrcChainId(), CHAIN_A);
    }

    function test_deliver_revertsInvalidLzPeerSender() public {
        // Encolar mensaje legitimo
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, hex"aa");

        // Spoof: llamar lzReceive como endpoint pero con sender LZ incorrecto
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"aa"
        });
        Origin memory origin = Origin({
            srcEid: uint32(CHAIN_A),
            sender: PeerLib.addressToBytes32(makeAddr("evilAdapter")),
            nonce: 1
        });

        vm.prank(address(endpoint));
        vm.expectRevert(MessagingErrors.InvalidSourceSender.selector);
        adapterB.lzReceive(origin, bytes32(uint256(1)), PacketCodec.encode(packet), address(0), "");
    }

    function test_replayViaEndpoint_reverts() public {
        vm.prank(user);
        bytes32 hash = messengerA.send{value: FEE}(CHAIN_B, hex"bb");
        endpoint.deliver(0);
        assertTrue(messengerB.processedMessages(hash));

        // Re-deliver same pending index already marked delivered at endpoint
        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        endpoint.deliver(0);
    }

    function test_secondSend_replaySamePacket_revertsAtMessenger() public {
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, hex"cc");
        endpoint.deliverLast();

        // Craft identical packet (same nonce/path) and push via endpoint path
        Packet memory packet = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: PeerLib.addressToBytes32(address(messengerA)),
            dstAddress: PeerLib.addressToBytes32(address(messengerB)),
            nonce: 1,
            payload: hex"cc"
        });
        Origin memory origin = Origin({
            srcEid: uint32(CHAIN_A),
            sender: PeerLib.addressToBytes32(address(adapterA)),
            nonce: 1
        });

        vm.prank(address(endpoint));
        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        adapterB.lzReceive(origin, bytes32(uint256(2)), PacketCodec.encode(packet), address(0), "");
    }
}
