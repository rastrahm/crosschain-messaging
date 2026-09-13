// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {CrossChainMessenger} from "../../src/CrossChainMessenger.sol";
import {MockTransportAdapter} from "../../src/mocks/MockTransportAdapter.sol";
import {MockRelayer} from "../../src/mocks/MockRelayer.sol";
import {RemoteStakeReceiver} from "../../src/apps/RemoteStakeReceiver.sol";
import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {PeerLib} from "../../src/libraries/PeerLib.sol";
import {Packet, PacketCodec} from "../../src/libraries/PacketCodec.sol";
import {ForkHelper} from "../helpers/ForkHelper.sol";

/**
 * @title DualForkTest
 * @notice Fase 6: dispatch en fork origen + receive en fork destino.
 * @dev Requiere `SRC_RPC_URL` y `DST_RPC_URL` en el entorno. Sin ellas → `vm.skip`.
 *      Usa chain ids de laboratorio (1 / 2) y transports mock; los forks aportan EVM real
 *      (gas schedule / state root) sin depender de endpoints LZ/CCIP live.
 *
 *      Ejemplo:
 *        SRC_RPC_URL=... DST_RPC_URL=... forge test --match-path 'test/fork/*' -vv
 */
contract DualForkTest is ForkHelper {
    uint64 internal constant CHAIN_A = 1;
    uint64 internal constant CHAIN_B = 2;
    uint256 internal constant FEE = 0.01 ether;

    address internal owner;
    address internal user;

    // Addresses persist across fork switches (logical peers).
    address internal messengerAAddr;
    address internal messengerBAddr;
    address internal transportAAddr;
    address internal transportBAddr;
    address internal relayerBAddr;
    address internal stakeAppAddr;

    function setUp() public {
        _tryCreateDualForks();
        if (!dualForked) return;

        owner = makeAddr("owner");
        user = makeAddr("user");

        // --- Destino primero (para conocer address del peer) ---
        vm.selectFork(dstForkId);
        vm.deal(user, 100 ether);
        vm.startPrank(owner);
        MockTransportAdapter transportB = new MockTransportAdapter(FEE);
        MockRelayer relayerB = new MockRelayer();
        CrossChainMessenger messengerB = new CrossChainMessenger(CHAIN_B, owner);
        RemoteStakeReceiver stakeApp = new RemoteStakeReceiver(address(messengerB), owner);

        messengerB.setAdapter(address(transportB));
        messengerB.setDeliverer(address(relayerB));
        messengerB.setReceiver(address(stakeApp));

        transportBAddr = address(transportB);
        relayerBAddr = address(relayerB);
        messengerBAddr = address(messengerB);
        stakeAppAddr = address(stakeApp);
        vm.stopPrank();

        // --- Origen ---
        vm.selectFork(srcForkId);
        vm.deal(user, 100 ether);
        vm.startPrank(owner);
        MockTransportAdapter transportA = new MockTransportAdapter(FEE);
        CrossChainMessenger messengerA = new CrossChainMessenger(CHAIN_A, owner);
        messengerA.setAdapter(address(transportA));
        messengerA.setPeer(CHAIN_B, PeerLib.addressToBytes32(messengerBAddr));
        transportAAddr = address(transportA);
        messengerAAddr = address(messengerA);
        vm.stopPrank();

        // Peer origen en destino
        vm.selectFork(dstForkId);
        vm.prank(owner);
        CrossChainMessenger(payable(messengerBAddr)).setPeer(
            CHAIN_A, PeerLib.addressToBytes32(messengerAAddr)
        );
    }

    function test_dualFork_sendAndReceive_stake() public {
        _skipIfNoDualFork();

        bytes memory payload = abi.encode(user, uint256(7 ether), true);

        // Dispatch en origen
        vm.selectFork(srcForkId);
        vm.prank(user);
        bytes32 messageHash = CrossChainMessenger(payable(messengerAAddr)).send{value: FEE}(CHAIN_B, payload);

        Packet memory packet = _readLastPacket(transportAAddr);
        assertEq(PacketCodec.messageHash(packet), messageHash);

        // Entrega en destino
        vm.selectFork(dstForkId);
        MockRelayer(relayerBAddr).relay(CrossChainMessenger(payable(messengerBAddr)), packet);

        assertTrue(CrossChainMessenger(payable(messengerBAddr)).processedMessages(messageHash));
        assertEq(RemoteStakeReceiver(stakeAppAddr).staked(user), 7 ether);
    }

    function test_dualFork_replayOnDestination_reverts() public {
        _skipIfNoDualFork();

        bytes memory payload = abi.encode(user, uint256(1 ether), true);

        vm.selectFork(srcForkId);
        vm.prank(user);
        CrossChainMessenger(payable(messengerAAddr)).send{value: FEE}(CHAIN_B, payload);
        Packet memory packet = _readLastPacket(transportAAddr);

        vm.selectFork(dstForkId);
        MockRelayer(relayerBAddr).relay(CrossChainMessenger(payable(messengerBAddr)), packet);

        vm.expectRevert(MessagingErrors.MessageAlreadyProcessed.selector);
        MockRelayer(relayerBAddr).relay(CrossChainMessenger(payable(messengerBAddr)), packet);
    }

    function _readLastPacket(address transport) internal view returns (Packet memory) {
        (
            uint64 srcChainId,
            uint64 dstChainId,
            bytes32 srcAddress,
            bytes32 dstAddress,
            uint64 nonce,
            bytes memory payload
        ) = MockTransportAdapter(payable(transport)).lastPacket();
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
