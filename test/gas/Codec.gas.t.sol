// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PacketCodecHarness, FeeRefundLibHarness} from "../helpers/LibHarnesses.sol";
import {Packet} from "../../src/libraries/PacketCodec.sol";
import {MessagingTestBase} from "../helpers/MessagingTestBase.sol";

/**
 * @title CodecGasTest
 * @notice Fase 7: ABI vs Yul decode + hot paths send/receive + refund (`.gas-snapshot`).
 */
contract CodecGasTest is MessagingTestBase {
    PacketCodecHarness internal codec;
    FeeRefundLibHarness internal refundHarness;

    Packet internal sample;

    function setUp() public override {
        super.setUp();
        codec = new PacketCodecHarness();
        refundHarness = new FeeRefundLibHarness();
        vm.deal(address(refundHarness), 50 ether);

        sample = Packet({
            srcChainId: CHAIN_A,
            dstChainId: CHAIN_B,
            srcAddress: bytes32(uint256(uint160(address(messengerA)))),
            dstAddress: bytes32(uint256(uint160(address(messengerB)))),
            nonce: 1,
            payload: abi.encode(user, uint256(1 ether), true)
        });
    }

    /// @notice Decode ABI (portable).
    function testGas_codec_decodeAbi() public view {
        codec.decode(codec.encode(sample));
    }

    /// @notice Decode packed Yul (hot path adapters).
    function testGas_codec_decodeYul() public view {
        codec.decodeYul(codec.encodePacked(sample));
    }

    /// @notice Hash memory.
    function testGas_codec_messageHashMemory() public view {
        codec.messageHash(sample);
    }

    /// @notice Hash calldata (via ABI-encode del external call).
    function testGas_codec_messageHashCalldata() public view {
        Packet memory p = sample;
        codec.messageHashCalldata(p);
    }

    /// @notice Refund Solidity `.call`.
    function testGas_refund_call() public {
        refundHarness.refundExcess{value: 1 ether}(user, 0.5 ether);
    }

    /// @notice Refund Yul (path send).
    function testGas_refund_assembly() public {
        refundHarness.refundExcessAssembly{value: 1 ether}(user, 0.5 ether);
    }

    /// @notice Send exact fee (sin refund).
    function testGas_messenger_sendExactFee() public {
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, sample.payload);
    }

    /// @notice Send + refund exceso.
    function testGas_messenger_sendWithRefund() public {
        vm.prank(user);
        messengerA.send{value: 1 ether}(CHAIN_B, sample.payload);
    }

    /// @notice Receive via MockRelayer (idempotencia + app mock).
    function testGas_messenger_receive() public {
        vm.prank(user);
        messengerA.send{value: FEE}(CHAIN_B, hex"01");
        Packet memory packet = _lastPacketA();
        relayer.relay(messengerB, packet);
    }
}
