// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../Interfaces/ILendingPoolCore.sol";
import "../Interfaces/IAddressProvider.sol";
import "../Interfaces/IReserveInterestRateStrategy.sol";

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

    // internal
    function _refreshConfig() internal {
        lendingPoolAddress = addressesProvider.getLendingPool();
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
}
