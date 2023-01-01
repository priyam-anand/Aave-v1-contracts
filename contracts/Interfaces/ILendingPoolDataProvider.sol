// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILendingPoolDataProvider {
    function calculateUserGlobalData(address _user)
        external
        view
        returns (
            uint256 totalLiquidityBalanceETH,
            uint256 totalCollateralBalanceETH,
            uint256 totalBorrowBalanceETH,
            uint256 totalFeesETH,
            uint256 currentLtv,
            uint256 currentLiquidationThreshold,
            uint256 healthFactor,
            bool healthFactorBelowThreshold
        );

    function calculateCollateralNeededInETH(
        address reserve,
        uint256 amount,
        uint256 fee,
        uint256 userCurrentBorrowBalanceTH,
        uint256 userCurrentFeesETH,
        uint256 userCurrentLtv
    ) external view returns (uint256);
}
