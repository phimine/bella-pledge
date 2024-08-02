// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MockV3Aggregator.sol";

contract MockLendAggregator is MockV3Aggregator {
    constructor(
        uint8 decimals,
        int256 initialAnswer
    ) MockV3Aggregator(decimals, initialAnswer) {}

    function setDecimals(uint8 _decimals) external {
        decimals_ = _decimals;
    }
}
