// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

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
contract PledgePool is AdminControl, ReentrancyGuardUpgradeable {
    // Type Declarations
    using SafeTransfer for address;

    // State Variables

    // pool id => user address => borrow/lend info
    mapping(uint256 => mapping(address => BorrowInfo)) private userBorrowList;
    mapping(uint256 => mapping(address => LendInfo)) private userLendList;

    // Events
    event DepositLend(address from, address token, uint256 amount);
    event RefundLend(address receiver, address token, uint256 refundAmount);
    event ClaimLend(address receiver, address token, uint256 claimAmount);
    event WithdrawLend(address receiver, address spToken, uint256 spAmount);
    event EmergencyLendWithdrawal(
        address receiver,
        address lendToken,
        uint256 withdrawAmount
    );

    event DepositBorrow(address borrower, address borrowToken, uint256 amount);
    event RefundBorrow(address borrower, address borrowToken, uint256 amount);
    event ClaimBorrow(address borrower, address jpToken, uint256 claimAmount);
    event WithdrawBorrow(address borrower, address jpToken, uint256 jpAmount);
    event EmergencyBorrowWithdrawal(
        address borrower,
        address borrowToken,
        uint256 amount
    );

    // Modifiers

    modifier validAmount(uint256 amount) {
        require(amount > 0);
        _;
    }

    // Constructor
    function initialize(
        address _feeAddress,
        address _swapRouter,
        address _oracle,
        address multiSignature
    ) public initializer {
        __AdminControl_init(multiSignature);
        __ReentrancyGuard_init();

        _setup(_feeAddress, _swapRouter, _oracle);
    }

    // Functions
    //// receive/fallback
    //// external
    ////// OWNER FUNCTIONS

    ////// LENDER FUNCTIONS
    /**
     * deposit action of depositor
     * @param poolId 借贷池ID
     * @param amount 质押金额
     */
    function depositLend(
        uint256 poolId,
        uint256 amount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeBefore(poolId)
        stateMatch(poolId)
        validAmount(amount)
    {
        // Check: poolId存在、结算之前、借贷池处于MATCH状态、amount大于minDeposit、amount小于总供应量-当前供应量
        PoolBaseInfo storage poolBaseInfo = poolBaseInfos[poolId];
        address _lendToken = poolBaseInfo.lendToken;
        uint256 depositAmount;
        if (_lendToken == address(0)) {
            depositAmount = msg.value;
        } else {
            depositAmount = amount;
        }
        require(depositAmount > minDeposit);
        require(
            depositAmount <= poolBaseInfo.maxSupply - poolBaseInfo.lendSupply
        );

        // Effect: 借贷池lendSupply增加、新增用户借贷信息
        poolBaseInfo.lendSupply += depositAmount;
        userLendList[poolId][msg.sender].stakeAmount += depositAmount;

        // Interactions
        emit DepositLend(msg.sender, _lendToken, depositAmount);
    }

    /**
     * refund excees deposit amount to depositor
     * @param poolId 借贷池ID
     */
    function refundLend(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateUndone(poolId)
    {
        // Check: poolId存在、借贷池处于UNDONE状态、用户质押过、没重复refund、时间在结算之后、借贷池lendSupply量大于refund量
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        LendInfo storage lendInfo = userLendList[poolId][msg.sender];
        uint256 _stakeAmount = lendInfo.stakeAmount;
        uint256 _lendSupply = baseInfo.lendSupply;
        uint256 _settleAmountLend = dataInfo.settleAmountLend;
        require(_stakeAmount > 0);
        require(!lendInfo.refunded);
        require(_lendSupply > _settleAmountLend);

        // Effect: lendInfo更改成已退款、计算退款金额 = stakeAmount / lendSupply * (lendSupply - settleAmountLend) 、lendInfo更新退款金额
        uint256 totalRefund = _lendSupply - _settleAmountLend;
        uint256 userShare = (_stakeAmount * CAL_DECIMAL) / _lendSupply;
        uint256 refundAmount = (userShare * totalRefund) / CAL_DECIMAL;

        lendInfo.refunded = true;
        lendInfo.refundAmount = refundAmount;

        // Interactions: 退还资产
        baseInfo.lendToken.safeTransferTo(
            address(this),
            msg.sender,
            refundAmount
        );
        emit RefundLend(msg.sender, baseInfo.lendToken, refundAmount);
    }

    /**
     * depositor receive sp token
     * @param poolId 借贷池ID
     */
    function claimLend(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateNotMatchOrUndone(poolId)
    {
        // Check: 借贷池Id存在、时间在结算之后、借贷池状态不是MATCH或UNDONE、用户有质押、用户没claim过
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        LendInfo storage lendInfo = userLendList[poolId][msg.sender];
        uint256 _stakeAmount = lendInfo.stakeAmount;
        uint256 _settleAmountLend = dataInfo.settleAmountLend;
        uint256 _lendSupply = baseInfo.lendSupply;
        require(_stakeAmount > 0);
        require(!lendInfo.claimed);

        // Effect: claimed=true、计算claim金额
        uint256 userShare = (_stakeAmount * CAL_DECIMAL) / _lendSupply;
        uint256 claimAmount = (userShare * _settleAmountLend) / CAL_DECIMAL;
        lendInfo.claimed = true;

        // Interactions: mint spToken
        DebtToken _spToken = baseInfo.spToken;
        _spToken.mint(msg.sender, claimAmount);
        emit ClaimLend(msg.sender, address(_spToken), claimAmount);
    }

    /**
     * Depositors withdraw the principal and interest
     * @param poolId 借贷池ID
     * @param spAmount sp token数量
     */
    function withdrawLend(
        uint256 poolId,
        uint256 spAmount
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        stateFinishOrLiquidation(poolId)
        validAmount(spAmount)
    {
        // Check: 借贷池ID存在、状态在FINISH或LIQUIDATION、时间是否和状态匹配、spAmount大于0
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        uint256 _settleAmountLend = dataInfo.settleAmountLend;

        // Effect: 计算withdrawAmount = spAmount / _settleAmountLend * totalAmountLend
        uint256 totalAmountLend;
        if (baseInfo.status == PoolState.FINISH) {
            require(block.timestamp > baseInfo.endTime);
            totalAmountLend = dataInfo.finishAmountLend;
        } else {
            require(block.timestamp > baseInfo.settleTime);
            totalAmountLend = dataInfo.liquidateAmountLend;
        }
        uint256 userShare = (spAmount * CAL_DECIMAL) / _settleAmountLend;
        uint256 withdrawAmount = (userShare * totalAmountLend) / CAL_DECIMAL;

        // Interactions: burn spToken、转账lendToken到depositor账户
        DebtToken _spToken = baseInfo.spToken;
        _spToken.burn(msg.sender, spAmount);
        baseInfo.lendToken.safeTransferTo(
            address(this),
            msg.sender,
            withdrawAmount
        );

        emit WithdrawLend(msg.sender, address(_spToken), spAmount);
    }

    /**
     * Emergency withdrawal of Lend
     * @param poolId 借贷池ID
     */
    function emergencyLendWithdrawal(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateUndone(poolId)
    {
        // Check: poolId存在，pool状态UNDONE、时间在结算之后、重复refund、有stakeAmount
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        LendInfo storage lendInfo = userLendList[poolId][msg.sender];
        require(baseInfo.lendSupply > 0);
        require(lendInfo.stakeAmount > 0);
        require(!lendInfo.refunded);

        // Effect: refunded=true、计算withdrawAmount
        uint256 withdrawAmount = lendInfo.stakeAmount;
        lendInfo.refunded = true;
        lendInfo.refundAmount = withdrawAmount;

        // Interactions: 转账
        baseInfo.lendToken.safeTransferTo(
            address(this),
            msg.sender,
            withdrawAmount
        );
        emit EmergencyLendWithdrawal(
            msg.sender,
            baseInfo.lendToken,
            withdrawAmount
        );
    }

    ////// BORROWER FUNCTIONS
    /**
     * Borrower pledge operation
     * @param poolId 借贷池ID
     * @param amount 抵押金额
     */
    function depositBorrow(
        uint256 poolId,
        uint256 amount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeBefore(poolId)
        stateMatch(poolId)
    {
        // Check: poolId存在、状态MATCH、时间结算之前、amount大于最小抵押、amount小于总量-已抵押数量
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        uint256 _maxSupply = baseInfo.maxSupply;
        uint256 _borrowSupply = baseInfo.borrowSupply;
        address _borrowToken = baseInfo.borrowToken;
        uint256 depositAmount;
        if (_borrowToken == address(0)) {
            depositAmount = msg.value;
        } else {
            depositAmount = amount;
        }

        require(depositAmount <= _maxSupply - _borrowSupply);
        require(depositAmount >= minDeposit);
        // Effect: pool.borrowSupply增加、用户抵押量增加
        baseInfo.borrowSupply += depositAmount;
        userBorrowList[poolId][msg.sender].stakeAmount += depositAmount;

        // Interactions: 转账到合约
        _borrowToken.safeTransferTo(msg.sender, address(this), depositAmount);
        emit DepositBorrow(msg.sender, _borrowToken, depositAmount);
    }

    /**
     * Refund excess deposit to borrower
     * @param poolId pool index
     */
    function refundBorrow(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateNotMatchOrUndone(poolId)
    {
        // Check: poolId存在、状态不是MATCH或UNDOEN、时间在结算之后、抵押amount大于0、未refund过
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        BorrowInfo storage borrowInfo = userBorrowList[poolId][msg.sender];
        uint256 _stakeAmount = borrowInfo.stakeAmount;
        require(_stakeAmount > 0);
        require(!borrowInfo.refunded);
        uint256 _borrowSupply = baseInfo.borrowSupply;
        uint256 _settleAmountBorrow = dataInfo.settleAmountBorrow;

        // Effect: refunded=true、计算refundAmount = _stakeAmount * (_borrowSupply - _settleAmountBorrow) / _borrowSupply
        borrowInfo.refunded = true;
        uint256 userShare = (_stakeAmount * CAL_DECIMAL) / _borrowSupply;
        uint256 totalRefund = _borrowSupply - _settleAmountBorrow;
        uint256 refundAmount = (userShare * totalRefund) / CAL_DECIMAL;
        borrowInfo.refundAmount = refundAmount;

        // Interactions: 转账到msg.sender
        baseInfo.borrowToken.safeTransferTo(
            address(this),
            msg.sender,
            refundAmount
        );
        emit RefundBorrow(msg.sender, baseInfo.borrowToken, refundAmount);
    }

    /**
     * Borrower receives jp_token and loan funds
     * @param poolId pool index
     */
    function claimBorrow(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateNotMatchOrUndone(poolId)
    {
        // Check: poolId存在、时间在结算之后、状态不是MATCH或UNDONE、未claim过、stakeAmount大于0
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        BorrowInfo storage borrowInfo = userBorrowList[poolId][msg.sender];
        uint256 _stakeAmount = borrowInfo.stakeAmount;
        require(!borrowInfo.claimed);
        require(_stakeAmount > 0);
        uint256 _settleAmountLend = dataInfo.settleAmountLend;
        uint256 _borrowSupply = baseInfo.borrowSupply;
        uint256 _mortgageRate = baseInfo.mortgageRate;

        // Effect: claimed=true、计算claimAmount = _stakeAmount * (settleAmountLend * mortgateRate) / borrowSupply
        borrowInfo.claimed = true;
        uint256 userShare = (_stakeAmount * CAL_DECIMAL) / _borrowSupply;
        uint256 totalJpAmount = _settleAmountLend * _mortgageRate;
        uint256 claimAmount = (userShare * totalJpAmount) / CAL_DECIMAL;
        uint256 borrowAmount = (userShare * _settleAmountLend) / CAL_DECIMAL;

        // Interactions: mint jp token、向msg.sender转账借款
        DebtToken _jpToken = baseInfo.jpToken;
        _jpToken.mint(msg.sender, claimAmount);
        baseInfo.lendToken.safeTransferTo(
            address(this),
            msg.sender,
            borrowAmount
        );
        emit ClaimBorrow(msg.sender, address(_jpToken), claimAmount);
    }

    /**
     * borrower withdraw the remaining margin
     * @param poolId pool index
     * @param jpAmount jp token amount
     */
    function withdrawBorrow(
        uint256 poolId,
        uint256 jpAmount
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        stateFinishOrLiquidation(poolId)
        validAmount(jpAmount)
    {
        // Check: poolId存在、状态FINISH或LIQUIDATION、时间在结算/结束之后、jpAmount大于0
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        BorrowInfo storage borrowInfo = userBorrowList[poolId][msg.sender];
        uint256 _stakeAmount = borrowInfo.stakeAmount;
        uint256 _borrowSupply = baseInfo.borrowSupply;

        // Effect: 计算withdrawAmount = stakeAmount / borrowSupply * totalAmountBorrow
        uint256 totalAmountBorrow;
        if (baseInfo.status == PoolState.FINISH) {
            require(block.timestamp > baseInfo.endTime);
            totalAmountBorrow = dataInfo.finishAmountBorrow;
        } else {
            require(block.timestamp > baseInfo.settleTime);
            totalAmountBorrow = dataInfo.liquidateAmountBorrow;
        }
        uint256 userShare = (_stakeAmount * CAL_DECIMAL) / _borrowSupply;
        uint256 withdrawAmount = (userShare * totalAmountBorrow) / CAL_DECIMAL;

        // Interactions: burn jp token、转账到msg.sender
        DebtToken _jpToken = baseInfo.jpToken;
        _jpToken.burn(msg.sender, jpAmount);
        baseInfo.borrowToken.safeTransferTo(
            address(this),
            msg.sender,
            withdrawAmount
        );

        emit WithdrawBorrow(msg.sender, address(_jpToken), jpAmount);
    }

    /**
     * emergency withdraw margin
     * @notice in extreme cases, the deposit is 0 or the margin is 0, pool is in UNDONE state
     * @param poolId pool index
     */
    function emergencyBorrowWithdrawal(
        uint256 poolId
    )
        external
        nonReentrant
        whenNotPaused
        validPoolId(poolId)
        timeAfter(poolId)
        stateUndone(poolId)
    {
        // Check: poolId存在、状态UNDONE、时间在结算之后、stakeAmount>0, 未refund过
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        BorrowInfo storage borrowInfo = userBorrowList[poolId][msg.sender];
        uint256 _stakeAmount = borrowInfo.stakeAmount;
        require(_stakeAmount > 0);
        require(!borrowInfo.refunded);

        // Effect: refundAmount更新、refunded=true
        borrowInfo.refunded = true;
        borrowInfo.refundAmount = _stakeAmount;

        // Interactions: 转账msg.sender
        baseInfo.borrowToken.safeTransferTo(
            address(this),
            msg.sender,
            _stakeAmount
        );
        emit EmergencyBorrowWithdrawal(
            msg.sender,
            baseInfo.borrowToken,
            _stakeAmount
        );
    }

    //// internal
    function _setup(
        address _feeAddress,
        address _swapRouter,
        address _oracle
    ) internal {
        oracle = PledgeOracle(_oracle);
        uniswap = IUniswapV2Router02(_swapRouter);
        feeAddress = _feeAddress;
        minDeposit = DEFAULT_MIN_DEPOSIT;
    }

    //// view/pure
    function getPoolState(
        uint256 poolId
    ) public view validPoolId(poolId) returns (uint256) {
        return uint256(poolBaseInfos[poolId].status);
    }

    function getFeeAddress() public view returns (address) {
        return feeAddress;
    }

    function getSwapRouter() public view returns (address) {
        return address(uniswap);
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
