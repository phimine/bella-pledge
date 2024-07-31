// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct LendInfo {
    uint256 stakeAmount;
    uint256 refundAmount;
    bool refunded; // false - not refund; true - refunded
    bool claimed; // false - not claim; true - claimed
}
