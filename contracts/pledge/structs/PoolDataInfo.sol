// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct PoolDataInfo {
    uint256 settleAmountLend; // 借贷结算总量
    uint256 settleAmountBorrow; // 抵押结算总量
    uint256 finishAmountLend;
    uint256 finishAmountBorrow;
    uint256 liquidateAmountLend;
    uint256 liquidateAmountBorrow;
}
