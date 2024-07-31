// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "../multisignature/MultiSignatureClient.sol";
import "../library/PriceAggregator.sol";
import "../library/PledgeAggregator.sol";

contract PledgeOracle is MultiSignatureClient {
    // Type Declarations
    using PriceAggregator for PledgeAggregator;

    // State Variables
    mapping(address => PledgeAggregator) internal tokenPriceAggregators;

    // Constructor
    function initialize(address multiSignature) public initializer {
        __MultiSignatureClient_init(multiSignature);
    }

    // Functions
    function addTokenAggregator(
        address token,
        address _aggregator,
        uint256 _decimals
    ) external validCall {
        tokenPriceAggregators[token] = PledgeAggregator({
            aggregator: AggregatorV3Interface(_aggregator),
            decimals: _decimals
        });
    }

    function getTokenAggregator(
        address token
    ) external view returns (address, uint256) {
        PledgeAggregator memory plgdgeAggregator = tokenPriceAggregators[token];
        return (
            address(plgdgeAggregator.aggregator),
            plgdgeAggregator.decimals
        );
    }

    function getPrice(address token) public view returns (uint256) {
        return tokenPriceAggregators[token].getPrice();
    }
}
