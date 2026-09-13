// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../errors/MessagingErrors.sol";

/**
 * @title FeeRefundLib
 * @notice Refund seguro del ETH sobrante tras pagar el fee de mensajeria.
 * @dev Usa `.call{value: ...}("")` (suite). `fee == msg.value` => no-op.
 */
library FeeRefundLib {
    /**
     * @notice Valida `msg.value >= fee` y reembolsa el exceso a `refundTo`.
     * @param refundTo Receptor del sobrante (tipicamente `msg.sender`).
     * @param fee Fee consumido por el transporte.
     */
    function refundExcess(address refundTo, uint256 fee) internal {
        if (msg.value < fee) revert MessagingErrors.InsufficientFee();
        uint256 excess;
        unchecked {
            excess = msg.value - fee;
        }
        if (excess == 0) return;
        if (refundTo == address(0)) revert MessagingErrors.ZeroAddress();

        (bool ok,) = refundTo.call{value: excess}("");
        if (!ok) revert MessagingErrors.EthRefundFailed();
    }
}
