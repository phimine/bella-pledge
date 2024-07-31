// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../multisignature/MultiSignatureClient.sol";
import "../token/DebtToken.sol";
import "../oracle/PledgeOracle.sol";
import "./SafeTransfer.sol";

/**
 * @title 借贷池主合约
 * @author Carl Fu
 * @notice
 */
contract PledgePool is
    ReentrancyGuard,
    SafeTransfer,
    MultiSignatureClient,
    PausableUpgradeable
{
    // Type Declarations
    enum PoolState {
        MATCH, // 借贷池开始募捐
        EXECUTION, // 借贷协议结算已开始
        FINISH, // 借贷协议结算已结束
        LIQUIDATION, // 借贷协议已清算
        UNDONE // 借贷协议取消
    }

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

    struct PoolDataInfo {
        uint256 settleAmountLend; // 借贷结算总量
        uint256 settleAmountBorrow; // 抵押结算总量
        uint256 finishAmountLend;
        uint256 finishAmountBorrow;
        uint256 liquidateAmountLend;
        uint256 liquidateAmountBorrow;
    }

    struct BorrowInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool refunded; // false - not refund; true - refunded
        bool claimed; // false - not claim; true - claimed
    }

    struct LendInfo {
        uint256 stakeAmount;
        uint256 refundAmount;
        bool refunded; // false - not refund; true - refunded
        bool claimed; // false - not claim; true - claimed
    }

    // State Variables
    //// constants
    uint256 internal constant CAL_DECIMAL = 10 ** 18;
    uint256 internal constant BASE_DECIMAL = 10 ** 8;
    uint256 internal constant DEFAULT_MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 internal constant BASE_YEAR = 365 days;
    PoolState internal constant INITIAL_POOL_STATE = PoolState.MATCH;
    uint256 private minDeposit;
    uint256 private lendFee;
    uint256 private borrowFee;
    address private feeAddress;
    address private swapRouter;

    PoolBaseInfo[] private poolBaseInfos;
    PoolDataInfo[] private poolDataInfos;

    PledgeOracle private oracle;

    // pool id => user address => borrow/lend info
    mapping(uint256 => mapping(address => BorrowInfo)) private userBorrowList;
    mapping(uint256 => mapping(address => LendInfo)) private userLendList;

    // Events
    event SetMinDeposit(
        address indexed sender,
        uint256 oldValue,
        uint256 newValue
    );
    event SetLendFee(
        address indexed sender,
        uint256 oldValue,
        uint256 newValue
    );
    event SetBorrowFee(
        address indexed sender,
        uint256 oldValue,
        uint256 newValue
    );
    event SetSwapRouter(
        address indexed sender,
        address oldAddress,
        address newAddress
    );
    event SetFeeAddress(
        address indexed sender,
        address oldAddress,
        address newAddress
    );
    event CreatePool(
        uint256 settleTime,
        uint256 endTime,
        uint256 maxSupply,
        address lendToken,
        address borrowToken,
        uint256 mortgageRate,
        uint256 interestRate,
        address spToken,
        address jpToken,
        uint256 autoLiquidateThreshold
    );

    // Modifiers
    // Constructor
    function initialize(
        address _feeAddress,
        address _swapRouter,
        address _oracle,
        address multiSignature
    ) public initializer {
        __MultiSignatureClient_init(multiSignature);
        __Pausable_init();
        _setup(_feeAddress, _swapRouter, _oracle);
    }

    // Functions
    //// receive/fallbacl
    //// external
    ////// OWNER FUNCTIONS
    function setMinDeposit(uint256 _minAmount) external validCall {
        require(_minAmount >= 0, "PledgePool: _minAmount is 0");
        uint256 old = minDeposit;
        minDeposit = _minAmount;
        emit SetMinDeposit(msg.sender, old, minDeposit);
    }

    function setLendFee(uint256 _lendFee) external validCall {
        require(_lendFee >= 0, "PledgePool: _lendFee is 0");
        uint256 old = lendFee;
        lendFee = _lendFee;
        emit SetLendFee(msg.sender, old, lendFee);
    }

    function setBorrowFee(uint256 _borrowFee) external validCall {
        require(_borrowFee >= 0, "PledgePool: _borrowFee is 0");
        uint256 old = borrowFee;
        borrowFee = _borrowFee;
        emit SetBorrowFee(msg.sender, old, borrowFee);
    }

    function setSwapRouter(address _swapRouter) external validCall {
        require(_swapRouter != address(0), "PledgePool: _swapRouter is 0x");
        address old = swapRouter;
        swapRouter = _swapRouter;
        emit SetSwapRouter(msg.sender, old, swapRouter);
    }

    function setFeeAddress(address _feeAddress) external validCall {
        require(_feeAddress != address(0), "PledgePool: _feeAddress is 0x");
        address old = feeAddress;
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, old, feeAddress);
    }

    function pause() external validCall {
        _pause();
    }

    function unpause() external validCall {
        _unpause();
    }

    function createPool(
        uint256 _settleTime,
        uint256 _endTime,
        uint256 _maxSupply,
        address _lendToken,
        address _borrowToken,
        uint256 _mortgageRate,
        uint256 _interestRate,
        address _spToken,
        address _jpToken,
        uint256 _autoLiquidateThreshold
    ) external validCall {
        // Check
        require(
            _endTime > _settleTime,
            "PledgePool.createPool: end time is less than settle time"
        );
        require(
            _maxSupply > 0,
            "PledgePool.createPool: max supply is less than 0"
        );
        require(_lendToken != address(0), "");
        require(_borrowToken != address(0), "");
        require(_spToken != address(0), "");
        require(_jpToken != address(0), "");
        require(_mortgageRate > 0, "");
        require(_interestRate > 0, "");
        require(_autoLiquidateThreshold > 0, "");

        // Effect
        poolBaseInfos.push(
            PoolBaseInfo({
                settleTime: _settleTime,
                endTime: _endTime,
                maxSupply: _maxSupply,
                lendSupply: 0,
                borrowSupply: 0,
                lendToken: _lendToken,
                borrowToken: _borrowToken,
                mortgageRate: _mortgageRate,
                interestRate: _interestRate,
                spToken: DebtToken(_spToken),
                jpToken: DebtToken(_jpToken),
                autoLiquidateThreshold: _autoLiquidateThreshold,
                status: INITIAL_POOL_STATE
            })
        );
        poolDataInfos.push(
            PoolDataInfo({
                settleAmountLend: 0,
                settleAmountBorrow: 0,
                finishAmountLend: 0,
                finishAmountBorrow: 0,
                liquidateAmountLend: 0,
                liquidateAmountBorrow: 0
            })
        );

        // Interactions
        emit CreatePool(
            _settleTime,
            _endTime,
            _maxSupply,
            _lendToken,
            _borrowToken,
            _mortgageRate,
            _interestRate,
            _spToken,
            _jpToken,
            _autoLiquidateThreshold
        );
    }

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
