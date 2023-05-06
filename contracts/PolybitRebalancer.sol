// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitDETF.sol";

/**
 * @title Polybit Rebalancer
 * @author Matt Leeburn
 * @notice A protocol to create swap orders to rebalance a Decentralised ETF.
 */

contract PolybitRebalancer {
    struct SellListData {
        address[] sellList;
        uint256[] sellListPrices;
    }

    /**
     * @notice Used to create a list of tokens that are owned by the DETF,
     * but are no longer a target of the DETF strategy and therefore should be sold.
     * @param ownedAssetsList is the list of tokens owned by the DETF.
     * @param targetAssetsList is the list of tokens that are currently a target
     * for the DETF strategy.
     * @return sellList is the list of tokens to sell.
     */
    function createSellList(
        address[] memory ownedAssetsList,
        uint256[] memory ownedAssetsPrices,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory, uint256[] memory) {
        require(
            ownedAssetsList.length == ownedAssetsPrices.length,
            "Price information incorrect"
        );
        SellListData memory data;

        data.sellList = new address[](ownedAssetsList.length);
        data.sellListPrices = new uint256[](ownedAssetsPrices.length);

        if (targetAssetsList.length == 0) {
            data.sellList = ownedAssetsList;
            data.sellListPrices = ownedAssetsPrices;
        } else {
            uint256 index = 0;
            for (uint256 i = 0; i < ownedAssetsList.length; i++) {
                for (uint256 x = 0; x < targetAssetsList.length; x++) {
                    if (ownedAssetsList[i] == targetAssetsList[x]) {
                        ownedAssetsList[i] = address(0);
                    }
                }
            }
            uint256 resultCount = 0;
            for (uint256 i = 0; i < ownedAssetsList.length; i++) {
                if (ownedAssetsList[i] != address(0)) {
                    resultCount++;
                }
            }

            data.sellList = new address[](resultCount);
            data.sellListPrices = new uint256[](resultCount);

            for (uint256 i = 0; i < ownedAssetsList.length; i++) {
                if (ownedAssetsList[i] != address(0)) {
                    data.sellList[index] = ownedAssetsList[i];
                    data.sellListPrices[index] = ownedAssetsPrices[i];
                    index++;
                }
            }
        }

        return (data.sellList, data.sellListPrices);
    }

    struct AdjustListData {
        address[] adjustAssets;
        uint256[] adjustAssetsWeights;
        uint256[] adjustAssetsPrices;
        address[] adjustList;
        uint256[] adjustListWeights;
        uint256[] adjustListPrices;
    }

    /**
     * @notice Used to create a list of tokens that are owned by the DETF,
     * and are still a target of the DETF and therefore should be adjusted
     * to ensure the owned percentage is equal to the target percentage.
     * @param ownedAssetsList is the list of tokens owned by the DETF.
     * @param targetAssetsList is the list of tokens that are currently a target
     * for the DETF strategy.
     * @return adjustList is the list of tokens to adjust.
     */
    function createAdjustList(
        address[] memory ownedAssetsList,
        uint256[] memory ownedAssetsPrices,
        address[] memory targetAssetsList,
        uint256[] memory targetAssetsWeights
    )
        external
        pure
        returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        require(
            ownedAssetsList.length == ownedAssetsPrices.length,
            "Owned price information incorrect"
        );
        require(
            targetAssetsList.length == targetAssetsWeights.length,
            "Target weight information incorrect"
        );
        AdjustListData memory data;

        data.adjustAssets = new address[](ownedAssetsList.length);
        data.adjustAssetsWeights = new uint256[](ownedAssetsList.length);
        data.adjustAssetsPrices = new uint256[](ownedAssetsList.length);

        uint256 index = 0;
        for (uint256 i = 0; i < ownedAssetsList.length; i++) {
            for (uint256 x = 0; x < targetAssetsList.length; x++) {
                if (ownedAssetsList[i] == targetAssetsList[x]) {
                    data.adjustAssets[index] = ownedAssetsList[i];
                    data.adjustAssetsWeights[index] = targetAssetsWeights[x];
                    data.adjustAssetsPrices[index] = ownedAssetsPrices[i];
                    index++;
                }
            }
        }

        uint256 resultCount = 0;
        for (uint256 i = 0; i < data.adjustAssets.length; i++) {
            if (data.adjustAssets[i] != address(0)) {
                resultCount++;
            }
        }

        data.adjustList = new address[](resultCount);
        data.adjustListWeights = new uint256[](resultCount);
        data.adjustListPrices = new uint256[](resultCount);

        index = 0;
        for (uint256 i = 0; i < data.adjustAssets.length; i++) {
            if (data.adjustAssets[i] != address(0)) {
                data.adjustList[index] = data.adjustAssets[i];
                data.adjustListWeights[index] = data.adjustAssetsWeights[i];
                data.adjustListPrices[index] = data.adjustAssetsPrices[i];
                index++;
            }
        }

        return (data.adjustList, data.adjustListWeights, data.adjustListPrices);
    }

    struct AdjustToSellData {
        address[] adjustToSellList;
        uint256[] adjustToSellWeights;
        uint256[] adjustToSellPrices;
        uint256 totalBalance;
        uint256 tokenBalanceInWeth;
        uint256 tokenBalancePercentage;
        uint256 tokenTargetPercentage;
        address[] filteredAdjustToSellList;
        uint256[] filteredAdjustToSellWeights;
        uint256[] filteredAdjustToSellPrices;
    }

    /**
     * @notice Used to split the tokens that need to be adjusted by selling.
     * @param detfAddress is the address of the DETF.
     * @param adjustList is the list of tokens to adjust.
     * @return adjustToSellList is the list of tokens to adjust by selling.
     */
    function createAdjustToSellList(
        address detfAddress,
        uint256 totalBalance,
        address[] memory adjustList,
        uint256[] memory adjustListWeights,
        uint256[] memory adjustListPrices
    )
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        require(
            adjustList.length == adjustListPrices.length,
            "Adjust List price information incorrect"
        );
        require(
            adjustList.length == adjustListWeights.length,
            "Adjust List weight information incorrect"
        );

        AdjustToSellData memory data;

        data.adjustToSellList = new address[](adjustList.length);
        data.adjustToSellWeights = new uint256[](adjustListWeights.length);
        data.adjustToSellPrices = new uint256[](adjustListPrices.length);

        uint256 index = 0;
        if (adjustList.length > 0) {
            index = 0;

            for (uint256 i = 0; i < adjustList.length; i++) {
                (, data.tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustList[i], adjustListPrices[i]);
                data.tokenBalancePercentage =
                    (10 ** 8 * data.tokenBalanceInWeth) /
                    /* data.totalBalance; */
                    totalBalance;
                data.tokenTargetPercentage = adjustListWeights[i];

                if (data.tokenBalancePercentage > data.tokenTargetPercentage) {
                    data.adjustToSellList[index] = adjustList[i];
                    data.adjustToSellWeights[index] = adjustListWeights[i];
                    data.adjustToSellPrices[index] = adjustListPrices[i];
                    index++;
                }
            }
        }

        uint256 resultCount = 0;
        for (uint256 i = 0; i < data.adjustToSellList.length; i++) {
            if (data.adjustToSellList[i] != address(0)) {
                resultCount++;
            }
        }

        //Remove empty items
        data.filteredAdjustToSellList = new address[](resultCount);
        data.filteredAdjustToSellWeights = new uint256[](resultCount);
        data.filteredAdjustToSellPrices = new uint256[](resultCount);

        index = 0;
        for (uint256 i = 0; i < data.adjustToSellList.length; i++) {
            if (data.adjustToSellList[i] != address(0)) {
                data.filteredAdjustToSellList[index] = data.adjustToSellList[i];
                data.filteredAdjustToSellWeights[index] = data
                    .adjustToSellWeights[i];
                data.filteredAdjustToSellPrices[index] = data
                    .adjustToSellPrices[i];
                index++;
            }
        }

        return (
            data.filteredAdjustToSellList,
            data.filteredAdjustToSellWeights,
            data.filteredAdjustToSellPrices
        );
    }

    struct AdjustToBuyData {
        address[] adjustToBuyList;
        uint256[] adjustToBuyWeights;
        uint256[] adjustToBuyPrices;
        uint256 totalBalance;
        uint256 tokenBalanceInWeth;
        uint256 tokenBalancePercentage;
        uint256 tokenTargetPercentage;
        address[] filteredAdjustToBuyList;
        uint256[] filteredAdjustToBuyWeights;
        uint256[] filteredAdjustToBuyPrices;
    }

    /**
     * @notice Used to split the tokens that need to be adjusted by buying.
     * @param detfAddress is the address of the DETF.
     * @param adjustList is the list of tokens to adjust.
     * @return adjustToBuyList is the list of tokens to adjust by buying.
     */
    function createAdjustToBuyList(
        address detfAddress,
        uint256 totalBalance,
        address[] memory adjustList,
        uint256[] memory adjustListWeights,
        uint256[] memory adjustListPrices
    )
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        require(
            adjustList.length == adjustListWeights.length,
            "Adjust List weight information incorrect"
        );
        require(
            adjustList.length == adjustListPrices.length,
            "Adjust List price information incorrect"
        );

        AdjustToBuyData memory data;

        data.adjustToBuyList = new address[](adjustList.length);
        data.adjustToBuyWeights = new uint256[](adjustListWeights.length);
        data.adjustToBuyPrices = new uint256[](adjustListPrices.length);

        uint256 index = 0;
        if (adjustList.length > 0) {
            index = 0;

            for (uint256 i = 0; i < adjustList.length; i++) {
                (, data.tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustList[i], adjustListPrices[i]);
                data.tokenBalancePercentage =
                    (10 ** 8 * data.tokenBalanceInWeth) /
                    /*data.totalBalance;*/
                    totalBalance;
                data.tokenTargetPercentage = adjustListWeights[i];

                if (data.tokenTargetPercentage > data.tokenBalancePercentage) {
                    data.adjustToBuyList[index] = adjustList[i];
                    data.adjustToBuyWeights[index] = adjustListWeights[i];
                    data.adjustToBuyPrices[index] = adjustListPrices[i];
                    index++;
                }
            }
        }

        uint256 resultCount = 0;
        for (uint256 i = 0; i < data.adjustToBuyList.length; i++) {
            if (data.adjustToBuyList[i] != address(0)) {
                resultCount++;
            }
        }

        //Remove empty items
        data.filteredAdjustToBuyList = new address[](resultCount);
        data.filteredAdjustToBuyWeights = new uint256[](resultCount);
        data.filteredAdjustToBuyPrices = new uint256[](resultCount);

        index = 0;
        for (uint256 i = 0; i < data.adjustToBuyList.length; i++) {
            if (data.adjustToBuyList[i] != address(0)) {
                data.filteredAdjustToBuyList[index] = data.adjustToBuyList[i];
                data.filteredAdjustToBuyWeights[index] = data
                    .adjustToBuyWeights[i];
                data.filteredAdjustToBuyPrices[index] = data.adjustToBuyPrices[
                    i
                ];
                index++;
            }
        }

        return (
            data.filteredAdjustToBuyList,
            data.filteredAdjustToBuyWeights,
            data.filteredAdjustToBuyPrices
        );
    }

    struct BuyListData {
        address[] buyList;
        uint256[] buyListWeights;
        uint256[] buyListPrices;
    }

    /**
     * @notice Used to create a list of tokens that are not owned by the DETF,
     * but are a target of the DETF strategy and therefore should be bought.
     * @param ownedAssetsList is the list of tokens owned by the DETF.
     * @param targetAssetsList is the list of tokens that are currently a target
     * for the DETF strategy.
     * @return buyList is the list of tokens to buy.
     */
    function createBuyList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList,
        uint256[] memory targetAssetsWeights,
        uint256[] memory targetAssetsPrices
    )
        external
        pure
        returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        require(
            targetAssetsList.length == targetAssetsWeights.length,
            "Target weight information incorrect"
        );
        require(
            targetAssetsList.length == targetAssetsPrices.length,
            "Target price information incorrect"
        );

        BuyListData memory data;

        data.buyList = new address[](targetAssetsList.length);
        data.buyListWeights = new uint256[](targetAssetsWeights.length);
        data.buyListPrices = new uint256[](targetAssetsPrices.length);

        if (ownedAssetsList.length == 0) {
            data.buyList = targetAssetsList;
            data.buyListWeights = targetAssetsWeights;
            data.buyListPrices = targetAssetsPrices;
        } else {
            uint256 index = 0;
            for (uint256 x = 0; x < targetAssetsList.length; x++) {
                for (uint256 i = 0; i < ownedAssetsList.length; i++) {
                    if (targetAssetsList[x] == ownedAssetsList[i]) {
                        targetAssetsList[x] = address(0);
                    }
                }
            }

            uint256 resultCount = 0;
            for (uint256 i = 0; i < targetAssetsList.length; i++) {
                if (targetAssetsList[i] != address(0)) {
                    resultCount++;
                }
            }

            data.buyList = new address[](resultCount);
            data.buyListWeights = new uint256[](resultCount);
            data.buyListPrices = new uint256[](resultCount);

            for (uint256 i = 0; i < targetAssetsList.length; i++) {
                if (targetAssetsList[i] != address(0)) {
                    data.buyList[index] = targetAssetsList[i];
                    data.buyListWeights[index] = targetAssetsWeights[i];
                    data.buyListPrices[index] = targetAssetsPrices[i];
                    index++;
                }
            }
        }

        return (data.buyList, data.buyListWeights, data.buyListPrices);
    }

    struct TargetBuyPercentageData {
        uint256 totalTargetPercentage;
        uint256 totalBalance;
        uint256 tokenBalanceInWeth;
        uint256 tokenBalancePercentage;
        uint256 targetPercentage;
    }

    /**
     * @notice Get the total of target percentages to buy, then multiply each one
     * by the total amount of remaining WETH to get the precise amount to buy.
     * @param adjustToBuyList is the list of tokens to adjust by buying.
     * @param buyList is the list of tokens to buy.
     * @param detfAddress is the address of the DETF.
     * @return totalTargetPercentage is the percetage of the total target amount.
     */
    function calcTotalTargetBuyPercentage(
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustToBuyList,
        uint256[] memory adjustToBuyWeights,
        uint256[] memory adjustToBuyPrices,
        address[] memory buyList,
        uint256[] memory buyListWeights,
        address detfAddress
    ) external view returns (uint256) {
        TargetBuyPercentageData memory data;

        data.totalTargetPercentage = 0;
        data.totalBalance = IPolybitDETF(detfAddress).getTotalBalanceInWeth(
            ownedAssetsPrices
        );

        for (uint256 i = 0; i < adjustToBuyList.length; i++) {
            if (adjustToBuyList[i] != address(0)) {
                (, data.tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustToBuyList[i], adjustToBuyPrices[i]);
                data.tokenBalancePercentage =
                    (10 ** 8 * data.tokenBalanceInWeth) /
                    data.totalBalance;
                data.targetPercentage = adjustToBuyWeights[i];
                data.totalTargetPercentage += (data.targetPercentage -
                    data.tokenBalancePercentage);
            }
        }

        for (uint256 i = 0; i < buyList.length; i++) {
            if (buyList[i] != address(0)) {
                data.targetPercentage = buyListWeights[i];
                data.totalTargetPercentage += data.targetPercentage;
            }
        }

        return data.totalTargetPercentage;
    }

    struct SellOrderData {
        uint256[] sellListAmountsIn;
        uint256[] sellListAmountsOut;
        uint256 tokenBalance;
        uint256 tokenBalanceInWeth;
    }

    /**
     * @notice Creates a sell order to be passed into the Router to sell tokens.
     * @param sellList is the list of tokens to sell.
     * @param detfAddress is the address of the DETF.
     * @return sellListAmountsIn is the list of amounts in for the sell orders.
     * @return sellListAmountsOut is the list of amounts out for the sell orders.
     */
    function createSellOrder(
        address[] memory sellList,
        uint256[] memory sellListPrices,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        SellOrderData memory data;

        data.sellListAmountsIn = new uint256[](sellList.length);
        data.sellListAmountsOut = new uint256[](sellList.length);

        uint256 index = 0;
        for (uint256 i = 0; i < sellList.length; i++) {
            (data.tokenBalance, data.tokenBalanceInWeth) = IPolybitDETF(
                detfAddress
            ).getTokenBalance(sellList[i], sellListPrices[i]);

            data.sellListAmountsIn[index] = data.tokenBalance;
            data.sellListAmountsOut[index] = data.tokenBalanceInWeth;
            index++;
        }

        return (data.sellListAmountsIn, data.sellListAmountsOut);
    }

    struct AdjustToSellOrderData {
        uint256[] adjustToSellListAmountsIn;
        uint256[] adjustToSellListAmountsOut;
        uint256 totalBalance;
        uint256 tokenBalance;
        uint256 tokenPrice;
        uint256 tokenBalanceInWeth;
        uint256 tokenBalancePercentage;
        uint256 tokenTargetPercentage;
        uint256 targetPercentage;
        uint256 amountIn;
        uint256 amountOut;
    }

    /**
     * @notice Creates a sell order to be passed into the Router to sell tokens.
     * @param adjustToSellList is the list of tokens to adjust by selling.
     * @param detfAddress is the address of the DETF.
     * @return adjustToSellListAmountsIn is the list of amounts in for the adjust
     * to sell orders.
     * @return adjustToSellListAmountsOut is the list of amounts out for the adjust
     * to sell orders.
     */
    function createAdjustToSellOrder(
        uint256[] memory ownedAssetsPrices,
        address[] memory adjustToSellList,
        uint256[] memory adjustToSellWeights,
        uint256[] memory adjustToSellPrices,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        AdjustToSellOrderData memory data;

        data.adjustToSellListAmountsIn = new uint256[](adjustToSellList.length);
        data.adjustToSellListAmountsOut = new uint256[](
            adjustToSellList.length
        );
        data.totalBalance = IPolybitDETF(detfAddress).getTotalBalanceInWeth(
            ownedAssetsPrices
        );

        uint256 index = 0;
        for (uint256 i = 0; i < adjustToSellList.length; i++) {
            if (adjustToSellList[i] != address(0)) {
                (data.tokenBalance, data.tokenBalanceInWeth) = IPolybitDETF(
                    detfAddress
                ).getTokenBalance(adjustToSellList[i], adjustToSellPrices[i]);
                data.tokenBalancePercentage =
                    (10 ** 8 * data.tokenBalanceInWeth) /
                    data.totalBalance;
                data.tokenTargetPercentage = adjustToSellWeights[i];
                data.amountIn =
                    data.tokenBalance -
                    (data.tokenBalance * data.tokenTargetPercentage) /
                    data.tokenBalancePercentage;
                data.amountOut =
                    data.tokenBalanceInWeth -
                    (data.tokenBalanceInWeth * data.tokenTargetPercentage) /
                    data.tokenBalancePercentage;
                data.adjustToSellListAmountsIn[index] = data.amountIn;
                data.adjustToSellListAmountsOut[index] = data.amountOut;
                index++;
            }
        }

        return (
            data.adjustToSellListAmountsIn,
            data.adjustToSellListAmountsOut
        );
    }

    struct AdjustToBuyOrderData {
        uint256[] adjustToBuyListAmountsIn;
        uint256[] adjustToBuyListAmountsOut;
        uint256 tokenPrice;
        uint256 tokenBalanceInWeth;
        uint256 targetPercentage;
        uint256 percentageOfAvailableWeth;
        uint256 precisionAmountIn;
        uint256 amountOut;
    }

    /**
     * @notice Creates a buy order to be passed into the Router to buy tokens.
     * @param adjustToBuyList is the list of tokens to adjust by buying.
     * @param detfAddress is the address of the DETF.
     * @return adjustToBuyListAmountsIn is the list of amounts in for the adjust
     * to buy orders.
     * @return adjustToBuyListAmountsOut is the list of amounts out for the adjust
     * to buy orders.
     * @dev percentages are calculated to 6 decimals places using 10**8
     */
    function createAdjustToBuyOrder(
        uint256 totalBalance,
        uint256 wethBalance,
        address[] memory adjustToBuyList,
        uint256[] memory adjustToBuyWeights,
        uint256[] memory adjustToBuyPrices,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        AdjustToBuyOrderData memory data;

        data.adjustToBuyListAmountsIn = new uint256[](adjustToBuyList.length);
        data.adjustToBuyListAmountsOut = new uint256[](adjustToBuyList.length);

        uint256 index = 0;
        for (uint256 i = 0; i < adjustToBuyList.length; i++) {
            if (adjustToBuyList[i] != address(0)) {
                data.tokenPrice = adjustToBuyPrices[i];
                (, data.tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustToBuyList[i], adjustToBuyPrices[i]);
                data.targetPercentage =
                    adjustToBuyWeights[i] -
                    ((10 ** 8 * data.tokenBalanceInWeth) / totalBalance);
                data.percentageOfAvailableWeth =
                    (10 ** 8 * data.targetPercentage) /
                    totalTargetPercentage;
                data.precisionAmountIn =
                    (wethBalance * data.percentageOfAvailableWeth) /
                    10 ** 8;
                data.amountOut =
                    (10 ** 18 * data.precisionAmountIn) /
                    data.tokenPrice;
                data.adjustToBuyListAmountsIn[index] = data.precisionAmountIn;
                data.adjustToBuyListAmountsOut[index] = data.amountOut;
                index++;
            }
        }

        return (data.adjustToBuyListAmountsIn, data.adjustToBuyListAmountsOut);
    }

    struct BuyOrderData {
        uint256[] buyListAmountsIn;
        uint256[] buyListAmountsOut;
        uint256 tokenPrice;
        uint256 tokenBalanceInWeth;
        uint256 targetPercentage;
        uint256 percentageOfAvailableWeth;
        uint256 precisionAmountIn;
        uint256 amountOut;
    }

    /**
     * @notice Creates a buy order to be passed into the Router to buy tokens.
     * @param buyList is the list of tokens to buy.
     * @return buyListAmountsIn is the list of amounts in for the buy orders.
     * @return buyListAmountsOut is the list of amounts out for the buy orders.
     * @dev percentages are calculated to 6 decimals places using 10**8
     */
    function createBuyOrder(
        address[] memory buyList,
        uint256[] memory buyListWeights,
        uint256[] memory buyListPrices,
        uint256 wethBalance,
        uint256 totalTargetPercentage
    ) external pure returns (uint256[] memory, uint256[] memory) {
        BuyOrderData memory data;

        data.buyListAmountsIn = new uint256[](buyList.length);
        data.buyListAmountsOut = new uint256[](buyList.length);

        uint256 index = 0;
        for (uint256 i = 0; i < buyList.length; i++) {
            data.tokenPrice = buyListPrices[i];
            data.targetPercentage = buyListWeights[i];
            data.percentageOfAvailableWeth =
                (10 ** 8 * data.targetPercentage) /
                totalTargetPercentage;
            data.precisionAmountIn =
                (wethBalance * data.percentageOfAvailableWeth) /
                10 ** 8;
            data.amountOut =
                (10 ** 18 * data.precisionAmountIn) /
                data.tokenPrice;
            data.buyListAmountsIn[index] = data.precisionAmountIn;
            data.buyListAmountsOut[index] = data.amountOut;
            index++;
        }

        return (data.buyListAmountsIn, data.buyListAmountsOut);
    }
}
