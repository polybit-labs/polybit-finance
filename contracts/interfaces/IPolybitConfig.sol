// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitConfig {
    function getPolybitRebalancerAddress() external view returns (address);

    function getPolybitRouterAddress() external view returns (address);

    function getPolybitDETFFactoryAddress() external view returns (address);

    function getDETFProductInfo(
        uint256 _productId
    ) external view returns (string memory, string memory, uint256, uint256);

    function getFeeAddress() external view returns (address);

    function getWethAddress() external view returns (address);
}
