// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

library UniswapUtil {
    event Swap(
        address inToken,
        uint256 swapAmountIn,
        address outToken,
        uint256 swapAmountOut
    );

    function getSwapAmountIn(
        IUniswapV2Router02 uniswap,
        address inToken,
        address outToken,
        uint256 swapAmountOut
    ) internal view returns (uint256) {
        if (swapAmountOut <= 0) {
            return 0;
        }
        address[] memory path = getSwapPairPath(uniswap, inToken, outToken);
        uint256[] memory amounts = uniswap.getAmountsIn(swapAmountOut, path);
        return amounts[0];
    }

    function getSwapPairPath(
        IUniswapV2Router02 uniswap,
        address inToken,
        address outToken
    ) internal pure returns (address[] memory paths) {
        paths = new address[](2);
        paths[0] = inToken == address(0) ? uniswap.WETH() : inToken;
        paths[1] = outToken == address(0) ? uniswap.WETH() : outToken;
    }

    function swap(
        IUniswapV2Router02 uniswap,
        address inToken,
        address outToken,
        uint256 swapAmountIn,
        address receiver
    ) internal returns (uint256, uint256) {
        if (inToken != address(0)) {
            _safeApprove(uniswap, inToken, type(uint256).max);
        }
        if (outToken != address(0)) {
            _safeApprove(uniswap, outToken, type(uint256).max);
        }

        address[] memory path = getSwapPairPath(uniswap, inToken, outToken);
        uint256[] memory amounts;
        uint256 cur = block.timestamp;
        if (inToken == address(0)) {
            // ETH换ERC20
            amounts = uniswap.swapExactETHForTokens{value: swapAmountIn}(
                0,
                path,
                receiver,
                cur + 30
            );
        } else if (outToken == address(0)) {
            // ERC20换ETH
            amounts = uniswap.swapExactTokensForETH(
                swapAmountIn,
                0,
                path,
                receiver,
                cur + 30
            );
        } else {
            // ERC20 换ERC20
            amounts = uniswap.swapExactTokensForTokens(
                swapAmountIn,
                0,
                path,
                receiver,
                cur + 30
            );
        }
        uint256 swapAmountOut = amounts[amounts.length - 1];
        emit Swap(inToken, swapAmountIn, outToken, swapAmountOut);
        return (swapAmountIn, swapAmountOut);
    }

    function _safeApprove(
        IUniswapV2Router02 uniswap,
        address token,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, address(uniswap), value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeApprove"
        );
    }
}
