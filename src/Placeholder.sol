// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Placeholder
 * @notice Stub de Fase 0 para validar compilacion y remappings.
 * @dev Se elimina en Fase 1 al introducir `MessagingErrors` / libs.
 */
contract Placeholder {
    /// @notice Valor fijo para smoke test.
    /// @return Constante `1`.
    function ping() external pure returns (uint256) {
        return 1;
    }
}
