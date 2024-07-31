// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SafeTransfer {
    using SafeERC20 for IERC20;

    event SafeTransferFrom(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount
    );

    function safeReceive(address token, uint256 amount) internal {
        if (token != address(0) && amount > 0) {
            IERC20 oToken = IERC20(token);
            oToken.safeTransferFrom(msg.sender, address(this), amount);
            emit SafeTransferFrom(msg.sender, address(this), token, amount);
        }
    }

    function safeTransfer(
        address payable receiver,
        address token,
        uint256 amount
    ) internal {
        if (token == address(0)) {
            receiver.transfer(amount);
        } else {
            IERC20 oToken = IERC20(token);
            oToken.safeTransferFrom(address(this), receiver, amount);
        }
        emit SafeTransferFrom(address(this), receiver, token, amount);
    }
}
