// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IAddressesProvider {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------
    enum AddressProviderErrorCodes {
        ZERO_ADDRESS
    }

    error AddressProviderError(AddressProviderErrorCodes code);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------
    event LendingPoolUpdated(address indexed pool);
    event LendingPoolCoreUpdated(address indexed pool);
    event LendingPoolConfiguratorUpdated(address indexed pool);
    event LendingPoolDataProviderUpdated(address indexed pool);
    event LendingPoolParameterProvider(address indexed pool);
    event TokenDistributorUpdated(address indexed pool);
    event FeeProviderUpdated(address indexed pool);
    event LendingPoolLiquidationManagerUpdated(address indexed manager);
    event LendingPoolManagerUpdated(address lendingPoolManager);
    event PriceOracleUpdated(address priceOracle);
    event LendingRateOracleUpdated(address lendingRateOracle);

    /// -----------------------------------------------------------------------
    /// Setter Actions
    /// -----------------------------------------------------------------------
    function setLendingPool(address _pool) external;

    function setLendingPoolCore(address _lendingPoolCore) external;

    function setLendingPoolConfigurator(address _configurator) external;

    function setLendingPoolDataProvider(address _provider) external;

    function setLendingPoolParametersProvider(address _parametersProvider)
        external;

    function setTokenDistributor(address _tokenDistributor) external;

    function setFeeProvider(address _feeProvider) external;

    function setLendingPoolLiquidationManager(address _manager) external;

    function setLendingPoolManager(address _lendingPoolManager) external;

    function setPriceOracle(address _priceOracle) external;

    function setLendingRateOracle(address _lendingRateOracle) external;

    /// -----------------------------------------------------------------------
    /// Getter Actions
    /// -----------------------------------------------------------------------
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address);

    function getLendingPoolConfigurator() external view returns (address);

    function getLendingPoolDataProvider() external view returns (address);

    function getLendingPoolParametersProvider() external view returns (address);

    function getTokenDistributor() external view returns (address);

    function getFeeProvider() external view returns (address);

    function getLendingPoolLiquidationManager() external view returns (address);

    function getLendingPoolManager() external view returns (address);

    function getPriceOracle() external view returns (address);

    function getLendingRateOracle() external view returns (address);
}
