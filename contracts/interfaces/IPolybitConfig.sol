// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitConfig {
    function getPolybitRebalancerAddress() external view returns (address);

    function getPolybitRouterAddress() external view returns (address);

    function getPolybitDETFFactoryAddress() external view returns (address);

    function getDepositFee() external view returns (uint256);

    function getPerformanceFee() external view returns (uint256);

    function getFeeAddress() external view returns (address);

    function getWethAddress() external view returns (address);
}
