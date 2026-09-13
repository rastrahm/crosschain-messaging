// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title EVM2AnyMessage
 * @notice Mensaje saliente estilo Chainlink CCIP `Client.EVM2AnyMessage` (lab, sin tokens).
 */
struct EVM2AnyMessage {
    bytes receiver;
    bytes data;
    address feeToken;
    bytes extraArgs;
}

/**
 * @title Any2EVMMessage
 * @notice Mensaje entrante estilo `Client.Any2EVMMessage` (lab, sin tokens).
 */
struct Any2EVMMessage {
    bytes32 messageId;
    uint64 sourceChainSelector;
    bytes sender;
    bytes data;
}

/**
 * @title ICCIPRouter
 * @notice Superficie minima de `IRouterClient` para lab / mocks.
 */
interface ICCIPRouter {
    /**
     * @notice Cotiza el fee nativo (feeToken == address(0)).
     * @param destinationChainSelector Selector CCIP destino.
     * @param message Mensaje a enviar.
     * @return fee Fee en wei.
     */
    function getFee(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external
        view
        returns (uint256 fee);

    /**
     * @notice Despacha un mensaje CCIP.
     * @param destinationChainSelector Selector destino.
     * @param message Mensaje a enviar.
     * @return messageId Identificador del mensaje.
     */
    function ccipSend(uint64 destinationChainSelector, EVM2AnyMessage memory message)
        external
        payable
        returns (bytes32 messageId);
}

/**
 * @title IAny2EVMMessageReceiver
 * @notice Callback de recepcion CCIP (`ccipReceive`).
 */
interface IAny2EVMMessageReceiver {
    /**
     * @notice Entrega un mensaje desde el router.
     * @param message Mensaje Any2EVM.
     */
    function ccipReceive(Any2EVMMessage calldata message) external;
}
