// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitRebalancer {
    function createSellList(
        address[] memory ownedAssetsList,
        uint256[] memory ownedAssetsPrices,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory, uint256[] memory);

    function createAdjustList(
        address[] memory ownedAssetsList,
        uint256[] memory ownedAssetsPrices,
        address[] memory targetAssetsList,
        uint256[] memory targetAssetsWeights
    )
        external
        pure
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        );

    function createAdjustToSellList(
        address detfAddress,
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustList,
        uint256[] memory adjustListWeights,
        uint256[] memory adjustListPrices
    )
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        );

    function createAdjustToBuyList(
        address detfAddress,
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustList,
        uint256[] memory adjustListWeights,
        uint256[] memory adjustListPrices
    )
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        );

    function createBuyList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList,
        uint256[] memory targetAssetsWeights,
        uint256[] memory targetAssetsPrices
    )
        external
        pure
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        );

    function calcTotalTargetBuyPercentage(
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustToBuyList,
        uint256[] memory adjustToBuyWeights,
        uint256[] memory adjustToBuyPrices,
        address[] memory buyList,
        uint256[] memory buyListWeights,
        address detfAddress
    ) external view returns (uint256);

    function createSellOrder(
        address[] memory sellList,
        uint256[] memory sellListWeights,
        uint256[] memory sellListPrices,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);

    function createAdjustToSellOrder(
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustToSellList,
        uint256[] memory adjustToSellWeights,
        uint256[] memory adjustToSellPrices,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);

    function createAdjustToBuyOrder(
        uint256 totalBalance,
        uint256 wethBalance,
        address[] memory adjustToBuyList,
        uint256[] memory adjustToBuyWeights,
        uint256[] memory adjustToBuyPrices,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory);

    function createBuyOrder(
        address[] memory buyList,
        uint256[] memory buyListWeights,
        uint256[] memory buyListPrices,
        uint256 wethBalance,
        uint256 totalTargetPercentage
    ) external view returns (uint256[] memory, uint256[] memory);
}
