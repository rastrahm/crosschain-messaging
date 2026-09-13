// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

import {MessagingErrors} from "../../src/errors/MessagingErrors.sol";
import {RejectETH} from "../../src/mocks/RejectETH.sol";
import {FeeRefundLibHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title FeeRefundLibTest
 * @notice Unit + fuzz de quote check y refund ETH sobrante.
 */
contract FeeRefundLibTest is Test {
    FeeRefundLibHarness internal harness;
    address internal recipient;

    function setUp() public {
        harness = new FeeRefundLibHarness();
        recipient = makeAddr("refundTo");
    }

    function test_refundExcess_exactFee_noop() public {
        uint256 beforeBal = recipient.balance;
        harness.refundExcess{value: 1 ether}(recipient, 1 ether);
        assertEq(recipient.balance, beforeBal);
        assertEq(address(harness).balance, 1 ether);
    }

    function test_refundExcess_refundsDifference() public {
        harness.refundExcess{value: 3 ether}(recipient, 1 ether);
        assertEq(recipient.balance, 2 ether);
        assertEq(address(harness).balance, 1 ether);
    }

    function test_refundExcess_revertsInsufficientFee() public {
        vm.expectRevert(MessagingErrors.InsufficientFee.selector);
        harness.refundExcess{value: 0.5 ether}(recipient, 1 ether);
    }

    function test_refundExcess_revertsZeroRefundToWhenExcess() public {
        vm.expectRevert(MessagingErrors.ZeroAddress.selector);
        harness.refundExcess{value: 2 ether}(address(0), 1 ether);
    }

    function test_refundExcess_zeroRefundToOkWhenNoExcess() public {
        // excess == 0 => early return before zero-address check
        harness.refundExcess{value: 1 ether}(address(0), 1 ether);
        assertEq(address(harness).balance, 1 ether);
    }

    function test_refundExcess_revertsWhenRecipientRejects() public {
        RejectETH rejector = new RejectETH();
        vm.expectRevert(MessagingErrors.EthRefundFailed.selector);
        harness.refundExcess{value: 2 ether}(address(rejector), 1 ether);
    }

    function testFuzz_refundExcess(uint96 valueSent, uint96 fee) public {
        valueSent = uint96(bound(valueSent, 0, 50 ether));
        fee = uint96(bound(fee, 0, 50 ether));
        vm.deal(address(this), valueSent);

        if (valueSent < fee) {
            vm.expectRevert(MessagingErrors.InsufficientFee.selector);
            harness.refundExcess{value: valueSent}(recipient, fee);
            return;
        }

        uint256 beforeRecipient = recipient.balance;
        uint256 beforeHarness = address(harness).balance;
        harness.refundExcess{value: valueSent}(recipient, fee);
        uint256 excess = uint256(valueSent) - uint256(fee);
        assertEq(recipient.balance, beforeRecipient + excess);
        assertEq(address(harness).balance, beforeHarness + fee);
    }

    receive() external payable {}
}
