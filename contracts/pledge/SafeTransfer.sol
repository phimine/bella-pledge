// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library SafeTransfer {
    using SafeERC20 for IERC20;

    event SafeTransferFrom(
        address indexed from,
        address indexed to,
        address indexed token,
        uint256 amount
    );

    function safeTransferTo(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            if (token == address(0)) {
                payable(to).transfer(amount);
            } else {
                IERC20 oToken = IERC20(token);
                oToken.safeTransferFrom(from, to, amount);
                emit SafeTransferFrom(from, to, token, amount);
            }
        }
    }
}
