// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitPriceOracle.sol";
import "./interfaces/IPolybitDETFOracle.sol";
import "./interfaces/IPolybitRebalancer.sol";
import "./interfaces/IPolybitRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

contract PolybitDETF {
    address public owner;
    address public detfOracleAddress;
    address public rebalancerAddress;
    string public riskWeighting;
    address[] internal ownedAssets;
    uint256 public totalDeposited = 0;
    address public wethAddress;
    IWETH wethToken;
    address internal polybitRouterAddress;
    IPolybitRouter polybitRouter;

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    constructor(
        address _detfOracleAddress,
        string memory _riskWeighting,
        address _rebalancerAddress,
        address _wethAddress,
        address _polybitRouterAddress
    ) {
        detfOracleAddress = _detfOracleAddress;
        riskWeighting = _riskWeighting;
        rebalancerAddress = _rebalancerAddress;
        wethAddress = _wethAddress;
        wethToken = IWETH(wethAddress);
        polybitRouterAddress = _polybitRouterAddress;
        polybitRouter = IPolybitRouter(polybitRouterAddress);
    }

    function getDETFOracleAddress() public view returns (address) {
        return detfOracleAddress;
    }

    function getRiskWeighting() external view returns (string memory) {
        return riskWeighting;
    }

    function changeRiskWeighting(uint8 _riskWeighting) external {
        require(
            _riskWeighting == 0 || _riskWeighting == 1,
            "Incorrect input for Risk Weighting. Try 0 (rwEquallyBalanced) or 1 (rwLiquidity)."
        );
        if (_riskWeighting == 0) {
            riskWeighting = "rwEquallyBalanced";
        }
        if (_riskWeighting == 1) {
            riskWeighting = "rwLiquidity";
        }
    }

    function getOwnedAssets() public view returns (address[] memory) {
        return ownedAssets;
    }

    function getTargetAssets() public view returns (address[] memory) {
        address[] memory targetList = IPolybitDETFOracle(detfOracleAddress)
            .getTargetList();
        return targetList;
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getWethBalance() public view returns (uint256) {
        return IERC20(wethAddress).balanceOf(address(this));
    }

    function getTokenBalance(address tokenAddress)
        public
        view
        returns (uint256, uint256)
    {
        IERC20 assetToken = IERC20(tokenAddress);
        address priceOracleAddress = IPolybitDETFOracle(detfOracleAddress)
            .getPriceOracleAddress(tokenAddress);
        uint256 tokenBalance = assetToken.balanceOf(address(this));
        uint256 tokenDecimals = IPolybitPriceOracle(priceOracleAddress)
            .getDecimals();
        uint256 tokenPrice = IPolybitPriceOracle(priceOracleAddress)
            .getLatestPrice();
        uint256 tokenBalanceInWeth = (tokenBalance * tokenPrice) /
            10**tokenDecimals;
        return (tokenBalance, tokenBalanceInWeth);
    }

    function getTotalBalanceInWeth() public view returns (uint256) {
        uint256 tokenBalances = 0;
        if (ownedAssets.length > 0) {
            for (uint256 x = 0; x < ownedAssets.length; x++) {
                (, uint256 tokenBalanceInWeth) = getTokenBalance(
                    ownedAssets[x]
                );
                tokenBalances = tokenBalances + tokenBalanceInWeth;
            }
        }
        uint256 totalBalance = tokenBalances +
            getEthBalance() +
            getWethBalance();
        return totalBalance;
    }

    function getRebalancerLists()
        internal
        view
        returns (
            address[] memory,
            address[] memory,
            address[] memory,
            address[] memory
        )
    {
        address[] memory targetList = IPolybitDETFOracle(detfOracleAddress)
            .getTargetList();
        address[] memory sellList = IPolybitRebalancer(rebalancerAddress)
            .createSellList(ownedAssets, targetList);
        address[] memory adjustList = IPolybitRebalancer(rebalancerAddress)
            .createAdjustList(ownedAssets, targetList);
        address[] memory adjustToSellList = IPolybitRebalancer(
            rebalancerAddress
        ).createAdjustToSellList(address(this), adjustList);
        address[] memory adjustToBuyList = IPolybitRebalancer(rebalancerAddress)
            .createAdjustToBuyList(address(this), adjustList);
        address[] memory buyList = IPolybitRebalancer(rebalancerAddress)
            .createBuyList(ownedAssets, targetList);
        return (sellList, adjustToSellList, adjustToBuyList, buyList);
    }

    event RebalancerList(string msg, address[]);
    event ListAmounts(string msg, address[], uint256[]);
    event ListLength(string msg, uint256);

    function rebalance() external {
        emit RebalancerList("Owned", getOwnedAssets());
        emit RebalancerList(
            "Target",
            IPolybitDETFOracle(detfOracleAddress).getTargetList()
        );

        /* require(detfStatus != 2, "DETF has been closed by the owner.");
        // Set DETF status to active on first use
        if (detfStatus == 0) {
            detfStatus = 1;
        } */
        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            totalDeposited = ethBalance + totalDeposited;
            wrapETH();
            //processFee(getWethBalance(), depositFee, depositFeeAddress);
        }

        uint256 totalBalance = getTotalBalanceInWeth();
        require(totalBalance > 0, "No tokens to swap.");

        (
            address[] memory sellList,
            address[] memory adjustToSellList,
            address[] memory adjustToBuyList,
            address[] memory buyList
        ) = getRebalancerLists();

        emit RebalancerList("Sell List", sellList);
        emit RebalancerList("Adjust To Sell List", adjustToSellList);
        emit RebalancerList("Adjust To Buy List", adjustToBuyList);
        emit RebalancerList("Buy List", buyList);

        if (sellList.length > 0) {
            (
                uint256[] memory sellListAmountsIn,
                uint256[] memory sellListAmountsOut
            ) = IPolybitRebalancer(rebalancerAddress).createSellOrder(
                    sellList,
                    address(this)
                );
            emit ListAmounts("Sell List In", sellList, sellListAmountsIn);
            emit ListAmounts("Sell List Out", sellList, sellListAmountsOut);
            emit ListLength("Sell list length", sellList.length);
            for (uint256 i = 0; i < sellList.length; i++) {
                if (sellList[i] != address(0)) {
                    swapWithLiquidPath(
                        sellList[i],
                        wethAddress,
                        sellListAmountsIn[i],
                        sellListAmountsOut[i]
                    );
                }
            }
        }

        // Reset ownedAssets to be an empty array
        delete ownedAssets;

        // Add assets in adjustToSellList to ownedAssets
        for (uint256 i = 0; i < adjustToSellList.length; i++) {
            if (adjustToSellList[i] != address(0)) {
                ownedAssets.push(adjustToSellList[i]);
            }
        }

        // Add assets in adjustToBuyList to ownedAssets
        for (uint256 i = 0; i < adjustToBuyList.length; i++) {
            if (adjustToBuyList[i] != address(0)) {
                ownedAssets.push(adjustToBuyList[i]);
            }
        }

        // Add assets in buyList to ownedAssets
        for (uint256 i = 0; i < buyList.length; i++) {
            if (buyList[i] != address(0)) {
                ownedAssets.push(buyList[i]);
            }
        }

        if (adjustToSellList.length > 0) {
            (
                uint256[] memory adjustToSellListAmountsIn,
                uint256[] memory adjustToSellListAmountsOut
            ) = IPolybitRebalancer(rebalancerAddress).createAdjustToSellOrder(
                    adjustToSellList,
                    address(this)
                );
            emit ListAmounts(
                "Adjust To Sell List In",
                adjustToSellList,
                adjustToSellListAmountsIn
            );
            emit ListAmounts(
                "Adjust To Sell List Out",
                adjustToSellList,
                adjustToSellListAmountsOut
            );
            for (uint256 i = 0; i < adjustToSellList.length; i++) {
                if (adjustToSellList[i] != address(0)) {
                    swapWithLiquidPath(
                        adjustToSellList[i],
                        wethAddress,
                        adjustToSellListAmountsIn[i],
                        adjustToSellListAmountsOut[i]
                    );
                }
            }
        }

        // Begin buy orders
        (
            uint256 wethBalance,
            uint256 totalTargetPercentage
        ) = IPolybitRebalancer(rebalancerAddress).calcTotalTargetBuyPercentage(
                adjustToBuyList,
                buyList,
                address(this)
            );

        totalBalance = getTotalBalanceInWeth();

        if (adjustToBuyList.length > 0) {
            (
                uint256[] memory adjustToBuyListAmountsIn,
                uint256[] memory adjustToBuyListAmountsOut
            ) = IPolybitRebalancer(rebalancerAddress).createAdjustToBuyOrder(
                    totalBalance,
                    adjustToBuyList,
                    totalTargetPercentage,
                    address(this)
                );
            emit ListAmounts(
                "Adjust To Buy List In",
                adjustToBuyList,
                adjustToBuyListAmountsIn
            );
            emit ListAmounts(
                "Adjust To Buy List Out",
                adjustToBuyList,
                adjustToBuyListAmountsOut
            );
            for (uint256 i = 0; i < adjustToBuyList.length; i++) {
                if (adjustToBuyList[i] != address(0)) {
                    swapWithLiquidPath(
                        wethAddress,
                        adjustToBuyList[i],
                        adjustToBuyListAmountsIn[i],
                        adjustToBuyListAmountsOut[i]
                    );
                }
            }
        }

        if (buyList.length > 0) {
            (
                uint256[] memory buyListAmountsIn,
                uint256[] memory buyListAmountsOut
            ) = IPolybitRebalancer(rebalancerAddress).createBuyOrder(
                    buyList,
                    wethBalance,
                    totalTargetPercentage,
                    address(this)
                );
            emit ListAmounts("Buy List In", buyList, buyListAmountsIn);
            emit ListAmounts("Buy List Out", buyList, buyListAmountsOut);
            for (uint256 i = 0; i < buyList.length; i++) {
                if (buyList[i] != address(0)) {
                    swapWithLiquidPath(
                        wethAddress,
                        buyList[i],
                        buyListAmountsIn[i],
                        buyListAmountsOut[i]
                    );
                }
            }
        }
    }

    receive() external payable {}

    fallback() external payable {}

    event EthWrap(string msg, uint256 amount);

    function wrapETH() public {
        uint256 ethBalance = getEthBalance();
        require(ethBalance > 0, "No ETH available to wrap");
        emit EthWrap("Wrapped ETH", ethBalance);
        wethToken.deposit{value: ethBalance}();
    }

    function unwrapETH() public {
        uint256 wethBalance = getWethBalance();
        require(wethBalance > 0, "No WETH available to unwrap");
        emit EthWrap("UnWrapped ETH", wethBalance);
        wethToken.approve(address(this), wethBalance);
        wethToken.withdraw(wethBalance);
    }

    function swapWithLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut
    ) internal {
        address recipient = address(this);
        IERC20 token = IERC20(tokenIn);
        require(
            token.approve(address(polybitRouterAddress), tokenAmountIn),
            "TOKEN approve failed"
        );
        polybitRouter.liquidPath(
            detfOracleAddress,
            tokenIn,
            tokenOut,
            tokenAmountIn,
            tokenAmountOut,
            recipient
        );
    }
}
