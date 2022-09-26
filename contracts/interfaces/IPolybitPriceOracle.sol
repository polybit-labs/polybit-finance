// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.4;

interface IPolybitPriceOracle {
    function getOracleStatus() external view returns (uint256);

    function getFactoryAddress() external view returns (address);

    function getTokenAddress() external view returns (address);

    function getSymbol() external view returns (string memory);

    function getDecimals() external view returns (uint8);

    function getLatestPrice() external view returns (uint256);

    function getLastUpdated() external view returns (uint256);
}
