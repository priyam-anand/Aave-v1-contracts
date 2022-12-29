// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IFeeProvider {
    function calculateLoanOriginationFee(address user, uint256 amount)
        external
        view
        returns (uint256);

    function originationFeePercentage() external view returns (uint256);
}
