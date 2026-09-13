// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MessagingErrors} from "../errors/MessagingErrors.sol";

/**
 * @title FeeRefundLib
 * @notice Refund seguro del ETH sobrante tras pagar el fee de mensajeria.
 * @dev `refundExcess` usa `.call`; `refundExcessAssembly` usa Yul (hot path send).
 */
library FeeRefundLib {
    /**
     * @notice Valida `msg.value >= fee` y reembolsa el exceso con `.call`.
     * @param refundTo Receptor del sobrante.
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

    /**
     * @notice Igual que `refundExcess` con `call` Yul (sin returndata).
     * @param refundTo Receptor del sobrante.
     * @param fee Fee consumido.
     * @dev Path de produccion en `CrossChainMessenger.send`.
     */
    function refundExcessAssembly(address refundTo, uint256 fee) internal {
        if (msg.value < fee) revert MessagingErrors.InsufficientFee();
        uint256 excess;
        unchecked {
            excess = msg.value - fee;
        }
        if (excess == 0) return;
        if (refundTo == address(0)) revert MessagingErrors.ZeroAddress();

        bool ok;
        assembly ("memory-safe") {
            ok := call(gas(), refundTo, excess, 0, 0, 0, 0)
        }
        if (!ok) revert MessagingErrors.EthRefundFailed();
    }
}
