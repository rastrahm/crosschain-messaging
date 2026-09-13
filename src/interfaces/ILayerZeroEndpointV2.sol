// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title Origin
 * @notice Origen LZ V2 de un mensaje entrante.
 */
struct Origin {
    uint32 srcEid;
    bytes32 sender;
    uint64 nonce;
}

/**
 * @title MessagingFee
 * @notice Fee nativo + opcional LZ token (v1 lab: solo nativeFee).
 */
struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

/**
 * @title MessagingParams
 * @notice Parametros de `quote` / `send` estilo Endpoint V2.
 */
struct MessagingParams {
    uint32 dstEid;
    bytes32 receiver;
    bytes message;
    bytes options;
    bool payInLzToken;
}

/**
 * @title MessagingReceipt
 * @notice Recibo de un `send` LZ.
 */
struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

/**
 * @title ILayerZeroEndpointV2
 * @notice Superficie minima del Endpoint V2 para lab / mocks.
 */
interface ILayerZeroEndpointV2 {
    /**
     * @notice Cotiza el fee de envio.
     * @param params Parametros de mensajeria.
     * @param sender OApp que enviaria (adapter).
     * @return fee Native + lzToken fee.
     */
    function quote(MessagingParams calldata params, address sender)
        external
        view
        returns (MessagingFee memory fee);

    /**
     * @notice Despacha un mensaje cross-chain.
     * @param params Parametros de mensajeria.
     * @param refundAddress Refund de exceso del endpoint.
     * @return receipt GUID + nonce + fee cobrado.
     */
    function send(MessagingParams calldata params, address refundAddress)
        external
        payable
        returns (MessagingReceipt memory receipt);
}

/**
 * @title ILayerZeroReceiver
 * @notice Callback de recepcion estilo OApp / Endpoint V2.
 */
interface ILayerZeroReceiver {
    /**
     * @notice Entrega un mensaje desde el endpoint.
     * @param origin Cadena/sender/nonce de origen.
     * @param guid Identificador global del mensaje.
     * @param message Payload (Packet ABI-encoded en este modulo).
     * @param executor Executor LZ (ignorado en mock).
     * @param extraData Datos extra (ignorado en mock).
     */
    function lzReceive(
        Origin calldata origin,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) external payable;
}
