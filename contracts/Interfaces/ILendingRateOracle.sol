// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILendingRateOracle {
    function getMarketBorrowRate(address _asset)
        external
        view
        returns (uint256);

    function setMarketBorrowRate(address _asset, uint256 _rate) external;
}
