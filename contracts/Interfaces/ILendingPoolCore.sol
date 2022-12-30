// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILendingPoolCore {
    // error
    enum LendingPoolCoreErrorCodes {
        LENDING_POOL_ONLY,
        INVALID_ETH_AMOUNT
    }

    error LendingPoolCoreError(LendingPoolCoreErrorCodes code);

    // event
    event ReserveUpdated(
        address indexed reserve,
        uint256 liquidityRate,
        uint256 stableBorrowRate,
        uint256 variableBorrowRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex
    );

    // actions
    function updateStateOnDeposit(
        address reserve,
        address user,
        uint256 amount,
        bool isFirstDeposit
    ) external;

    function transferToReserve(
        address reseve,
        address user,
        uint256 amount
    ) external payable;

    // view
    function getAvailableLiquidity(address reserve)
        external
        view
        returns (uint256);

    function getReserveIsActive(address reserve) external view returns (bool);

    function getReserveIsFreezed(address reserve) external view returns (bool);

    function getReserveATokenAddress(address reserve)
        external
        view
        returns (address);
}
