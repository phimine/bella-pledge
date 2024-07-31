// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PoolState.sol";
import "../../token/DebtToken.sol";

struct PoolBaseInfo {
    uint256 maxSupply; // 总供应量
    uint256 lendSupply; // 借贷供应量
    uint256 borrowSupply; // 抵押供应量
    uint256 settleTime; // 结算时间
    uint256 endTime; // 结束时间
    address lendToken; // 借贷资产
    address borrowToken; // 抵押资产
    uint256 mortgageRate; // 抵押率
    uint256 interestRate; // 利率
    PoolState status; // 借贷池状态
    DebtToken spToken; // 存款代币凭证
    DebtToken jpToken; // 债务代币凭证
    uint256 autoLiquidateThreshold; // 自动清算阈值
}
