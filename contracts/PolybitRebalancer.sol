// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitPriceOracle.sol";
import "./interfaces/IPolybitDETFOracle.sol";
import "./interfaces/IPolybitDETF.sol";

contract PolybitRebalancer {
    string public rebalancerVersion;

    struct DETFInfo {
        address detfOracleAddress;
        address priceOracleAddress;
        string riskWeighting;
        uint256 tokenPrice;
        uint256 tokenBalance;
        uint256 tokenBalanceInWeth;
        uint256 targetPercentage;
    }

    constructor(string memory _rebalancerVersion) {
        rebalancerVersion = _rebalancerVersion;
    }

    // Output 1: items in owned that do not exist in target (SELL)
    function createSellList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory) {
        address[] memory sellList = new address[](ownedAssetsList.length);
        if (targetAssetsList.length == 0) {
            sellList = ownedAssetsList;
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

            sellList = new address[](resultCount);
            for (uint256 i = 0; i < ownedAssetsList.length; i++) {
                if (ownedAssetsList[i] != address(0)) {
                    sellList[index] = ownedAssetsList[i];
                    index++;
                }
            }
        }
        return sellList;
    }

    // Output 2: items in target that exist in owned (ADJUST)
    function createAdjustList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory) {
        address[] memory adjustAssets = new address[](ownedAssetsList.length);

        uint256 index = 0;
        for (uint256 i = 0; i < ownedAssetsList.length; i++) {
            for (uint256 x = 0; x < targetAssetsList.length; x++) {
                if (ownedAssetsList[i] == targetAssetsList[x]) {
                    adjustAssets[index] = ownedAssetsList[i];
                    index++;
                }
            }
        }
        uint256 resultCount = 0;
        for (uint256 i = 0; i < adjustAssets.length; i++) {
            if (adjustAssets[i] != address(0)) {
                resultCount++;
            }
        }

        address[] memory adjustList = new address[](resultCount);
        index = 0;

        for (uint256 i = 0; i < adjustAssets.length; i++) {
            if (adjustAssets[i] != address(0)) {
                adjustList[index] = adjustAssets[i];
                index++;
            }
        }

        return adjustList;
    }

    function createAdjustToSellList(
        address detfAddress,
        address[] memory adjustList
    ) external view returns (address[] memory) {
        address[] memory adjustToSellList = new address[](adjustList.length);

        if (adjustList.length > 0) {
            address detfOracleAddress = IPolybitDETF(detfAddress)
                .getDETFOracleAddress();

            uint256 adjustToSellListIndex = 0;
            uint256 totalBalance = IPolybitDETF(detfAddress)
                .getTotalBalanceInWeth();

            for (uint256 i = 0; i < adjustList.length; i++) {
                (, uint256 tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustList[i]);
                uint256 tokenBalancePercentage = (10**6 * tokenBalanceInWeth) /
                    totalBalance;
                uint256 tokenTargetPercentage = IPolybitDETFOracle(
                    detfOracleAddress
                ).getTargetPercentage(
                        adjustList[i],
                        IPolybitDETF(detfAddress).getRiskWeighting()
                    );

                if (tokenBalancePercentage > tokenTargetPercentage) {
                    adjustToSellList[adjustToSellListIndex] = adjustList[i];
                    adjustToSellListIndex++;
                }
            }
        }

        return adjustToSellList;
    }

    function createAdjustToBuyList(
        address detfAddress,
        address[] memory adjustList
    ) external view returns (address[] memory) {
        address[] memory adjustToBuyList = new address[](adjustList.length);

        if (adjustList.length > 0) {
            address detfOracleAddress = IPolybitDETF(detfAddress)
                .getDETFOracleAddress();

            uint256 adjustToBuyListIndex = 0;
            uint256 totalBalance = IPolybitDETF(detfAddress)
                .getTotalBalanceInWeth();

            for (uint256 i = 0; i < adjustList.length; i++) {
                (, uint256 tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustList[i]);
                uint256 tokenBalancePercentage = (10**6 * tokenBalanceInWeth) /
                    totalBalance;
                uint256 tokenTargetPercentage = IPolybitDETFOracle(
                    detfOracleAddress
                ).getTargetPercentage(
                        adjustList[i],
                        IPolybitDETF(detfAddress).getRiskWeighting()
                    );
                if (tokenTargetPercentage > tokenBalancePercentage) {
                    adjustToBuyList[adjustToBuyListIndex] = adjustList[i];
                    adjustToBuyListIndex++;
                }
            }
        }

        return adjustToBuyList;
    }

    // Output 3: items in target that do not exist in owned (BUY)
    function createBuyList(
        address[] memory ownedAssetsList,
        address[] memory targetAssetsList
    ) external pure returns (address[] memory) {
        address[] memory buyList = new address[](targetAssetsList.length);
        if (ownedAssetsList.length == 0) {
            buyList = targetAssetsList;
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

            buyList = new address[](resultCount);
            for (uint256 i = 0; i < targetAssetsList.length; i++) {
                if (targetAssetsList[i] != address(0)) {
                    buyList[index] = targetAssetsList[i];
                    index++;
                }
            }
        }
        return buyList;
    }

    // Get the total of target percentages to buy, then multiply each one by the
    // total amount of remaing WETH to get the precise amount
    function calcTotalTargetBuyPercentage(
        address[] memory adjustToBuyList,
        address[] memory buyList,
        address detfAddress
    ) external view returns (uint256, uint256) {
        uint256 totalTargetPercentage = 0;
        uint256 wethBalance = IPolybitDETF(detfAddress).getWethBalance();
        uint256 totalBalance = IPolybitDETF(detfAddress)
            .getTotalBalanceInWeth();
        address detfOracleAddress = IPolybitDETF(detfAddress)
            .getDETFOracleAddress();
        string memory riskWeighting = IPolybitDETF(detfAddress)
            .getRiskWeighting();

        for (uint256 i = 0; i < adjustToBuyList.length; i++) {
            if (adjustToBuyList[i] != address(0)) {
                (, uint256 tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustToBuyList[i]);
                uint256 tokenBalancePercentage = (10**6 * tokenBalanceInWeth) /
                    totalBalance;
                uint256 targetPercentage = IPolybitDETFOracle(detfOracleAddress)
                    .getTargetPercentage(adjustToBuyList[i], riskWeighting);
                totalTargetPercentage += (targetPercentage -
                    tokenBalancePercentage);
            }
        }

        for (uint256 i = 0; i < buyList.length; i++) {
            if (buyList[i] != address(0)) {
                uint256 targetPercentage = IPolybitDETFOracle(detfOracleAddress)
                    .getTargetPercentage(buyList[i], riskWeighting);
                totalTargetPercentage += targetPercentage;
            }
        }

        return (wethBalance, totalTargetPercentage);
    }

    function createSellOrder(address[] memory sellList, address detfAddress)
        external
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint256[] memory sellListAmountsIn = new uint256[](sellList.length);
        uint256[] memory sellListAmountsOut = new uint256[](sellList.length);
        uint8 index = 0;

        for (uint256 i = 0; i < sellList.length; i++) {
            (uint256 tokenBalance, uint256 tokenBalanceInWeth) = IPolybitDETF(
                detfAddress
            ).getTokenBalance(sellList[i]);

            sellListAmountsIn[index] = tokenBalance;
            sellListAmountsOut[index] = tokenBalanceInWeth;
            index++;
        }
        return (sellListAmountsIn, sellListAmountsOut);
    }

    function createAdjustToSellOrder(
        address[] memory adjustToSellList,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        DETFInfo memory info;

        info.detfOracleAddress = IPolybitDETF(detfAddress)
            .getDETFOracleAddress();
        info.priceOracleAddress = address(0);
        info.riskWeighting = "";
        info.tokenPrice = 0;
        info.tokenBalance = 0;
        info.tokenBalanceInWeth = 0;
        info.targetPercentage = 0;

        uint256[] memory adjustToSellListAmountsIn = new uint256[](
            adjustToSellList.length
        );
        uint256[] memory adjustToSellListAmountsOut = new uint256[](
            adjustToSellList.length
        );
        uint8 index = 0;

        uint256 totalBalance = IPolybitDETF(detfAddress)
            .getTotalBalanceInWeth();

        for (uint256 i = 0; i < adjustToSellList.length; i++) {
            if (adjustToSellList[i] != address(0)) {
                info.detfOracleAddress = IPolybitDETF(detfAddress)
                    .getDETFOracleAddress();
                info.priceOracleAddress = IPolybitDETFOracle(
                    info.detfOracleAddress
                ).getPriceOracleAddress(adjustToSellList[i]);
                info.riskWeighting = IPolybitDETF(detfAddress)
                    .getRiskWeighting();
                (
                    uint256 tokenBalance,
                    uint256 tokenBalanceInWeth
                ) = IPolybitDETF(detfAddress).getTokenBalance(
                        adjustToSellList[i]
                    );
                uint256 tokenBalancePercentage = (10**6 * tokenBalanceInWeth) /
                    totalBalance;
                uint256 tokenTargetPercentage = IPolybitDETFOracle(
                    info.detfOracleAddress
                ).getTargetPercentage(adjustToSellList[i], info.riskWeighting);
                uint256 amountIn = tokenBalance -
                    (tokenBalance * tokenTargetPercentage) /
                    tokenBalancePercentage;
                uint256 amountOut = tokenBalanceInWeth -
                    (tokenBalanceInWeth * tokenTargetPercentage) /
                    tokenBalancePercentage;

                adjustToSellListAmountsIn[index] = amountIn;
                adjustToSellListAmountsOut[index] = amountOut;
                index++;
            }
        }
        return (adjustToSellListAmountsIn, adjustToSellListAmountsOut);
    }

    function createAdjustToBuyOrder(
        uint256 totalBalance,
        address[] memory adjustToBuyList,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        DETFInfo memory info;

        uint256[] memory adjustToBuyListAmountsIn = new uint256[](
            adjustToBuyList.length
        );
        uint256[] memory adjustToBuyListAmountsOut = new uint256[](
            adjustToBuyList.length
        );
        uint8 index = 0;

        for (uint256 i = 0; i < adjustToBuyList.length; i++) {
            if (adjustToBuyList[i] != address(0)) {
                info.detfOracleAddress = IPolybitDETF(detfAddress)
                    .getDETFOracleAddress();
                info.priceOracleAddress = IPolybitDETFOracle(
                    info.detfOracleAddress
                ).getPriceOracleAddress(adjustToBuyList[i]);
                info.riskWeighting = IPolybitDETF(detfAddress)
                    .getRiskWeighting();
                info.tokenPrice = IPolybitPriceOracle(info.priceOracleAddress)
                    .getLatestPrice();
                (, info.tokenBalanceInWeth) = IPolybitDETF(detfAddress)
                    .getTokenBalance(adjustToBuyList[i]);
                info.targetPercentage =
                    IPolybitDETFOracle(info.detfOracleAddress)
                        .getTargetPercentage(
                            adjustToBuyList[i],
                            info.riskWeighting
                        ) -
                    ((10**6 * info.tokenBalanceInWeth) / totalBalance);

                uint256 percentageOfAvailableWeth = (10**6 *
                    info.targetPercentage) / totalTargetPercentage;
                uint256 precisionAmountIn = (IPolybitDETF(detfAddress)
                    .getWethBalance() * percentageOfAvailableWeth) / 10**6;
                uint256 amountOut = (10**18 * precisionAmountIn) /
                    info.tokenPrice;

                adjustToBuyListAmountsIn[index] = precisionAmountIn;
                adjustToBuyListAmountsOut[index] = amountOut;
                index++;
            }
        }
        return (adjustToBuyListAmountsIn, adjustToBuyListAmountsOut);
    }

    function createBuyOrder(
        address[] memory buyList,
        uint256 wethBalance,
        uint256 totalTargetPercentage,
        address detfAddress
    ) external view returns (uint256[] memory, uint256[] memory) {
        DETFInfo memory info;

        uint256[] memory buyListAmountsIn = new uint256[](buyList.length);
        uint256[] memory buyListAmountsOut = new uint256[](buyList.length);
        uint8 index = 0;

        for (uint256 i = 0; i < buyList.length; i++) {
            info.detfOracleAddress = IPolybitDETF(detfAddress)
                .getDETFOracleAddress();
            info.priceOracleAddress = IPolybitDETFOracle(info.detfOracleAddress)
                .getPriceOracleAddress(buyList[i]);
            info.riskWeighting = IPolybitDETF(detfAddress).getRiskWeighting();
            info.tokenPrice = IPolybitPriceOracle(info.priceOracleAddress)
                .getLatestPrice();
            info.targetPercentage = IPolybitDETFOracle(info.detfOracleAddress)
                .getTargetPercentage(buyList[i], info.riskWeighting);
            uint256 percentageOfAvailableWeth = (10**6 *
                info.targetPercentage) / totalTargetPercentage;
            uint256 precisionAmountIn = (wethBalance *
                percentageOfAvailableWeth) / 10**6;
            uint256 amountOut = (10**18 * precisionAmountIn) / info.tokenPrice;

            buyListAmountsIn[index] = precisionAmountIn;
            buyListAmountsOut[index] = amountOut;
            index++;
        }
        return (buyListAmountsIn, buyListAmountsOut);
    }
}
