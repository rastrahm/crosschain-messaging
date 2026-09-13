// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {CrossChainMessenger} from "../src/CrossChainMessenger.sol";
import {MockTransportAdapter} from "../src/mocks/MockTransportAdapter.sol";
import {MockRelayer} from "../src/mocks/MockRelayer.sol";
import {RemoteStakeReceiver} from "../src/apps/RemoteStakeReceiver.sol";
import {PeerLib} from "../src/libraries/PeerLib.sol";
import {Packet} from "../src/libraries/PacketCodec.sol";

/**
 * @title SimulateRelay
 * @notice Simula el camino evento → relay → receive de mensajeria cross-chain.
 * @dev Flujo documentado (lab / Anvil / fork unico):
 *
 *      1. Usuario llama `messengerA.send{value}(dstChainId, payload)`
 *         - Se cotiza fee (`adapter.quote`)
 *         - Se arma `Packet` + `messageHash`
 *         - `adapter.dispatch` consume el fee
 *         - Refund del sobrante a `msg.sender`
 *         - Evento `MessageSent(messageHash, dstChainId, nonce, payload)`
 *
 *      2. Relayer off-chain (aqui `MockRelayer`) observa el evento / lee el packet
 *         del transport y llama `messengerB.receivePacket(packet)` en destino.
 *
 *      3. Destino verifica deliverer + peer (`srcChainId`/`srcAddress`) + anti-replay,
 *         marca `processedMessages[hash]`, invoca `RemoteStakeReceiver`.
 *
 *      Dual-fork real: ver `test/fork/DualFork.t.sol` con `SRC_RPC_URL` + `DST_RPC_URL`.
 *      Este script es simulacion in-process (sin `startBroadcast`) para demo local.
 *      Deploy on-chain: `script/Deploy.s.sol` (Fase 7).
 *
 * Uso:
 *   forge script script/SimulateRelay.s.sol:SimulateRelay -vvv
 *   forge script script/SimulateRelay.s.sol:SimulateRelay --fork-url $SRC_RPC_URL -vvv
 *
 * Env opcionales:
 * - PRIVATE_KEY — deriva el address del "usuario" demo (default Anvil #0)
 * - STAKE_AMOUNT — amount del payload (default 5 ether)
 */
contract SimulateRelay is Script {
    uint64 internal constant CHAIN_A = 1;
    uint64 internal constant CHAIN_B = 2;
    uint256 internal constant FEE = 0.01 ether;

    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address user = vm.addr(pk);
        address deployer = user;
        uint256 stakeAmount = vm.envOr("STAKE_AMOUNT", uint256(5 ether));

        vm.deal(user, 100 ether);

        MockTransportAdapter transportA = new MockTransportAdapter(FEE);
        MockTransportAdapter transportB = new MockTransportAdapter(FEE);
        MockRelayer relayer = new MockRelayer();

        CrossChainMessenger messengerA = new CrossChainMessenger(CHAIN_A, deployer);
        CrossChainMessenger messengerB = new CrossChainMessenger(CHAIN_B, deployer);
        RemoteStakeReceiver stakeApp = new RemoteStakeReceiver(address(messengerB), deployer);

        messengerA.setAdapter(address(transportA));
        messengerB.setAdapter(address(transportB));
        messengerA.setPeer(CHAIN_B, PeerLib.addressToBytes32(address(messengerB)));
        messengerB.setPeer(CHAIN_A, PeerLib.addressToBytes32(address(messengerA)));
        messengerA.setDeliverer(address(relayer));
        messengerB.setDeliverer(address(relayer));
        messengerB.setReceiver(address(stakeApp));

        bytes memory payload = abi.encode(user, stakeAmount, true);

        console2.log("1) send on origin messenger");
        vm.prank(user);
        bytes32 messageHash = messengerA.send{value: FEE}(CHAIN_B, payload);

        (
            uint64 srcChainId,
            uint64 dstChainId,
            bytes32 srcAddress,
            bytes32 dstAddress,
            uint64 nonce,
            bytes memory storedPayload
        ) = transportA.lastPacket();

        Packet memory packet = Packet({
            srcChainId: srcChainId,
            dstChainId: dstChainId,
            srcAddress: srcAddress,
            dstAddress: dstAddress,
            nonce: nonce,
            payload: storedPayload
        });

        console2.log("2) relayer delivers packet to destination");
        relayer.relay(messengerB, packet);

        console2.log("3) destination state");
        console2.log("messageHash:");
        console2.logBytes32(messageHash);
        console2.log("staked:", stakeApp.staked(user));
        console2.log("processed:", messengerB.processedMessages(messageHash));
        console2.log("SimulateRelay OK");
    }
}
