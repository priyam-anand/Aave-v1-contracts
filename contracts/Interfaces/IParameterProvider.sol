// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IParameterProvider {
    function MAX_STABLE_RATE_BORROW_SIZE_PERCENT()
        external
        view
        returns (uint256);

    function REBALANCE_DOWN_RATE_DELTA() external view returns (uint256);

    function FLASHLOAN_FEE_TOTAL() external view returns (uint256);

    function FLASHLOAN_FEE_PROTOCOL() external view returns (uint256);
}
