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

    function getCompoundedBorrowBalance(
        UserReserveData storage _self,
        ReserveData storage _reserve
    ) internal view returns (uint256) {
        if (_self.principalBorrowBalance == 0) return 0;

        uint256 principalBorrowBalanceRay = _self
            .principalBorrowBalance
            .wadToRay();
        uint256 compoundedBalance = 0;
        uint256 cumulatedInterest = 0;

        if (_self.stableBorrowRate > 0) {
            cumulatedInterest = calculateCompoundedInterest(
                _self.stableBorrowRate,
                _self.lastUpdateTimestamp
            );
        } else {
            //variable interest
            cumulatedInterest = calculateCompoundedInterest(
                _reserve.currentVariableBorrowRate,
                _reserve.lastUpdateTimestamp
            ).rayMul(_reserve.lastVariableBorrowCumulativeIndex).rayDiv(
                    _self.lastVariableBorrowCumulativeIndex
                );
        }

        compoundedBalance = principalBorrowBalanceRay
            .rayMul(cumulatedInterest)
            .rayToWad();

        if (compoundedBalance == _self.principalBorrowBalance) {
            //solium-disable-next-line
            if (_self.lastUpdateTimestamp != block.timestamp) {
                //no interest cumulation because of the rounding - we add 1 wei
                //as symbolic cumulated interest to avoid interest free loans.

                return _self.principalBorrowBalance + 1 wei;
            }
        }

        return compoundedBalance;
    }

    function increaseTotalBorrowsStableAndUpdateAverageRate(
        ReserveData storage _reserve,
        uint256 _amount,
        uint256 _rate
    ) internal {
        uint256 previousTotalBorrowStable = _reserve.totalBorrowsStable;
        //updating reserve borrows stable
        _reserve.totalBorrowsStable = _reserve.totalBorrowsStable + _amount;

        //update the average stable rate
        //weighted average of all the borrows
        uint256 weightedLastBorrow = _amount.wadToRay().rayMul(_rate);
        uint256 weightedPreviousTotalBorrows = previousTotalBorrowStable
            .wadToRay()
            .rayMul(_reserve.currentAverageStableBorrowRate);

        _reserve.currentAverageStableBorrowRate = Math.rayDiv(
            weightedLastBorrow + weightedPreviousTotalBorrows,
            _reserve.totalBorrowsStable.wadToRay()
        );
    }

    function increaseTotalBorrowsVariable(
        ReserveData storage _reserve,
        uint256 _amount
    ) internal {
        _reserve.totalBorrowsVariable = _reserve.totalBorrowsVariable + _amount;
    }

    function decreaseTotalBorrowsVariable(
        ReserveData storage _reserve,
        uint256 _amount
    ) internal {
        require(
            _reserve.totalBorrowsVariable >= _amount,
            "The amount that is being subtracted from the variable total borrows is incorrect"
        );
        _reserve.totalBorrowsVariable = _reserve.totalBorrowsVariable - _amount;
    }

    function decreaseTotalBorrowsStableAndUpdateAverageRate(
        ReserveData storage _reserve,
        uint256 _amount,
        uint256 _rate
    ) internal {
        require(
            _reserve.totalBorrowsStable >= _amount,
            "Invalid amount to decrease"
        );

        uint256 previousTotalBorrowStable = _reserve.totalBorrowsStable;

        //updating reserve borrows stable
        _reserve.totalBorrowsStable = _reserve.totalBorrowsStable - _amount;

        if (_reserve.totalBorrowsStable == 0) {
            _reserve.currentAverageStableBorrowRate = 0; //no income if there are no stable rate borrows
            return;
        }

        //update the average stable rate
        //weighted average of all the borrows
        uint256 weightedLastBorrow = _amount.wadToRay().rayMul(_rate);
        uint256 weightedPreviousTotalBorrows = previousTotalBorrowStable
            .wadToRay()
            .rayMul(_reserve.currentAverageStableBorrowRate);

        require(
            weightedPreviousTotalBorrows >= weightedLastBorrow,
            "The amounts to subtract don't match"
        );

        _reserve.currentAverageStableBorrowRate = Math.rayDiv(
            weightedPreviousTotalBorrows - weightedLastBorrow,
            _reserve.totalBorrowsStable.wadToRay()
        );
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
