// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "../utils/DataTypes.sol";

interface ILendingPoolCore {
    // error
    enum LendingPoolCoreErrorCodes {
        LENDING_POOL_ONLY,
        INVALID_ETH_AMOUNT,
        FAILED_TO_SEND_ETH
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

    function updateStateOnRedeem(
        address reserve,
        address payable user,
        uint256 amount,
        bool redeemAll
    ) external;

    function transferToReserve(
        address reseve,
        address user,
        uint256 amount
    ) external payable;

    function transferToUser(
        address reserve,
        address payable user,
        uint256 amount
    ) external;

    function updateStateOnBorrow(
        address _reserve,
        address _user,
        uint256 _amountBorrowed,
        uint256 _borrowFee,
        InterestRateMode _rateMode
    ) external returns (uint256, uint256);

    // view
    function getUserBasicReserveData(address _reserve, address _user)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        );

    function getReserveConfiguration(address _reserve)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        );

    function getReserves() external view returns (address[] memory);

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

    function getReserveDecimals(address reserve)
        external
        view
        returns (uint256);

    function isReserveBorrowingEnabled(address reserve)
        external
        view
        returns (bool);

    function isUserAllowedToBorrowAtStable(
        address reserve,
        address user,
        uint256 amount
    ) external view returns (bool);
}
