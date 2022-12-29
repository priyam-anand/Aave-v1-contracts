// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../Interfaces/IAddressProvider.sol";

contract AddressProvider is Ownable, IAddressesProvider {
    /// -----------------------------------------------------------------------
    /// Storage variables
    /// -----------------------------------------------------------------------

    /// Constants
    bytes32 constant LENDING_POOL = "LENDING_POOL";
    bytes32 constant LENDING_POOL_CORE = "LENDING_POOL_CORE";
    bytes32 constant LENDING_POOL_CONFIGURATOR = "LENDING_POOL_CONFIGURATOR";
    bytes32 constant LENDING_POOL_DATA_PROVIDER = "LENDING_POOL_DATA_PROVIDER";
    bytes32 constant LENDING_POOL_PARAMETER_PROVIDER =
        "LENDING_POOL_PARAMETER_PROVIDER";
    bytes32 constant TOKEN_DISTRIBUTOR = "TOKEN_DISTRIBUTOR";
    bytes32 constant FEE_PROVIDER = "FEE_PROVIDER";
    bytes32 constant LENDING_POOL_LIQUIDATION_MANAGER =
        "LENDING_POOL_LIQUIDATION_MANAGER";
    bytes32 constant LENDING_POOL_MANAGER = "LENDING_POOL_MANAGER";
    bytes32 constant PRICE_ORACLE = "PRICE_ORACLE";
    bytes32 constant LENDING_RATE_ORACLE = "LENDING_RATE_ORACLE";

    mapping(bytes32 => address) private addresses;

    /// -----------------------------------------------------------------------
    /// Setter Actions
    /// -----------------------------------------------------------------------
    function setLendingPool(address _pool) external override onlyOwner {
        _updateImplementation(LENDING_POOL, _pool);
        emit LendingPoolUpdated(_pool);
    }

    function setLendingPoolCore(address _pool) external override onlyOwner {
        _updateImplementation(LENDING_POOL_CORE, _pool);
        emit LendingPoolCoreUpdated(_pool);
    }

    function setLendingPoolConfigurator(address _pool)
        external
        override
        onlyOwner
    {
        _updateImplementation(LENDING_POOL_CONFIGURATOR, _pool);
        emit LendingPoolConfiguratorUpdated(_pool);
    }

    function setLendingPoolDataProvider(address _pool)
        external
        override
        onlyOwner
    {
        _updateImplementation(LENDING_POOL_DATA_PROVIDER, _pool);
        emit LendingPoolDataProviderUpdated(_pool);
    }

    function setLendingPoolParametersProvider(address _pool)
        external
        override
        onlyOwner
    {
        _updateImplementation(LENDING_POOL_PARAMETER_PROVIDER, _pool);
        emit LendingPoolParameterProvider(_pool);
    }

    function setTokenDistributor(address _pool) external override onlyOwner {
        _updateImplementation(TOKEN_DISTRIBUTOR, _pool);
        emit TokenDistributorUpdated(_pool);
    }

    function setFeeProvider(address _pool) external override onlyOwner {
        _updateImplementation(FEE_PROVIDER, _pool);
        emit FeeProviderUpdated(_pool);
    }

    function setLendingPoolLiquidationManager(address _manager)
        external
        override
        onlyOwner
    {
        _setAddress(LENDING_POOL_LIQUIDATION_MANAGER, _manager);
        emit LendingPoolLiquidationManagerUpdated(_manager);
    }

    function setLendingPoolManager(address _lendingPoolManager)
        external
        override
        onlyOwner
    {
        _setAddress(LENDING_POOL_MANAGER, _lendingPoolManager);
        emit LendingPoolManagerUpdated(_lendingPoolManager);
    }

    function setPriceOracle(address _priceOracle) external override onlyOwner {
        _setAddress(PRICE_ORACLE, _priceOracle);
        emit PriceOracleUpdated(_priceOracle);
    }

    function setLendingRateOracle(address _lendingRateOracle)
        external
        override
        onlyOwner
    {
        _setAddress(LENDING_RATE_ORACLE, _lendingRateOracle);
        emit LendingRateOracleUpdated(_lendingRateOracle);
    }

    /// -----------------------------------------------------------------------
    /// Getter Actions
    /// -----------------------------------------------------------------------
    function getLendingPool() external view override returns (address) {
        return _getAddress(LENDING_POOL);
    }

    function getLendingPoolCore() external view override returns (address) {
        return _getAddress(LENDING_POOL_CORE);
    }

    function getLendingPoolConfigurator()
        external
        view
        override
        returns (address)
    {
        return _getAddress(LENDING_POOL_CONFIGURATOR);
    }

    function getLendingPoolDataProvider()
        external
        view
        override
        returns (address)
    {
        return _getAddress(LENDING_POOL_DATA_PROVIDER);
    }

    function getLendingPoolParametersProvider()
        external
        view
        override
        returns (address)
    {
        return _getAddress(LENDING_POOL_PARAMETER_PROVIDER);
    }

    function getTokenDistributor() external view override returns (address) {
        return _getAddress(TOKEN_DISTRIBUTOR);
    }

    function getFeeProvider() external view override returns (address) {
        return _getAddress(FEE_PROVIDER);
    }

    function getLendingPoolLiquidationManager()
        external
        view
        override
        returns (address)
    {
        return _getAddress(LENDING_POOL_LIQUIDATION_MANAGER);
    }

    function getLendingPoolManager() external view override returns (address) {
        return _getAddress(LENDING_POOL_MANAGER);
    }

    function getPriceOracle() external view override returns (address) {
        return _getAddress(PRICE_ORACLE);
    }

    function getLendingRateOracle() external view override returns (address) {
        return _getAddress(LENDING_RATE_ORACLE);
    }

    /// -----------------------------------------------------------------------
    /// Internal Actions
    /// -----------------------------------------------------------------------
    function _updateImplementation(bytes32 _id, address _pool) internal {
        if (_pool == address(0)) {
            revert AddressProviderError(AddressProviderErrorCodes.ZERO_ADDRESS);
        }
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(_getAddress(_id))
        );
        proxy.upgradeTo(_pool);
    }

    function _getAddress(bytes32 key) internal view returns (address) {
        return addresses[key];
    }

    function _setAddress(bytes32 key, address value) internal {
        addresses[key] = value;
    }
}
