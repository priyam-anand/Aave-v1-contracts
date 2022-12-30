// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../utils/DataTypes.sol";
import "./Math.sol";

library CoreLibrary {
    using Math for uint256;

    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    function updateCumulativeIndexes(ReserveData storage _self) internal {
        uint256 totalBorrows = getTotalBorrows(_self);

        if (totalBorrows > 0) {
            //only cumulating if there is any income being produced
            uint256 cumulatedLiquidityInterest = calculateLinearInterest(
                _self.currentLiquidityRate,
                _self.lastUpdateTimestamp
            );

            _self.lastLiquidityCumulativeIndex = cumulatedLiquidityInterest
                .rayMul(_self.lastLiquidityCumulativeIndex);

            uint256 cumulatedVariableBorrowInterest = calculateCompoundedInterest(
                    _self.currentVariableBorrowRate,
                    _self.lastUpdateTimestamp
                );
            _self
                .lastVariableBorrowCumulativeIndex = cumulatedVariableBorrowInterest
                .rayMul(_self.lastVariableBorrowCumulativeIndex);
        }
    }

    function calculateCompoundedInterest(
        uint256 _rate,
        uint256 _lastUpdateTimestamp
    ) internal view returns (uint256) {
        //solium-disable-next-line
        uint256 timeDifference = block.timestamp - _lastUpdateTimestamp;

        uint256 ratePerSecond = _rate / SECONDS_PER_YEAR;

        return ratePerSecond + (Math.ray()).rayPow(timeDifference);
    }

    function calculateLinearInterest(
        uint256 _rate,
        uint256 _lastUpdateTimestamp
    ) internal view returns (uint256) {
        //solium-disable-next-line
        uint256 timeDifference = block.timestamp - _lastUpdateTimestamp;

        uint256 timeDelta = timeDifference.wadToRay().rayDiv(
            SECONDS_PER_YEAR.wadToRay()
        );

        return _rate.rayMul(timeDelta) + Math.ray();
    }

    function getTotalBorrows(ReserveData storage _reserve)
        internal
        view
        returns (uint256)
    {
        return _reserve.totalBorrowsStable + _reserve.totalBorrowsVariable;
    }
}
