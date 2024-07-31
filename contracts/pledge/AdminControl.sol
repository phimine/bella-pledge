// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import "../multisignature/MultiSignatureClient.sol";
import "../token/DebtToken.sol";
import "../oracle/PledgeOracle.sol";
import "./structs/PoolBaseInfo.sol";
import "./structs/PoolDataInfo.sol";

contract AdminControl is PausableUpgradeable, MultiSignatureClient {
    // Constants
    PoolState internal constant INITIAL_POOL_STATE = PoolState.MATCH;

    // State Variables
    uint256 internal minDeposit;
    uint256 internal lendFee;
    uint256 internal borrowFee;
    address internal feeAddress;
    address internal swapRouter;

    PoolBaseInfo[] internal poolBaseInfos;
    PoolDataInfo[] internal poolDataInfos;

    PledgeOracle internal oracle;

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

    function __AdminControl_init(
        address multiSignature
    ) internal onlyInitializing {
        __MultiSignatureClient_init(multiSignature);
        __Pausable_init();
    }

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
}
