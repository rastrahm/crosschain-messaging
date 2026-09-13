// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {CrossChainMessenger} from "../../src/CrossChainMessenger.sol";
import {MockTransportAdapter} from "../../src/mocks/MockTransportAdapter.sol";
import {MockRelayer} from "../../src/mocks/MockRelayer.sol";
import {MockMessageReceiver} from "../../src/mocks/MockMessageReceiver.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {Packet} from "../../src/libraries/PacketCodec.sol";

/**
 * @title MessagingTestBase
 * @notice Setup dual-messenger in-process para unit tests AMP.
 */
abstract contract MessagingTestBase is Test {
    uint64 internal constant CHAIN_A = 1;
    uint64 internal constant CHAIN_B = 2;
    uint256 internal constant FEE = 0.01 ether;

    CrossChainMessenger internal messengerA;
    CrossChainMessenger internal messengerB;
    MockTransportAdapter internal transportA;
    MockTransportAdapter internal transportB;
    MockRelayer internal relayer;
    MockMessageReceiver internal appB;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    function setUp() public virtual {
        vm.deal(user, 100 ether);

        transportA = new MockTransportAdapter(FEE);
        transportB = new MockTransportAdapter(FEE);
        relayer = new MockRelayer();
        appB = new MockMessageReceiver();

        vm.startPrank(owner);
        messengerA = new CrossChainMessenger(CHAIN_A, owner);
        messengerB = new CrossChainMessenger(CHAIN_B, owner);

        messengerA.setAdapter(address(transportA));
        messengerB.setAdapter(address(transportB));

        messengerA.setPeer(CHAIN_B, PeerLib.addressToBytes32(address(messengerB)));
        messengerB.setPeer(CHAIN_A, PeerLib.addressToBytes32(address(messengerA)));

        messengerA.setDeliverer(address(relayer));
        messengerB.setDeliverer(address(relayer));

        messengerB.setReceiver(address(appB));
        vm.stopPrank();
    }

    /**
     * @notice Envia desde A y entrega en B via MockRelayer.
     * @param payload Payload app.
     * @param value ETH enviado con `send`.
     * @return packet Paquete despachado.
     * @return messageHash Hash del mensaje.
     */
    function _sendAndRelay(bytes memory payload, uint256 value)
        internal
        returns (Packet memory packet, bytes32 messageHash)
    {
        vm.prank(user);
        messageHash = messengerA.send{value: value}(CHAIN_B, payload);
        packet = _lastPacketA();
        relayer.relay(messengerB, packet);
    }

    function _lastPacketA() internal view returns (Packet memory) {
        (
            uint64 srcChainId,
            uint64 dstChainId,
            bytes32 srcAddress,
            bytes32 dstAddress,
            uint64 nonce,
            bytes memory payload
        ) = transportA.lastPacket();
        return Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: payload
        });
    }
}
