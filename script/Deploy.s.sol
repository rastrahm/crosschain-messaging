// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {CrossChainMessenger} from "../src/CrossChainMessenger.sol";
import {MockTransportAdapter} from "../src/mocks/MockTransportAdapter.sol";
import {MockRelayer} from "../src/mocks/MockRelayer.sol";
import {RemoteStakeReceiver} from "../src/apps/RemoteStakeReceiver.sol";
import {LayerZeroV2Adapter} from "../src/adapters/LayerZeroV2Adapter.sol";
import {CCIPAdapter} from "../src/adapters/CCIPAdapter.sol";
import {MockLayerZeroEndpoint} from "../src/mocks/MockLayerZeroEndpoint.sol";
import {MockCCIPRouter} from "../src/mocks/MockCCIPRouter.sol";
import {PeerLib} from "../src/libraries/PeerLib.sol";

/**
 * @title Deploy
 * @notice Despliega stack demo dual-messenger + transports + adapters + stake app.
 * @dev Ejemplo Anvil:
 *      `forge script script/Deploy.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast`
 *
 * Env opcionales:
 * - `PRIVATE_KEY` — deployer (default Anvil #0)
 * - `FEE_WEI` — fee mock transport/endpoint/router (default 0.01 ether)
 * - `CHAIN_A` / `CHAIN_B` — ids locales (default 1 / 2)
 */
contract Deploy is Script {
    function run() external {
        uint256 pk =
            vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address deployer = vm.addr(pk);
        uint256 fee = vm.envOr("FEE_WEI", uint256(0.01 ether));
        uint64 chainA = uint64(vm.envOr("CHAIN_A", uint256(1)));
        uint64 chainB = uint64(vm.envOr("CHAIN_B", uint256(2)));

        vm.startBroadcast(pk);

        MockTransportAdapter transportA = new MockTransportAdapter(fee);
        MockTransportAdapter transportB = new MockTransportAdapter(fee);
        MockRelayer relayer = new MockRelayer();

        CrossChainMessenger messengerA = new CrossChainMessenger(chainA, deployer);
        CrossChainMessenger messengerB = new CrossChainMessenger(chainB, deployer);
        RemoteStakeReceiver stakeApp = new RemoteStakeReceiver(address(messengerB), deployer);

        messengerA.setAdapter(address(transportA));
        messengerB.setAdapter(address(transportB));
        messengerA.setPeer(chainB, PeerLib.addressToBytes32(address(messengerB)));
        messengerB.setPeer(chainA, PeerLib.addressToBytes32(address(messengerA)));
        messengerA.setDeliverer(address(relayer));
        messengerB.setDeliverer(address(relayer));
        messengerB.setReceiver(address(stakeApp));

        // Adapters LZ / CCIP listos para cablear (no sustituyen el transport mock por defecto).
        MockLayerZeroEndpoint lzEndpoint = new MockLayerZeroEndpoint(fee);
        LayerZeroV2Adapter lzA = new LayerZeroV2Adapter(address(lzEndpoint), address(messengerA), deployer);
        LayerZeroV2Adapter lzB = new LayerZeroV2Adapter(address(lzEndpoint), address(messengerB), deployer);
        lzA.setLzPeer(chainB, PeerLib.addressToBytes32(address(lzB)));
        lzB.setLzPeer(chainA, PeerLib.addressToBytes32(address(lzA)));

        MockCCIPRouter ccipRouter = new MockCCIPRouter(fee);
        CCIPAdapter ccipA = new CCIPAdapter(address(ccipRouter), address(messengerA), deployer);
        CCIPAdapter ccipB = new CCIPAdapter(address(ccipRouter), address(messengerB), deployer);
        ccipA.setCcipPeer(chainB, address(ccipB));
        ccipB.setCcipPeer(chainA, address(ccipA));

        console2.log("messengerA", address(messengerA));
        console2.log("messengerB", address(messengerB));
        console2.log("stakeApp", address(stakeApp));
        console2.log("relayer", address(relayer));
        console2.log("lzEndpoint", address(lzEndpoint));
        console2.log("ccipRouter", address(ccipRouter));
        console2.log("lzAdapterA", address(lzA));
        console2.log("ccipAdapterA", address(ccipA));

        vm.stopBroadcast();
    }
}
