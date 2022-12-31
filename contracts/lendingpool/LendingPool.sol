// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

// openzeppelin imports
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// config imports
import "../Interfaces/IAddressProvider.sol";
import "../Interfaces/IParameterProvider.sol";
import "../Interfaces/IFeeProvider.sol";

// libraray imports
import "../lib/Math.sol";

// lending pool helpers
import "../Interfaces/ILendingPoolDataProvider.sol";
import "../Interfaces/ILendingPoolCore.sol";
import "../Interfaces/ILendingPool.sol";

// AToken
import "../Interfaces/IAToken.sol";

contract LendingPool is
    ILendingPool,
    Initializable,
    ReentrancyGuardUpgradeable
{
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    IAddressesProvider public addressesProvider;
    ILendingPoolCore public core;
    ILendingPoolDataProvider public dataProvider;
    IParameterProvider public parameterProvider;
    IFeeProvider public feeProvider;

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyActiveReserve(address _reserve) {
        _requireActiveReserve(_reserve);
        _;
    }

    modifier onlyUnfreezedReserve(address _reserve) {
        _requireUnfreezedReserve(_reserve);
        _;
    }

    modifier onlyAmountGreaterThanZero(uint256 _amount) {
        _requireAmountGreaterThanZero(_amount);
        _;
    }

    modifier onlyOverlyingAToken(address _reserve) {
        _requireOverlyingAToken(_reserve);
        _;
    }

    //============= init ===============//

    function initialize(address _addressProvider) public initializer {
        addressesProvider = IAddressesProvider(_addressProvider);
        core = ILendingPoolCore(addressesProvider.getLendingPoolCore());
        dataProvider = ILendingPoolDataProvider(
            addressesProvider.getLendingPoolDataProvider()
        );
        parameterProvider = IParameterProvider(
            addressesProvider.getLendingPoolParametersProvider()
        );
        feeProvider = IFeeProvider(addressesProvider.getFeeProvider());

        __ReentrancyGuard_init();
    }

    /// -----------------------------------------------------------------------
    /// User Actions
    /// -----------------------------------------------------------------------

    function deposit(address _reserve, uint256 _amount)
        external
        payable
        override
        nonReentrant
        onlyActiveReserve(_reserve)
        onlyUnfreezedReserve(_reserve)
        onlyAmountGreaterThanZero(_amount)
    {
        IAToken aToken = IAToken(core.getReserveATokenAddress(_reserve));

        bool isFirstDeposit = aToken.balanceOf(msg.sender) == 0;

        core.updateStateOnDeposit(
            _reserve,
            msg.sender,
            _amount,
            isFirstDeposit
        );

        aToken.mintOnDeposit(msg.sender, _amount);

        core.transferToReserve{value: msg.value}(_reserve, msg.sender, _amount);

        emit Deposit(_reserve, msg.sender, _amount, block.timestamp);
    }

    function redeemUnderlying(
        address _reserve,
        address payable _user,
        uint256 _amount,
        uint256 _aTokenBalanceAfterRedeem
    )
        external
        override
        nonReentrant
        onlyOverlyingAToken(_reserve)
        onlyActiveReserve(_reserve)
        onlyAmountGreaterThanZero(_amount)
    {
        uint256 currentAvailableLiquidity = core.getAvailableLiquidity(
            _reserve
        );

        if (currentAvailableLiquidity < _amount) {
            revert LendingPoolError(
                LendingPoolErrorCodes.INSUFFICIENT_LIQUIDITY
            );
        }

        core.updateStateOnRedeem(
            _reserve,
            _user,
            _amount,
            _aTokenBalanceAfterRedeem == 0
        );

        core.transferToUser(_reserve, _user, _amount);

        emit RedeemUnderlying(_reserve, _user, _amount, block.timestamp);
    }

    /// -----------------------------------------------------------------------
    /// Internal Actions
    /// -----------------------------------------------------------------------

    function _requireActiveReserve(address _reserve) internal view {
        if (!core.getReserveIsActive(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.POOL_INACTIVE);
        }
    }

    function _requireUnfreezedReserve(address _reserve) internal view {
        if (core.getReserveIsFreezed(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.POOL_FEEZED);
        }
    }

    function _requireAmountGreaterThanZero(uint256 _amount) internal pure {
        if (_amount <= 0) {
            revert LendingPoolError(LendingPoolErrorCodes.ZERO_AMOUNT);
        }
    }

    function _requireOverlyingAToken(address _reserve) internal view {
        if (msg.sender != core.getReserveATokenAddress(_reserve)) {
            revert LendingPoolError(LendingPoolErrorCodes.ONLY_A_TOKEN);
        }
    }
}
