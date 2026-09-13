// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MessagingErrors
 * @notice Custom errors del modulo 16 (cross-chain messaging).
 * @dev Preferidos sobre `require` con strings (suite).
 */
library MessagingErrors {
    /// @notice Remitente remoto no coincide con el peer trusted de `srcChainId`.
    error InvalidSourceSender();

    /// @notice El `messageHash` ya fue ejecutado (anti-replay / idempotencia).
    error MessageAlreadyProcessed();

    /// @notice `msg.value` insuficiente frente al fee cotizado.
    error InsufficientFee();

    /// @notice Fallo el refund ETH del sobrante al caller.
    error EthRefundFailed();

    /// @notice Direccion cero donde se exige un valor valido.
    error ZeroAddress();

    /// @notice Peer mal configurado (cero o ruta no soportada al setear).
    error InvalidPeer();

    /// @notice Payload vacio o no decodable para la app destino.
    error InvalidPayload();

    /// @notice Caller no es el endpoint/router/relayer autorizado.
    error UnauthorizedCaller();

    /// @notice Cadena destino/origen sin peer configurado.
    error UnsupportedChain();

    /// @notice Cantidad cero donde no se permite.
    error ZeroAmount();
}
