// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../multisignature/MultiSignatureClient.sol";
import "../token/DebtToken.sol";
import "../oracle/PledgeOracle.sol";
import "./SafeTransfer.sol";
import "./AdminControl.sol";
import "./structs/BorrowInfo.sol";
import "./structs/LendInfo.sol";
import "./structs/PoolBaseInfo.sol";
import "./structs/PoolDataInfo.sol";
import "./structs/PoolState.sol";

/**
 * @title 借贷池主合约
 * @author Carl Fu
 * @notice
 */
contract PledgePool is SafeTransfer, AdminControl, ReentrancyGuard {
    // Type Declarations

    // State Variables
    //// constants
    uint256 internal constant CAL_DECIMAL = 10 ** 18;
    uint256 internal constant BASE_DECIMAL = 10 ** 8;
    uint256 internal constant DEFAULT_MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 internal constant BASE_YEAR = 365 days;

    // pool id => user address => borrow/lend info
    mapping(uint256 => mapping(address => BorrowInfo)) private userBorrowList;
    mapping(uint256 => mapping(address => LendInfo)) private userLendList;

    // Events

    // Modifiers
    // Constructor
    function initialize(
        address _feeAddress,
        address _swapRouter,
        address _oracle,
        address multiSignature
    ) public initializer {
        __AdminControl_init(multiSignature);

        _setup(_feeAddress, _swapRouter, _oracle);
    }

    // Functions
    //// receive/fallback
    //// external
    ////// OWNER FUNCTIONS

    ////// LENDER FUNCTIONS
    ////// BORROWER FUNCTIONS

    //// internal
    function _setup(
        address _feeAddress,
        address _swapRouter,
        address _oracle
    ) internal {
        oracle = PledgeOracle(_oracle);
        feeAddress = _feeAddress;
        swapRouter = _swapRouter;
        minDeposit = DEFAULT_MIN_DEPOSIT;
    }

    //// view/pure
    function getFeeAddress() public view returns (address) {
        return feeAddress;
    }

    function getSwapRouter() public view returns (address) {
        return swapRouter;
    }

    function getOracle() public view returns (address) {
        return address(oracle);
    }

    function getMinDeposit() public view returns (uint256) {
        return minDeposit;
    }

    function getLendFee() public view returns (uint256) {
        return lendFee;
    }

    function getBorrowFee() public view returns (uint256) {
        return borrowFee;
    }

    function getPoolLength() public view returns (uint256) {
        return poolBaseInfos.length;
    }
}
