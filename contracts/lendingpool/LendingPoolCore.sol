// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Interfaces/ILendingPoolCore.sol";
import "../Interfaces/IAddressProvider.sol";
import "../Interfaces/IReserveInterestRateStrategy.sol";
import "../Interfaces/IAToken.sol";

import "../utils/DataTypes.sol";

import "../lib/CoreLibrary.sol";
import "../lib/EthLibrary.sol";

contract LendingPoolCore is ILendingPoolCore, Initializable {
    address public lendingPoolAddress;
    IAddressesProvider public addressesProvider;

    mapping(address => ReserveData) internal reserves;
    mapping(address => mapping(address => UserReserveData))
        public userReserveData;

    address[] public reservesList;

    // modifiers
    modifier onlyLendingPool() {
        if (msg.sender != lendingPoolAddress) {
            revert LendingPoolCoreError(
                LendingPoolCoreErrorCodes.LENDING_POOL_ONLY
            );
        }
        _;
    }

    // init
    function initialize(address _addressesProvider) public initializer {
        addressesProvider = IAddressesProvider(_addressesProvider);
        _refreshConfig();
    }

    // actions
    function updateStateOnDeposit(
        address _reserve,
        address _user,
        uint256 _amount,
        bool _isFirstDeposit
    ) external onlyLendingPool {
        CoreLibrary.updateCumulativeIndexes(reserves[_reserve]);
        _updateReserveInterestRatesAndTimestamp(_reserve, _amount, 0);

        if (_isFirstDeposit) {
            setUserUseReserveAsCollateral(_reserve, _user, true);
        }
    }

    function updateStateOnRedeem(
        address _reserve,
        address payable _user,
        uint256 _amount,
        bool _redeemAll
    ) external onlyLendingPool {
        CoreLibrary.updateCumulativeIndexes(reserves[_reserve]);
        _updateReserveInterestRatesAndTimestamp(_reserve, 0, _amount);

        if (_redeemAll) {
            setUserUseReserveAsCollateral(_reserve, _user, false);
        }
    }

    function updateStateOnBorrow(
        address _reserve,
        address _user,
        uint256 _amountBorrowed,
        uint256 _borrowFee,
        InterestRateMode _rateMode
    ) external onlyLendingPool returns (uint256, uint256) {
        (
            uint256 principalBorrowBalance,
            ,
            uint256 balanceIncrease
        ) = getUserBorrowBalances(_reserve, _user);

        _updateReserveTotalBorrowsByRateMode(
            _reserve,
            _user,
            principalBorrowBalance,
            balanceIncrease,
            _amountBorrowed,
            _rateMode
        );

        _updateUserStateOnBorrow(
            _reserve,
            _user,
            _amountBorrowed,
            balanceIncrease,
            _borrowFee,
            _rateMode
        );

        _updateReserveInterestRatesAndTimestamp(_reserve, 0, _amountBorrowed);

        return (_getUserCurrentBorrowRate(_reserve, _user), balanceIncrease);
    }

    function transferToReserve(
        address _reserve,
        address _user,
        uint256 _amount
    ) external payable onlyLendingPool {
        if (_reserve == EthLibrary.ethAddress()) {
            if (_amount != msg.value) {
                revert LendingPoolCoreError(
                    LendingPoolCoreErrorCodes.INVALID_ETH_AMOUNT
                );
            }
        } else {
            SafeERC20.safeTransferFrom(
                IERC20(_reserve),
                _user,
                address(this),
                _amount
            );
        }
    }

    function transferToUser(
        address _reserve,
        address payable _user,
        uint256 _amount
    ) external onlyLendingPool {
        if (_reserve == EthLibrary.ethAddress()) {
            (bool success, ) = _user.call{value: _amount}("");
            if (!success) {
                revert LendingPoolCoreError(
                    LendingPoolCoreErrorCodes.FAILED_TO_SEND_ETH
                );
            }
        } else {
            SafeERC20.safeTransfer(IERC20(_reserve), _user, _amount);
        }
    }

    function setUserUseReserveAsCollateral(
        address _reserve,
        address _user,
        bool _useAsCollateral
    ) public onlyLendingPool {
        UserReserveData storage user = userReserveData[_user][_reserve];
        user.useAsCollateral = _useAsCollateral;
    }

    // view
    function getUserBasicReserveData(address _reserve, address _user)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        ReserveData storage reserve = reserves[_reserve];
        UserReserveData storage user = userReserveData[_user][_reserve];

        uint256 underlyingBalance = _getUserUnderlyingAssetBalance(
            _reserve,
            _user
        );

        if (user.principalBorrowBalance == 0) {
            return (underlyingBalance, 0, 0, user.useAsCollateral);
        }

        return (
            underlyingBalance,
            CoreLibrary.getCompoundedBorrowBalance(user, reserve),
            user.originationFee,
            user.useAsCollateral
        );
    }

    function getReserveConfiguration(address _reserve)
        external
        view
        override
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        uint256 decimals;
        uint256 baseLTVasCollateral;
        uint256 liquidationThreshold;
        bool usageAsCollateralEnabled;

        ReserveData storage reserve = reserves[_reserve];
        decimals = reserve.decimals;
        baseLTVasCollateral = reserve.baseLTVasCollateral;
        liquidationThreshold = reserve.liquidationThreshold;
        usageAsCollateralEnabled = reserve.usageAsCollateralEnabled;

        return (
            decimals,
            baseLTVasCollateral,
            liquidationThreshold,
            usageAsCollateralEnabled
        );
    }

    function getReserves() public view override returns (address[] memory) {
        return reservesList;
    }

    function getAvailableLiquidity(address _reserve)
        public
        view
        override
        returns (uint256 balance)
    {
        if (_reserve == EthLibrary.ethAddress()) {
            balance = address(this).balance;
        } else {
            balance = IERC20(_reserve).balanceOf(address(this));
        }
    }

    function getReserveIsActive(address _reserve)
        external
        view
        override
        returns (bool)
    {
        ReserveData storage reserve = reserves[_reserve];
        return reserve.isActive;
    }

    function getReserveIsFreezed(address _reserve)
        external
        view
        override
        returns (bool)
    {
        ReserveData storage reserve = reserves[_reserve];
        return reserve.isFreezed;
    }

    function getReserveATokenAddress(address _reserve)
        external
        view
        override
        returns (address)
    {
        ReserveData storage reserve = reserves[_reserve];
        return reserve.aTokenAddress;
    }

    function getReserveDecimals(address _reserve)
        external
        view
        override
        returns (uint256)
    {
        return reserves[_reserve].decimals;
    }

    function isReserveBorrowingEnabled(address _reserve)
        external
        view
        returns (bool)
    {
        ReserveData storage reserve = reserves[_reserve];
        return reserve.borrowingEnabled;
    }

    function isUserAllowedToBorrowAtStable(
        address _reserve,
        address _user,
        uint256 _amount
    ) external view override returns (bool) {
        ReserveData storage reserve = reserves[_reserve];
        UserReserveData storage userData = userReserveData[_user][_reserve];
        if (!reserve.isStableBorrowRateEnabled) return false;
        return
            !userData.useAsCollateral ||
            !reserve.usageAsCollateralEnabled ||
            _amount > _getUserUnderlyingAssetBalance(_reserve, _user);
    }

    // internal
    function _refreshConfig() internal {
        lendingPoolAddress = addressesProvider.getLendingPool();
    }

    function _getUserUnderlyingAssetBalance(address _reserve, address _user)
        internal
        view
        returns (uint256)
    {
        IAToken aToken = IAToken(reserves[_reserve].aTokenAddress);
        return aToken.balanceOf(_user);
    }

    function _updateReserveInterestRatesAndTimestamp(
        address _reserve,
        uint256 _liquidityAdded,
        uint256 _liquidityTaken
    ) internal {
        ReserveData storage reserve = reserves[_reserve];

        IReserveInterestRateStrategy interestRateStrategy = IReserveInterestRateStrategy(
                reserves[_reserve].interestRateStrategyAddress
            );

        (
            uint256 newLiquidityRate,
            uint256 newStableBorrowRate,
            uint256 newVariableBorrowRate
        ) = interestRateStrategy.calculateInterestRates(
                _reserve,
                getAvailableLiquidity(_reserve) +
                    _liquidityAdded -
                    _liquidityTaken,
                reserve.totalBorrowsStable,
                reserve.totalBorrowsVariable,
                reserve.currentAverageStableBorrowRate
            );

        reserve.currentLiquidityRate = newLiquidityRate;
        reserve.currentStableBorrowRate = newStableBorrowRate;
        reserve.currentVariableBorrowRate = newVariableBorrowRate;

        reserve.lastUpdateTimestamp = block.timestamp;

        emit ReserveUpdated(
            _reserve,
            newLiquidityRate,
            newStableBorrowRate,
            newVariableBorrowRate,
            reserve.lastLiquidityCumulativeIndex,
            reserve.lastVariableBorrowCumulativeIndex
        );
    }

    function getUserBorrowBalances(address _reserve, address _user)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        UserReserveData storage user = userReserveData[_user][_reserve];
        if (user.principalBorrowBalance == 0) {
            return (0, 0, 0);
        }

        uint256 principal = user.principalBorrowBalance;
        uint256 compoundedBalance = CoreLibrary.getCompoundedBorrowBalance(
            user,
            reserves[_reserve]
        );
        return (principal, compoundedBalance, compoundedBalance - principal);
    }

    function _updateReserveTotalBorrowsByRateMode(
        address _reserve,
        address _user,
        uint256 _principalBalance,
        uint256 _balanceIncrease,
        uint256 _amountBorrowed,
        InterestRateMode _newBorrowRateMode
    ) internal {
        InterestRateMode previousRateMode = getUserCurrentBorrowRateMode(
            _reserve,
            _user
        );
        ReserveData storage reserve = reserves[_reserve];

        if (previousRateMode == InterestRateMode.STABLE) {
            UserReserveData storage user = userReserveData[_user][_reserve];
            CoreLibrary.decreaseTotalBorrowsStableAndUpdateAverageRate(
                reserve,
                _principalBalance,
                user.stableBorrowRate
            );
        } else if (previousRateMode == InterestRateMode.VARIABLE) {
            CoreLibrary.decreaseTotalBorrowsVariable(
                reserve,
                _principalBalance
            );
        }

        uint256 newPrincipalAmount = _principalBalance +
            _balanceIncrease +
            _amountBorrowed;
        if (_newBorrowRateMode == InterestRateMode.STABLE) {
            CoreLibrary.increaseTotalBorrowsStableAndUpdateAverageRate(
                reserve,
                newPrincipalAmount,
                reserve.currentStableBorrowRate
            );
        } else if (_newBorrowRateMode == InterestRateMode.VARIABLE) {
            CoreLibrary.increaseTotalBorrowsVariable(
                reserve,
                newPrincipalAmount
            );
        } else {
            revert("Invalid new borrow rate mode");
        }
    }

    function getUserCurrentBorrowRateMode(address _reserve, address _user)
        internal
        view
        returns (InterestRateMode)
    {
        UserReserveData storage user = userReserveData[_user][_reserve];

        if (user.principalBorrowBalance == 0) {
            return InterestRateMode.NONE;
        }

        return
            user.stableBorrowRate > 0
                ? InterestRateMode.STABLE
                : InterestRateMode.VARIABLE;
    }

    function _updateUserStateOnBorrow(
        address _reserve,
        address _user,
        uint256 _amountBorrowed,
        uint256 _balanceIncrease,
        uint256 _fee,
        InterestRateMode _rateMode
    ) internal {
        ReserveData storage reserve = reserves[_reserve];
        UserReserveData storage user = userReserveData[_user][_reserve];

        if (_rateMode == InterestRateMode.STABLE) {
            //stable
            //reset the user variable index, and update the stable rate
            user.stableBorrowRate = reserve.currentStableBorrowRate;
            user.lastVariableBorrowCumulativeIndex = 0;
        } else if (_rateMode == InterestRateMode.VARIABLE) {
            //variable
            //reset the user stable rate, and store the new borrow index
            user.stableBorrowRate = 0;
            user.lastVariableBorrowCumulativeIndex = reserve
                .lastVariableBorrowCumulativeIndex;
        } else {
            revert("Invalid borrow rate mode");
        }
        //increase the principal borrows and the origination fee
        user.principalBorrowBalance =
            user.principalBorrowBalance +
            _amountBorrowed +
            _balanceIncrease;
        user.originationFee = user.originationFee + _fee;

        //solium-disable-next-line
        user.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _getUserCurrentBorrowRate(address _reserve, address _user)
        internal
        view
        returns (uint256)
    {
        InterestRateMode rateMode = getUserCurrentBorrowRateMode(
            _reserve,
            _user
        );

        if (rateMode == InterestRateMode.NONE) {
            return 0;
        }

        return
            rateMode == InterestRateMode.STABLE
                ? userReserveData[_user][_reserve].stableBorrowRate
                : reserves[_reserve].currentVariableBorrowRate;
    }
}
