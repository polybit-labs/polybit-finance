// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitRebalancer {
    function createSellList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory);

    function createAdjustList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory);

    function createAdjustToSellList(
        address detfAddress,
        address[] memory adjustList
    ) external view returns (address[] memory);

    function createAdjustToBuyList(
        address detfAddress,
        address[] memory adjustList
    ) external view returns (address[] memory);

    function createBuyList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory);

    function calcTotalTargetBuyPercentage(
        address[] memory adjustToBuyList,
        address[] memory buyList,
        address detfAddress
    ) external view returns (uint256, uint256);

    function createSellOrder(address[] memory sellList, address detfAddress)
        external
        view
        returns (uint256[] memory, uint256[] memory);

    function createAdjustToSellOrder(
        address[] memory adjustToSellList,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);

    function createAdjustToBuyOrder(
        address[] memory adjustToBuyList,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);

    function createBuyOrder(
        address[] memory buyList,
        uint256 wethBalance,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);
}
