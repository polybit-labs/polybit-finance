// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitDETF {
    function getDETFOracleAddress() external view returns (address);

    function getOwnedAssets() external view returns (address[] memory);

    function getEthBalance() external view returns (uint256);

    function getWethBalance() external view returns (uint256);

    function getTokenBalance(address tokenAddress, uint256 tokenPrice)
        external
        view
        returns (uint256, uint256);

    function getTotalBalanceInWeth(uint256[] memory ownedAssetsPrices)
        external
        view
        returns (uint256);

    function getRebalancerLists()
        external
        view
        returns (
            address[] memory,
            address[] memory,
            address[] memory,
            address[] memory
        );
}
