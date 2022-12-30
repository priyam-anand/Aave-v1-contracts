// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAToken is IERC20 {
    function mintOnDeposit(address to, uint256 amount) external;
}
