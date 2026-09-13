// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke test de Fase 0: forge-std, OZ remappings y compilacion.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_ping() public view {
        assertEq(placeholder.ping(), 1);
    }

    /// @dev Valida que el remapping `@openzeppelin/contracts` resuelve.
    function test_openzeppelinRemapping() public pure {
        assertTrue(type(IERC20).interfaceId != bytes4(0));
    }
}
