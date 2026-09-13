// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IMessageReceiver} from "../interfaces/IMessageReceiver.sol";
import {MessagingErrors} from "../errors/MessagingErrors.sol";
import {PeerLib} from "../libraries/PeerLib.sol";

/**
 * @title RemoteStakeReceiver
 * @notice Demo de ejecucion remota: stake/unstake via mensaje cross-chain autenticado.
 * @dev Solo el `messenger` configurado puede invocar `onMessageReceived`.
 *      Payload: `abi.encode(address user, uint256 amount, bool isStake)`.
 */
contract RemoteStakeReceiver is IMessageReceiver, Ownable2Step {
    /// @notice Messenger autorizado a entregar mensajes.
    address public messenger;

    /// @notice Balance staked por usuario (unidades abstractas del payload).
    mapping(address user => uint256 amount) public staked;

    /// @notice Stake actualizado tras un mensaje remoto.
    event StakeUpdated(address indexed user, uint256 amount, bool indexed isStake, uint64 indexed srcChainId);

    /// @notice Messenger actualizado.
    event MessengerUpdated(address indexed messenger);

    /**
     * @notice Despliega el receiver.
     * @param messenger_ Messenger local de confianza (puede ser cero y setearse luego).
     * @param owner_ Owner administrativo.
     */
    constructor(address messenger_, address owner_) Ownable(owner_) {
        PeerLib.requireNonZero(owner_);
        if (messenger_ != address(0)) {
            messenger = messenger_;
        }
    }

    /// @inheritdoc IMessageReceiver
    function onMessageReceived(uint64 srcChainId, bytes32, bytes calldata payload) external override {
        if (msg.sender != messenger) revert MessagingErrors.UnauthorizedCaller();
        if (payload.length == 0) revert MessagingErrors.InvalidPayload();

        (address user, uint256 amount, bool isStake) = abi.decode(payload, (address, uint256, bool));
        if (user == address(0)) revert MessagingErrors.ZeroAddress();
        if (amount == 0) revert MessagingErrors.ZeroAmount();

        if (isStake) {
            staked[user] += amount;
        } else {
            uint256 current = staked[user];
            if (current < amount) revert MessagingErrors.InvalidPayload();
            unchecked {
                staked[user] = current - amount;
            }
        }

        emit StakeUpdated(user, amount, isStake, srcChainId);
    }

    /**
     * @notice Configura el messenger autorizado.
     * @param messenger_ `CrossChainMessenger` local.
     */
    function setMessenger(address messenger_) external onlyOwner {
        PeerLib.requireNonZero(messenger_);
        messenger = messenger_;
        emit MessengerUpdated(messenger_);
    }
}
