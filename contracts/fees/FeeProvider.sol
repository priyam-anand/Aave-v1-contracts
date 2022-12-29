// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Interfaces/IFeeProvider.sol";
import "../lib/Math.sol";

contract FeeProvider is Initializable, IFeeProvider {
    uint256 public originationFeePercentage;

    function initialize(address) public initializer {
        originationFeePercentage = 25 * 1e14;
    }

    function calculateLoanOriginationFee(address, uint256 _amount)
        external
        view
        returns (uint256 value)
    {
        value = Math.wadMul(_amount, originationFeePercentage);
    }
}
