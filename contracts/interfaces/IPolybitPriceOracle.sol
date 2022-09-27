// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitPriceOracle {
    function getFactoryAddress() external view returns (address);

    function getOracleStatus() external view returns (uint256);

    function getTokenAddress() external view returns (address);

    function getSymbol() external view returns (string memory);

    function getDecimals() external view returns (uint8);

    function getLatestPrice() external view returns (uint256);

    function getLastUpdated() external view returns (uint256);
}
