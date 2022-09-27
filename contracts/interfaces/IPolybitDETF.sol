// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitDETF {
    function getDETFOracleAddress() external view returns (address);

    function getRiskWeighting() external view returns (string memory);

    function getOwnedAssets() external view returns (address[] memory);

    function getTargetAssets() external view returns (address[] memory);

    function getEthBalance() external view returns (uint256);

    function getWethBalance() external view returns (uint256);

    function getTokenBalance(address tokenAddress)
        external
        view
        returns (uint256, uint256);

    function getTotalBalanceInWeth() external view returns (uint256);
}
