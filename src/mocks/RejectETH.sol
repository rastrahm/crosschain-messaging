// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title RejectETH
 * @notice Contrato sin `receive`/`fallback` payable: cualquier ETH falla.
 * @dev Usado para assertar `EthRefundFailed` en `FeeRefundLib`.
 */
contract RejectETH {
    // Intencionalmente vacio: no acepta ETH.
}
