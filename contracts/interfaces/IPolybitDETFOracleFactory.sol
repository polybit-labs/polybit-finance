// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitDETFOracleFactory {
    function getListOfOracles() external view returns (address[] memory);

    function getDepositFee() external view returns (uint256);

    function getPerformanceFee() external view returns (uint256);

    function getFeeAddress() external view returns (address);
}
