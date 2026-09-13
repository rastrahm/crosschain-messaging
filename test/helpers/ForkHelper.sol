// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/**
 * @title ForkHelper
 * @notice Utilidades para dual-fork (`SRC_RPC_URL` / `DST_RPC_URL`).
 * @dev Sin ambas URLs la suite hace `vm.skip` (CI verde sin RPC).
 */
abstract contract ForkHelper is Test {
    uint256 internal srcForkId;
    uint256 internal dstForkId;
    bool internal dualForked;

    /**
     * @notice Intenta crear dos forks desde env. No revierte si faltan URLs.
     */
    function _tryCreateDualForks() internal {
        string memory srcRpc = _envOrEmpty("SRC_RPC_URL");
        string memory dstRpc = _envOrEmpty("DST_RPC_URL");
        if (bytes(srcRpc).length == 0 || bytes(dstRpc).length == 0) {
            return;
        }

        srcForkId = vm.createFork(srcRpc);
        dstForkId = vm.createFork(dstRpc);
        dualForked = true;
    }

    /**
     * @notice Salta el test si no hay dual-fork activo.
     */
    function _skipIfNoDualFork() internal {
        if (!dualForked) {
            vm.skip(true);
        }
    }

    function _envOrEmpty(string memory key) private view returns (string memory value) {
        try vm.envString(key) returns (string memory v) {
            return v;
        } catch {
            return "";
        }
    }
}
