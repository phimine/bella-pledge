// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./PledgeAggregator.sol";

library PriceAggregator {
    uint256 internal constant DEFAULT_DECIMAL = 18;

    function getPrice(
        PledgeAggregator memory aggregator
    ) internal view returns (uint256) {
        (, int price, , , ) = aggregator.aggregator.latestRoundData();
        uint256 decimals = aggregator.decimals;

        if (decimals < DEFAULT_DECIMAL) {
            return
                (uint256(price) * (10 ** (DEFAULT_DECIMAL - decimals))) /
                (10 ** DEFAULT_DECIMAL);
        } else if (decimals > DEFAULT_DECIMAL) {
            return
                uint256(price) /
                (10 ** (decimals - DEFAULT_DECIMAL)) /
                (10 ** DEFAULT_DECIMAL);
        } else {
            return uint256(price) / (10 ** DEFAULT_DECIMAL);
        }
    }
}
