// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILendingPool {
    enum LendingPoolErrorCodes {
        POOL_INACTIVE,
        POOL_FEEZED,
        ZERO_AMOUNT,
        ONLY_A_TOKEN,
        INSUFFICIENT_LIQUIDITY
    }

    error LendingPoolError(LendingPoolErrorCodes code);

    event Deposit(
        address indexed _reserve,
        address indexed _user,
        uint256 _amount,
        uint256 _timestamp
    );

    event RedeemUnderlying(
        address indexed _reserve,
        address indexed _user,
        uint256 _amount,
        uint256 _timestamp
    );

    event Borrow(
        address indexed _reserve,
        address indexed _user,
        uint256 _amount,
        uint256 _borrowRateMode,
        uint256 _borrowRate,
        uint256 _originationFee,
        uint256 _borrowBalanceIncrease,
        uint16 indexed _referral,
        uint256 _timestamp
    );

    event Repay(
        address indexed _reserve,
        address indexed _user,
        address indexed _repayer,
        uint256 _amountMinusFees,
        uint256 _fees,
        uint256 _borrowBalanceIncrease,
        uint256 _timestamp
    );

    event Swap(
        address indexed _reserve,
        address indexed _user,
        uint256 _newRateMode,
        uint256 _newRate,
        uint256 _borrowBalanceIncrease,
        uint256 _timestamp
    );

    event ReserveUsedAsCollateralEnabled(
        address indexed _reserve,
        address indexed _user
    );

    event ReserveUsedAsCollateralDisabled(
        address indexed _reserve,
        address indexed _user
    );

    event RebalanceStableBorrowRate(
        address indexed _reserve,
        address indexed _user,
        uint256 _newStableRate,
        uint256 _borrowBalanceIncrease,
        uint256 _timestamp
    );

    event FlashLoan(
        address indexed _target,
        address indexed _reserve,
        uint256 _amount,
        uint256 _totalFee,
        uint256 _protocolFee,
        uint256 _timestamp
    );

    /**
     * @dev these events are not emitted directly by the LendingPool
     * but they are declared here as the LendingPoolLiquidationManager
     * is executed using a delegateCall().
     * This allows to have the events in the generated ABI for LendingPool.
     **/

    event OriginationFeeLiquidated(
        address indexed _collateral,
        address indexed _reserve,
        address indexed _user,
        uint256 _feeLiquidated,
        uint256 _liquidatedCollateralForFee,
        uint256 _timestamp
    );

    event LiquidationCall(
        address indexed _collateral,
        address indexed _reserve,
        address indexed _user,
        uint256 _purchaseAmount,
        uint256 _liquidatedCollateralAmount,
        uint256 _accruedBorrowInterest,
        address _liquidator,
        bool _receiveAToken,
        uint256 _timestamp
    );

    function deposit(address reserve, uint256 amount) external payable;

    function redeemUnderlying(
        address reserve,
        address payable _user,
        uint256 amount,
        uint256 aTokenBalanceAfterRedeem
    ) external;
}
