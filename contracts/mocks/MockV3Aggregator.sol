// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";

/**
 * @title MockV3Aggregator
 * @notice Based on the FluxAggregator contract
 * @notice Use this contract when you need to test
 * other contract's ability to read data from an
 * aggregator contract, but how the aggregator got
 * its answer is unimportant
 */
contract MockV3Aggregator is AggregatorV2V3Interface {
    uint8 public decimals_;
    int256 public latestAnswer_;
    uint256 public latestTimestamp_;
    uint256 public latestRound_;

    mapping(uint256 => int256) public getAnswer_;
    mapping(uint256 => uint256) public getTimestamp_;
    mapping(uint256 => uint256) private getStartedAt_;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals_ = _decimals;
        updateAnswer(_initialAnswer);
    }

    function latestRound() external view override returns (uint256) {
        return latestRound_;
    }

    function latestTimestamp() external view override returns (uint256) {
        return latestTimestamp_;
    }

    function latestAnswer() external view override returns (int256) {
        return latestAnswer_;
    }

    function getStartedAt(uint256 roundId) external view returns (uint256) {
        return getStartedAt_[roundId];
    }

    function getTimestamp(
        uint256 roundId
    ) external view override returns (uint256) {
        return getTimestamp_[roundId];
    }

    function getAnswer(
        uint256 roundId
    ) external view override returns (int256) {
        return getAnswer_[roundId];
    }

    function decimals() external view override returns (uint8) {
        return decimals_;
    }

    function version() external pure override returns (uint256) {
        return 0;
    }

    function updateAnswer(int256 _answer) public {
        latestAnswer_ = _answer;
        latestTimestamp_ = block.timestamp;
        latestRound_++;
        getAnswer_[latestRound_] = _answer;
        getTimestamp_[latestRound_] = block.timestamp;
        getStartedAt_[latestRound_] = block.timestamp;
    }

    function updateRoundData(
        uint80 _roundId,
        int256 _answer,
        uint256 _timestamp,
        uint256 _startedAt
    ) public {
        latestRound_ = _roundId;
        latestAnswer_ = _answer;
        latestTimestamp_ = _timestamp;
        getAnswer_[latestRound_] = _answer;
        getTimestamp_[latestRound_] = _timestamp;
        getStartedAt_[latestRound_] = _startedAt;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            _roundId,
            getAnswer_[_roundId],
            getStartedAt_[_roundId],
            getTimestamp_[_roundId],
            _roundId
        );
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            uint80(latestRound_),
            getAnswer_[latestRound_],
            getStartedAt_[latestRound_],
            getTimestamp_[latestRound_],
            uint80(latestRound_)
        );
    }

    function description() external pure override returns (string memory) {
        return "v0.8/tests/MockV3Aggregator.sol";
    }
}
