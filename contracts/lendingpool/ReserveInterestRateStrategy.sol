// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../Interfaces/IReserveInterestRateStrategy.sol";
import "../Interfaces/IAddressProvider.sol";
import "../Interfaces/ILendingRateOracle.sol";
import "../lib/Math.sol";

contract ReserveInterestRateStrategy is IReserveInterestRateStrategy {
    uint256 public constant OPTIMAL_UTILIZATION_RATE = 0.8 * 1e27;
    uint256 public constant EXCESS_UTILIZATION_RATE = 0.2 * 1e17;

    IAddressesProvider public addressesProvider;
    //base variable borrow rate when Utilization rate = 0. Expressed in ray
    uint256 public baseVariableBorrowRate;

    //slope of the variable interest curve when utilization rate > 0 and <= OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 public variableRateSlope1;

    //slope of the variable interest curve when utilization rate > OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 public variableRateSlope2;

    //slope of the stable interest curve when utilization rate > 0 and <= OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 public stableRateSlope1;

    //slope of the stable interest curve when utilization rate > OPTIMAL_UTILIZATION_RATE. Expressed in ray
    uint256 public stableRateSlope2;

    address public reserve;

    constructor(
        address _reserve,
        address _provider,
        uint256 _baseVariableBorrowRate,
        uint256 _variableRateSlope1,
        uint256 _variableRateSlope2,
        uint256 _stableRateSlope1,
        uint256 _stableRateSlope2
    ) {
        addressesProvider = IAddressesProvider(_provider);
        reserve = _reserve;
        baseVariableBorrowRate = _baseVariableBorrowRate;
        variableRateSlope1 = _variableRateSlope1;
        variableRateSlope2 = _variableRateSlope2;
        stableRateSlope1 = _stableRateSlope1;
        stableRateSlope2 = _stableRateSlope2;
    }

    function calculateInterestRates(
        address _reserve,
        uint256 _availableLiquidity,
        uint256 _totalBorrowsStable,
        uint256 _totalBorrowsVariable,
        uint256 _averageStableBorrowRate
    )
        external
        view
        returns (
            uint256 currentLiquidityRate,
            uint256 currentStableBorrowRate,
            uint256 currentVariableBorrowRate
        )
    {
        uint256 totalBorrows = _totalBorrowsStable + _totalBorrowsVariable;

        uint256 utilizationRate = (totalBorrows == 0 &&
            _availableLiquidity == 0)
            ? 0
            : Math.rayDiv(totalBorrows, _availableLiquidity + totalBorrows);

        currentStableBorrowRate = ILendingRateOracle(
            addressesProvider.getLendingRateOracle()
        ).getMarketBorrowRate(_reserve);

        if (utilizationRate > OPTIMAL_UTILIZATION_RATE) {
            uint256 excessUtilizationRateRatio = Math.rayDiv(
                utilizationRate - OPTIMAL_UTILIZATION_RATE,
                EXCESS_UTILIZATION_RATE
            );

            currentStableBorrowRate =
                currentStableBorrowRate +
                stableRateSlope1 +
                Math.rayMul(stableRateSlope2, excessUtilizationRateRatio);

            currentVariableBorrowRate =
                baseVariableBorrowRate +
                variableRateSlope1 +
                Math.rayMul(variableRateSlope2, excessUtilizationRateRatio);
        } else {
            currentStableBorrowRate =
                currentStableBorrowRate +
                Math.rayMul(
                    stableRateSlope1,
                    (Math.rayDiv(utilizationRate, OPTIMAL_UTILIZATION_RATE))
                );
            currentVariableBorrowRate =
                baseVariableBorrowRate +
                Math.rayDiv(
                    utilizationRate,
                    Math.rayMul(OPTIMAL_UTILIZATION_RATE, variableRateSlope1)
                );
        }

        currentLiquidityRate = Math.rayMul(
            getOverallBorrowRateInternal(
                _totalBorrowsStable,
                _totalBorrowsVariable,
                currentVariableBorrowRate,
                _averageStableBorrowRate
            ),
            utilizationRate
        );
    }

    function getOverallBorrowRateInternal(
        uint256 _totalBorrowsStable,
        uint256 _totalBorrowsVariable,
        uint256 _currentVariableBorrowRate,
        uint256 _currentAverageStableBorrowRate
    ) internal pure returns (uint256) {
        uint256 totalBorrows = _totalBorrowsStable + _totalBorrowsVariable;

        if (totalBorrows == 0) return 0;

        uint256 weightedVariableRate = Math.rayMul(
            Math.wadToRay(_totalBorrowsVariable),
            _currentVariableBorrowRate
        );

        uint256 weightedStableRate = Math.rayMul(
            Math.wadToRay(_totalBorrowsStable),
            _currentAverageStableBorrowRate
        );

        uint256 overallBorrowRate = Math.rayDiv(
            weightedVariableRate + weightedStableRate,
            Math.wadToRay(totalBorrows)
        );

        return overallBorrowRate;
    }
}
