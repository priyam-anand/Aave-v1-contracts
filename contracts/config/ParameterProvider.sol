// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../Interfaces/IParameterProvider.sol";

contract ParameterProvider is Initializable, IParameterProvider {
    uint256 public constant MAX_STABLE_RATE_BORROW_SIZE_PERCENT = 25;
    uint256 public constant REBALANCE_DOWN_RATE_DELTA = (1e27) / 5;
    uint256 public constant FLASHLOAN_FEE_TOTAL = 35;
    uint256 public constant FLASHLOAN_FEE_PROTOCOL = 3000;

    function initialize(address _addressesProvider) public initializer {}
}
