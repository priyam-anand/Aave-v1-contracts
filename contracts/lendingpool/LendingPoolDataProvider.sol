// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Interfaces/ILendingPoolDataProvider.sol";
import "../Interfaces/IPriceOracleGetter.sol";
import "../Interfaces/ILendingPoolCore.sol";
import "../Interfaces/IAddressProvider.sol";
import "../utils/DataTypes.sol";
import "../lib/Math.sol";

contract LendingPoolDataProvider is ILendingPoolDataProvider, Initializable {
    using Math for uint256;

    ILendingPoolCore public core;
    IAddressesProvider public addressesProvider;

    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

    function initialize(address _addressesProvider) public initializer {
        addressesProvider = IAddressesProvider(_addressesProvider);
        core = ILendingPoolCore(addressesProvider.getLendingPoolCore());
    }

    function calculateCollateralNeededInETH(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        uint256 _userCurrentBorrowBalanceTH,
        uint256 _userCurrentFeesETH,
        uint256 _userCurrentLtv
    ) external view returns (uint256) {
        uint256 reserveDecimals = core.getReserveDecimals(_reserve);

        IPriceOracle oracle = IPriceOracle(addressesProvider.getPriceOracle());

        uint256 requestedBorrowAmountETH = (oracle.getAssetPrice(_reserve) *
            (_amount + _fee)) / (10**reserveDecimals); //price is in ether

        //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
        uint256 collateralNeededInETH = ((_userCurrentBorrowBalanceTH +
            _userCurrentFeesETH +
            requestedBorrowAmountETH) * 100) / _userCurrentLtv; //LTV is calculated in percentage

        return collateralNeededInETH;
    }

    function calculateUserGlobalData(address _user)
        public
        view
        override
        returns (
            uint256 totalLiquidityBalanceETH,
            uint256 totalCollateralBalanceETH,
            uint256 totalBorrowBalanceETH,
            uint256 totalFeesETH,
            uint256 currentLtv,
            uint256 currentLiquidationThreshold,
            uint256 healthFactor,
            bool healthFactorBelowThreshold
        )
    {
        IPriceOracle oracle = IPriceOracle(addressesProvider.getPriceOracle());

        // Usage of a memory struct of vars to avoid "Stack too deep" errors due to local variables
        UserGlobalDataLocalVars memory vars;

        address[] memory reserves = core.getReserves();

        for (uint256 i = 0; i < reserves.length; i++) {
            vars.currentReserve = reserves[i];

            (
                vars.compoundedLiquidityBalance,
                vars.compoundedBorrowBalance,
                vars.originationFee,
                vars.userUsesReserveAsCollateral
            ) = core.getUserBasicReserveData(vars.currentReserve, _user);

            if (
                vars.compoundedLiquidityBalance == 0 &&
                vars.compoundedBorrowBalance == 0
            ) {
                continue;
            }

            //fetch reserve data
            (
                vars.reserveDecimals,
                vars.baseLtv,
                vars.liquidationThreshold,
                vars.usageAsCollateralEnabled
            ) = core.getReserveConfiguration(vars.currentReserve);

            vars.tokenUnit = 10**vars.reserveDecimals;
            vars.reserveUnitPrice = oracle.getAssetPrice(vars.currentReserve);

            //liquidity and collateral balance
            if (vars.compoundedLiquidityBalance > 0) {
                uint256 liquidityBalanceETH = (vars.reserveUnitPrice *
                    vars.compoundedLiquidityBalance) / vars.tokenUnit;
                totalLiquidityBalanceETH =
                    totalLiquidityBalanceETH +
                    liquidityBalanceETH;

                if (
                    vars.usageAsCollateralEnabled &&
                    vars.userUsesReserveAsCollateral
                ) {
                    totalCollateralBalanceETH =
                        totalCollateralBalanceETH +
                        liquidityBalanceETH;
                    currentLtv =
                        currentLtv +
                        (liquidityBalanceETH * vars.baseLtv);
                    currentLiquidationThreshold =
                        currentLiquidationThreshold +
                        (liquidityBalanceETH * vars.liquidationThreshold);
                }
            }

            if (vars.compoundedBorrowBalance > 0) {
                totalBorrowBalanceETH =
                    totalBorrowBalanceETH +
                    ((vars.reserveUnitPrice * vars.compoundedBorrowBalance) /
                        vars.tokenUnit);
                totalFeesETH =
                    totalFeesETH +
                    (vars.originationFee * vars.reserveUnitPrice) /
                    vars.tokenUnit;
            }
        }

        currentLtv = totalCollateralBalanceETH > 0
            ? currentLtv / totalCollateralBalanceETH
            : 0;
        currentLiquidationThreshold = totalCollateralBalanceETH > 0
            ? currentLiquidationThreshold / totalCollateralBalanceETH
            : 0;

        healthFactor = calculateHealthFactorFromBalancesInternal(
            totalCollateralBalanceETH,
            totalBorrowBalanceETH,
            totalFeesETH,
            currentLiquidationThreshold
        );
        healthFactorBelowThreshold =
            healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
    }

    function calculateHealthFactorFromBalancesInternal(
        uint256 collateralBalanceETH,
        uint256 borrowBalanceETH,
        uint256 totalFeesETH,
        uint256 liquidationThreshold
    ) internal pure returns (uint256) {
        if (borrowBalanceETH == 0) return type(uint256).max;

        return
            ((collateralBalanceETH * liquidationThreshold) / 100).wadDiv(
                borrowBalanceETH + totalFeesETH
            );
    }
}
