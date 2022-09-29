// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitDETFOracle {
    function getFactoryAddress() external view returns (address);

    function getOracleStatus() external view returns (uint256);

    function getTargetList() external view returns (address[] memory);

    function getPriceOracleAddress(address tokenAddress)
        external
        view
        returns (address);

    function getBaseTokens() external view returns (address[] memory);

    function getTokenLiquiditySingle(address baseToken, address tokenAddress)
        external
        view
        returns (uint256);

    function getTokenLiquidity(address tokenAddress)
        external
        view
        returns (uint256);

    function getTotalLiquidity() external view returns (uint256);

    function getTargetPercentage(address tokenAddress, uint256 riskWeighting)
        external
        view
        returns (uint256);

    function getLastUpdated() external view returns (uint256);
}
