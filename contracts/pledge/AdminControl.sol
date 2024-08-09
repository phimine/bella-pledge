// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../multisignature/MultiSignatureClient.sol";
import "../token/DebtToken.sol";
import "../library/UniswapUtil.sol";
import "../oracle/PledgeOracle.sol";
import "./structs/PoolBaseInfo.sol";
import "./structs/PoolDataInfo.sol";
import "./SafeTransfer.sol";

contract AdminControl is PausableUpgradeable, MultiSignatureClient {
    using UniswapUtil for IUniswapV2Router02;
    using SafeTransfer for address;
    // Constants
    PoolState internal constant INITIAL_POOL_STATE = PoolState.MATCH;
    uint256 internal constant CAL_DECIMAL = 10 ** 18;
    uint256 internal constant BASE_DECIMAL = 10 ** 8;
    uint256 internal constant DEFAULT_MIN_DEPOSIT = 100 * 10 ** 18;
    uint256 internal constant BASE_YEAR = 365 days;

    // State Variables
    uint256 internal minDeposit;
    uint256 internal lendFee;
    uint256 internal borrowFee;
    address internal feeAddress;

    PoolBaseInfo[] internal poolBaseInfos;
    PoolDataInfo[] internal poolDataInfos;

    PledgeOracle internal oracle;
    IUniswapV2Router02 internal uniswap;

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
    event PoolStateChange(uint256 poolId, uint256 oldState, uint256 newState);

    // Modifiers
    modifier validPoolId(uint256 poolId) {
        require(poolBaseInfos.length > poolId, "PledgePool: invalid pool id");
        _;
    }

    modifier timeBefore(uint256 poolId) {
        require(
            block.timestamp < poolBaseInfos[poolId].settleTime,
            "PledgePool: greater than settle time"
        );
        _;
    }

    modifier timeAfter(uint256 poolId) {
        require(
            block.timestamp > poolBaseInfos[poolId].settleTime,
            "PledgePool: less than settle time"
        );
        _;
    }

    modifier timeAfterEnd(uint256 poolId) {
        require(
            block.timestamp > poolBaseInfos[poolId].endTime,
            "PledgePool: less than end time"
        );
        _;
    }

    modifier stateMatch(uint256 poolId) {
        require(
            poolBaseInfos[poolId].status == PoolState.MATCH,
            "PledgePool: not match pool state"
        );
        _;
    }

    modifier stateUndone(uint256 poolId) {
        require(
            poolBaseInfos[poolId].status == PoolState.UNDONE,
            "PledgePool: not undone pool state"
        );
        _;
    }

    modifier stateExecution(uint256 poolId) {
        require(
            poolBaseInfos[poolId].status == PoolState.EXECUTION,
            "PledgePool: not execution pool state"
        );
        _;
    }

    modifier stateNotMatchOrUndone(uint256 poolId) {
        require(
            poolBaseInfos[poolId].status != PoolState.UNDONE &&
                poolBaseInfos[poolId].status != PoolState.MATCH,
            "PledgePool: not undone pool state"
        );
        _;
    }

    modifier stateFinishOrLiquidation(uint256 poolId) {
        require(
            poolBaseInfos[poolId].status != PoolState.FINISH &&
                poolBaseInfos[poolId].status != PoolState.LIQUIDATION,
            "PledgePool: not undone pool state"
        );
        _;
    }

    function __AdminControl_init(
        address multiSignature
    ) internal onlyInitializing {
        __MultiSignatureClient_init(multiSignature);
        __Pausable_init();
    }

    ////// OWNER FUNCTIONS
    function setMinDeposit(uint256 _minAmount) external validCall {
        require(_minAmount > 0, "PledgePool: _minAmount is 0");
        uint256 old = minDeposit;
        minDeposit = _minAmount;
        emit SetMinDeposit(msg.sender, old, minDeposit);
    }

    function setLendFee(uint256 _lendFee) external validCall {
        require(_lendFee > 0, "PledgePool: _lendFee is 0");
        uint256 old = lendFee;
        lendFee = _lendFee;
        emit SetLendFee(msg.sender, old, lendFee);
    }

    function setBorrowFee(uint256 _borrowFee) external validCall {
        require(_borrowFee > 0, "PledgePool: _borrowFee is 0");
        uint256 old = borrowFee;
        borrowFee = _borrowFee;
        emit SetBorrowFee(msg.sender, old, borrowFee);
    }

    function setSwapRouter(address _swapRouter) external validCall {
        require(_swapRouter != address(0), "PledgePool: _swapRouter is 0x");
        address old = address(uniswap);
        uniswap = IUniswapV2Router02(_swapRouter);
        emit SetSwapRouter(msg.sender, old, address(uniswap));
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
        require(
            _lendToken != address(0),
            "PledgePool.createPool: _lendToken is 0x"
        );
        require(
            _borrowToken != address(0),
            "PledgePool.createPool: _borrowToken is 0x"
        );
        require(
            _spToken != address(0),
            "PledgePool.createPool: _spToken is 0x"
        );
        require(
            _jpToken != address(0),
            "PledgePool.createPool: _jpToken is 0x"
        );
        require(
            _mortgageRate > 0,
            "PledgePool.createPool: _mortgageRate is le 0"
        );
        require(
            _interestRate > 0,
            "PledgePool.createPool: _interestRate is le 0"
        );
        require(
            _autoLiquidateThreshold > 0,
            "PledgePool.createPool: _autoLiquidateThreshold is le 0"
        );

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

    function settle(
        uint256 poolId
    )
        external
        validCall
        validPoolId(poolId)
        timeAfter(poolId)
        stateMatch(poolId)
    {
        // Check: 调用者权限、poolId存在、时间在结算之后、状态MATCH
        // Effect: settleAmountBorrow、settleAmountLend、pool更新状态
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        uint256 _borrowSupply = baseInfo.borrowSupply;
        uint256 _lendSupply = baseInfo.lendSupply;
        if (_lendSupply > 0 && _borrowSupply > 0) {
            baseInfo.status = PoolState.EXECUTION;

            (uint256 lendPrice, uint256 borrowPrice) = getLendBorrowPrices(
                poolId
            );
            uint256 _mortgageRate = baseInfo.mortgageRate;
            uint256 totalBorrowValue = _borrowSupply *
                borrowPrice *
                CAL_DECIMAL;
            uint256 equivalentLendAmount = totalBorrowValue /
                lendPrice /
                CAL_DECIMAL;
            uint256 actualLendAmount = (equivalentLendAmount * BASE_DECIMAL) /
                _mortgageRate;
            if (_lendSupply > actualLendAmount) {
                dataInfo.settleAmountLend = actualLendAmount;
                dataInfo.settleAmountBorrow = _borrowSupply;
            } else {
                dataInfo.settleAmountLend = _lendSupply;
                // settleAmountBorrow = _lendSupply * _mortgageRate * lendPrice / borrowSupply
                uint256 totalLendValue = _lendSupply * lendPrice * CAL_DECIMAL;
                uint256 equivalentBorrowAmount = totalLendValue /
                    borrowPrice /
                    CAL_DECIMAL;
                dataInfo.settleAmountBorrow =
                    (equivalentBorrowAmount * _mortgageRate) /
                    BASE_DECIMAL;
            }
            emit PoolStateChange(
                poolId,
                uint256(PoolState.MATCH),
                uint256(PoolState.EXECUTION)
            );
        } else {
            baseInfo.status = PoolState.UNDONE;
            dataInfo.settleAmountBorrow = _borrowSupply;
            dataInfo.settleAmountLend = _lendSupply;
            emit PoolStateChange(
                poolId,
                uint256(PoolState.MATCH),
                uint256(PoolState.UNDONE)
            );
        }
        // Interactions
    }

    function finish(
        uint256 poolId
    )
        external
        validCall
        validPoolId(poolId)
        timeAfterEnd(poolId)
        stateExecution(poolId)
    {
        // Check: 调用者权限、poolId存在、状态Execution、时间在结束之后
        // Effect: pool.state=FINISH、计算dataInfo.finishAmountBorrow、dataInfo.finishAmountLend
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        PoolDataInfo storage dataInfo = poolDataInfos[poolId];
        baseInfo.status = PoolState.FINISH;
        // 1. 计算需要购买的lendToken总量：settleAmountLend -> interest -> lendAmount + lendFee -> buyAmount
        // interest = periods / year * interestRate * settleAmountLend
        uint256 _settleAmountLend = dataInfo.settleAmountLend;
        uint256 _interestRate = baseInfo.interestRate;
        uint256 timeRatio = ((block.timestamp - baseInfo.settleTime) *
            BASE_DECIMAL) / BASE_YEAR;
        uint256 interest = (timeRatio * _interestRate * _settleAmountLend) /
            BASE_DECIMAL /
            BASE_DECIMAL;
        uint256 totalLendAmount = _settleAmountLend + interest;
        // buyAmount = totalLendAmount * (1 + lendFee)
        uint256 buyAmount = (totalLendAmount * (BASE_DECIMAL + lendFee)) /
            BASE_DECIMAL;

        // // 2. 通过swapRouter用borrowToken换lendToken
        (address sellToken, address buyToken) = (
            baseInfo.borrowToken,
            baseInfo.lendToken
        );
        uint256 swapAmountIn = uniswap.getSwapAmountIn(
            sellToken,
            buyToken,
            buyAmount
        );
        (uint256 swapBorrowAmount, uint256 swapLendAmount) = uniswap.swap(
            sellToken,
            buyToken,
            swapAmountIn,
            address(this)
        );

        // 计算质押手续费
        require(swapLendAmount >= totalLendAmount);
        // 计算手续费
        uint256 actualLendFee = swapLendAmount - totalLendAmount;
        dataInfo.finishAmountLend = totalLendAmount;

        // 计算借贷手续费
        uint256 _settleAmountBorrow = dataInfo.settleAmountBorrow;
        uint256 restAmountBorrow = _settleAmountBorrow - swapAmountIn;
        uint256 actualBorrowFee = (restAmountBorrow * borrowFee) / BASE_DECIMAL;
        dataInfo.finishAmountBorrow = restAmountBorrow - actualBorrowFee;

        // Interactions: 手续费转账
        buyToken.safeTransferTo(address(this), feeAddress, actualLendFee);
        sellToken.safeTransferTo(address(this), feeAddress, actualBorrowFee);

        emit PoolStateChange(
            poolId,
            uint256(PoolState.EXECUTION),
            uint256(PoolState.FINISH)
        );
    }

    //// internals
    /**
     * 通过预言机获取lendToken和borrowToken的价格
     * @param poolId pool index
     */
    function getLendBorrowPrices(
        uint256 poolId
    ) internal view returns (uint256 lendPrice, uint256 borrowPrice) {
        PoolBaseInfo storage baseInfo = poolBaseInfos[poolId];
        address[] memory tokens = new address[](2);
        tokens[0] = baseInfo.lendToken;
        tokens[1] = baseInfo.borrowToken;

        uint256[] memory prices = oracle.getPrices(tokens);
        lendPrice = prices[0];
        borrowPrice = prices[1];
    }
}
