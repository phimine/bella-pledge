// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

struct PledgeAggregator {
    AggregatorV3Interface aggregator;
    uint256 decimals;
}
