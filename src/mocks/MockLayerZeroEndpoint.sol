// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    ILayerZeroEndpointV2,
    ILayerZeroReceiver,
    MessagingFee,
    MessagingParams,
    MessagingReceipt,
    Origin
} from "../interfaces/ILayerZeroEndpointV2.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";
import {PeerLib} from "../libraries/PeerLib.sol";

/**
 * @title MockLayerZeroEndpoint
 * @notice Endpoint V2 de laboratorio: fee fijo + cola entregable a adapters.
 * @dev Un endpoint compartido; cada OApp registra su `eid` con `registerOApp`.
 */
contract MockLayerZeroEndpoint is ILayerZeroEndpointV2 {
    /// @notice Fee nativo fijo por mensaje.
    uint256 public immutable nativeFee;

    /// @notice Eid registrado por OApp (adapter).
    mapping(address oapp => uint32 eid) public eidOf;

    /// @notice Nonce outbound por (sender, dstEid).
    mapping(address sender => mapping(uint32 dstEid => uint64 nonce)) public outboundNonce;

    struct Pending {
        uint32 srcEid;
        bytes32 sender;
        uint64 nonce;
        uint32 dstEid;
        bytes32 receiver;
        bytes32 guid;
        bytes message;
        bool delivered;
    }

    /// @notice Cola de mensajes pendientes de entrega.
    Pending[] public pending;

    /**
     * @notice Crea el mock endpoint.
     * @param nativeFee_ Fee en wei.
     */
    constructor(uint256 nativeFee_) {
        nativeFee = nativeFee_;
    }

    /**
     * @notice Registra el eid del OApp llamante (adapter).
     * @param eid Endpoint id local del adapter.
     */
    function registerOApp(uint32 eid) external {
        if (eid == 0) revert MessagingErrors.UnsupportedChain();
        eidOf[msg.sender] = eid;
    }

    /// @inheritdoc ILayerZeroEndpointV2
    function quote(MessagingParams calldata, address)
        external
        view
        override
        returns (MessagingFee memory fee)
    {
        fee = MessagingFee({nativeFee: nativeFee, lzTokenFee: 0});
    }

    /// @inheritdoc ILayerZeroEndpointV2
    function send(MessagingParams calldata params, address refundAddress)
        external
        payable
        override
        returns (MessagingReceipt memory receipt)
    {
        uint32 srcEid = eidOf[msg.sender];
        if (srcEid == 0) revert MessagingErrors.UnauthorizedCaller();
        if (params.receiver == bytes32(0)) revert MessagingErrors.InvalidPeer();
        if (msg.value < nativeFee) revert MessagingErrors.InsufficientFee();

        uint64 nonce;
        unchecked {
            nonce = ++outboundNonce[msg.sender][params.dstEid];
        }

        bytes32 sender = PeerLib.addressToBytes32(msg.sender);
        bytes32 guid =
            keccak256(abi.encode(srcEid, sender, params.dstEid, nonce, keccak256(params.message)));

        pending.push(
            Pending({
                srcEid: srcEid,
                sender: sender,
                nonce: nonce,
                dstEid: params.dstEid,
                receiver: params.receiver,
                guid: guid,
                message: params.message,
                delivered: false
            })
        );

        uint256 excess;
        unchecked {
            excess = msg.value - nativeFee;
        }
        if (excess > 0) {
            if (refundAddress == address(0)) revert MessagingErrors.ZeroAddress();
            (bool ok,) = refundAddress.call{value: excess}("");
            if (!ok) revert MessagingErrors.EthRefundFailed();
        }

        receipt = MessagingReceipt({
            guid: guid,
            nonce: nonce,
            fee: MessagingFee({nativeFee: nativeFee, lzTokenFee: 0})
        });
    }

    /**
     * @notice Cantidad de mensajes en cola.
     * @return count Longitud de `pending`.
     */
    function pendingLength() external view returns (uint256 count) {
        return pending.length;
    }

    /**
     * @notice Entrega el mensaje en `index` al adapter destino.
     * @param index Indice en `pending`.
     */
    function deliver(uint256 index) external {
        if (index >= pending.length) revert MessagingErrors.InvalidPayload();
        Pending storage p = pending[index];
        if (p.delivered) revert MessagingErrors.MessageAlreadyProcessed();
        p.delivered = true;

        ILayerZeroReceiver(PeerLib.bytes32ToAddress(p.receiver)).lzReceive(
            Origin({srcEid: p.srcEid, sender: p.sender, nonce: p.nonce}),
            p.guid,
            p.message,
            address(0),
            ""
        );
    }

    /**
     * @notice Entrega el ultimo mensaje encolado.
     */
    function deliverLast() external {
        if (pending.length == 0) revert MessagingErrors.InvalidPayload();
        this.deliver(pending.length - 1);
    }

    receive() external payable {}
}
