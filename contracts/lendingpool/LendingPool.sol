// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// openzeppelin imports
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// config imports
import "../Interfaces/IAddressProvider.sol";
import "../Interfaces/IParameterProvider.sol";
import "../Interfaces/IFeeProvider.sol";

// libraray imports
import "../lib/Math.sol";
import "../utils/DataTypes.sol";

// lending pool helpers
import "../Interfaces/ILendingPoolDataProvider.sol";
import "../Interfaces/ILendingPoolCore.sol";
import "../Interfaces/ILendingPool.sol";

// AToken
import "../Interfaces/IAToken.sol";

contract LendingPool is
    ILendingPool,
    Initializable,
    ReentrancyGuardUpgradeable
{
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    IAddressesProvider public addressesProvider;
    ILendingPoolCore public core;
    ILendingPoolDataProvider public dataProvider;
    IParameterProvider public parameterProvider;
    IFeeProvider public feeProvider;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyActiveReserve(address _reserve) {
        _requireActiveReserve(_reserve);
        _;
    }

    modifier onlyUnfreezedReserve(address _reserve) {
        _requireUnfreezedReserve(_reserve);
        _;
    }

    modifier onlyAmountGreaterThanZero(uint256 _amount) {
        _requireAmountGreaterThanZero(_amount);
        _;
    }

    modifier onlyOverlyingAToken(address _reserve) {
        _requireOverlyingAToken(_reserve);
        _;
    }

    //============= init ===============//

    function initialize(address _addressProvider) public initializer {
        addressesProvider = IAddressesProvider(_addressProvider);
        core = ILendingPoolCore(addressesProvider.getLendingPoolCore());
        dataProvider = ILendingPoolDataProvider(
            addressesProvider.getLendingPoolDataProvider()
        );
        parameterProvider = IParameterProvider(
            addressesProvider.getLendingPoolParametersProvider()
        );
        feeProvider = IFeeProvider(addressesProvider.getFeeProvider());

        __ReentrancyGuard_init();
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function deposit(address _reserve, uint256 _amount)
        external
        payable
        override
        nonReentrant
        onlyActiveReserve(_reserve)
        onlyUnfreezedReserve(_reserve)
        onlyAmountGreaterThanZero(_amount)
    {
        IAToken aToken = IAToken(core.getReserveATokenAddress(_reserve));

        bool isFirstDeposit = aToken.balanceOf(msg.sender) == 0;

        core.updateStateOnDeposit(
            _reserve,
            msg.sender,
            _amount,
            isFirstDeposit
        );

        aToken.mintOnDeposit(msg.sender, _amount);

        core.transferToReserve{value: msg.value}(_reserve, msg.sender, _amount);

        emit Deposit(_reserve, msg.sender, _amount, block.timestamp);
    }

    function redeemUnderlying(
        address _reserve,
        address payable _user,
        uint256 _amount,
        uint256 _aTokenBalanceAfterRedeem
    )
        external
        override
        nonReentrant
        onlyOverlyingAToken(_reserve)
        onlyActiveReserve(_reserve)
        onlyAmountGreaterThanZero(_amount)
    {
        _checkAvailableLiquidity(_reserve, _amount);

        core.updateStateOnRedeem(
            _reserve,
            _user,
            _amount,
            _aTokenBalanceAfterRedeem == 0
        );

        core.transferToUser(_reserve, _user, _amount);

        emit RedeemUnderlying(_reserve, _user, _amount, block.timestamp);
    }

    function borrow(
        address _reserve,
        uint256 _amount,
        uint256 _interestRateMode
    )
        external
        override
        nonReentrant
        onlyActiveReserve(_reserve)
        onlyUnfreezedReserve(_reserve)
        onlyAmountGreaterThanZero(_amount)
    {
        _checkReserveBorrowing(_reserve);

        if (!(_interestRateMode == 0 || _interestRateMode == 1)) {
            revert LendingPoolError(
                LendingPoolErrorCodes.INVALID_INTEREST_RATE
            );
        }
        BorrowLocalVars memory vars;

        vars.availableLiquidity = _checkAvailableLiquidity(_reserve, _amount);
        vars.rateMode = InterestRateMode(_interestRateMode);

        (
            ,
            vars.userCollateralBalanceETH,
            vars.userBorrowBalanceETH,
            vars.userTotalFeesETH,
            vars.currentLtv,
            vars.currentLiquidationThreshold,
            ,
            vars.healthFactorBelowThreshold
        ) = dataProvider.calculateUserGlobalData(msg.sender);

        if (vars.userCollateralBalanceETH <= 0) {
            revert LendingPoolError(
                LendingPoolErrorCodes.COLLATERAL_BALANCE_ZERO
            );
        }

        if (vars.healthFactorBelowThreshold) {
            revert LendingPoolError(
                LendingPoolErrorCodes.INVALID_HEALTH_FACTOR
            );
        }

        vars.borrowFee = feeProvider.calculateLoanOriginationFee(
            msg.sender,
            _amount
        );

        if (vars.borrowFee <= 0) {
            revert LendingPoolError(LendingPoolErrorCodes.INVALID_AMOUNT);
        }

        vars.amountOfCollateralNeededETH = dataProvider
            .calculateCollateralNeededInETH(
                _reserve,
                _amount,
                vars.borrowFee,
                vars.userBorrowBalanceETH,
                vars.userTotalFeesETH,
                vars.currentLtv
            );

        if (vars.amountOfCollateralNeededETH > vars.userCollateralBalanceETH) {
            revert LendingPoolError(
                LendingPoolErrorCodes.INVALID_COLLATERAL_AMOUNT
            );
        }

        if (vars.rateMode == InterestRateMode.STABLE) {
            if (
                !core.isUserAllowedToBorrowAtStable(
                    _reserve,
                    msg.sender,
                    _amount
                )
            ) {
                revert LendingPoolError(
                    LendingPoolErrorCodes.STABLE_RATE_NOT_ALLOWED
                );
            }
            uint256 maxLoanPercent = parameterProvider
                .MAX_STABLE_RATE_BORROW_SIZE_PERCENT();
            uint256 maxLoanSizeStable = (vars.availableLiquidity *
                maxLoanPercent) / 100;
            if (_amount > maxLoanSizeStable) {
                revert LendingPoolError(LendingPoolErrorCodes.INVALID_AMOUNT);
            }
        }

        (vars.finalUserBorrowRate, vars.borrowBalanceIncrease) = core
            .updateStateOnBorrow(
                _reserve,
                msg.sender,
                _amount,
                vars.borrowFee,
                vars.rateMode
            );

        core.transferToUser(_reserve, payable(msg.sender), _amount);
        emit Borrow(
            _reserve,
            msg.sender,
            _amount,
            _interestRateMode,
            vars.finalUserBorrowRate,
            vars.borrowFee,
            vars.borrowBalanceIncrease,
            block.timestamp
        );
    }

    /// -----------------------------------------------------------------------
    /// Internal Actions
    /// -----------------------------------------------------------------------

    function _requireActiveReserve(address _reserve) internal view {
        if (!core.getReserveIsActive(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.POOL_INACTIVE);
        }
    }

    function _requireUnfreezedReserve(address _reserve) internal view {
        if (core.getReserveIsFreezed(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.POOL_FEEZED);
        }
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        if (_amount <= 0) {
            revert LendingPoolError(LendingPoolErrorCodes.ZERO_AMOUNT);
        }
    }

    function _requireOverlyingAToken(address _reserve) internal view {
        if (msg.sender != core.getReserveATokenAddress(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.ONLY_A_TOKEN);
        }
    }

    function _checkAvailableLiquidity(address _reserve, uint256 _amount)
        internal
        view
        returns (uint256 _availableLiquidity)
    {
        _availableLiquidity = core.getAvailableLiquidity(_reserve);
        if (_availableLiquidity < _amount) {
            revert LendingPoolError(
                LendingPoolErrorCodes.INSUFFICIENT_LIQUIDITY
            );
        }
    }

    function _checkReserveBorrowing(address _reserve) internal view {
        if (!core.isReserveBorrowingEnabled(_reserve)) {
            revert LendingPoolError(
                LendingPoolErrorCodes.BORROWING_NOT_ENABLED
            );
        }
    }
}
