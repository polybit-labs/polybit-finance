// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitPriceOracle.sol";
import "./interfaces/IPolybitDETFOracle.sol";
import "./interfaces/IPolybitDETFOracleFactory.sol";
import "./interfaces/IPolybitRebalancer.sol";
import "./interfaces/IPolybitRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

contract PolybitDETF {
    address public owner;
    address public polybitDETFOracleAddress;
    IPolybitDETFOracle polybitDETFOracle;
    address public polybitDETFOracleFactoryAddress;
    IPolybitDETFOracleFactory polybitDETFOracleFactory;
    address public polybitRebalancerAddress;
    IPolybitRebalancer polybitRebalancer;
    address public polybitRouterAddress;
    IPolybitRouter polybitRouter;
    address internal wethAddress;
    IWETH wethToken;
    uint256 internal riskWeighting;
    address[] internal ownedAssets;
    uint256 public totalDeposited = 0;
    uint256 internal lastRebalance = 0;
    uint256 internal constant rebalancePeriods = 1 * 60; //90 * 86400;
    uint256 internal unlockTime;
    uint256 public valueAtClose;
    uint256 internal detfStatus = 0; //Set status to inactive (0 = inactive, 1 = active, 2 = closed)

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    constructor(
        address _polybitDETFOracleAddress,
        address _polybitDETFOracleFactoryAddress,
        uint256 _riskWeighting,
        address _polybitRebalancerAddress,
        address _polybitRouterAddress,
        uint256 _lockDuration
    ) {
        require(address(_polybitDETFOracleAddress) != address(0));
        require(address(_polybitDETFOracleFactoryAddress) != address(0));
        require(address(_polybitRebalancerAddress) != address(0));
        require(address(_polybitRouterAddress) != address(0));
        polybitDETFOracleAddress = _polybitDETFOracleAddress;
        polybitDETFOracle = IPolybitDETFOracle(polybitDETFOracleAddress);
        polybitDETFOracleFactoryAddress = _polybitDETFOracleFactoryAddress;
        polybitDETFOracleFactory = IPolybitDETFOracleFactory(
            polybitDETFOracleFactoryAddress
        );
        polybitRebalancerAddress = _polybitRebalancerAddress;
        polybitRebalancer = IPolybitRebalancer(polybitRebalancerAddress);
        polybitRouterAddress = _polybitRouterAddress;
        polybitRouter = IPolybitRouter(polybitRouterAddress);
        riskWeighting = _riskWeighting;
        wethAddress = polybitRouter.getWethAddress();
        wethToken = IWETH(wethAddress);
        unlockTime = block.timestamp + _lockDuration;
        require(
            block.timestamp < unlockTime,
            "Unlock time should be in the future"
        );
    }

    receive() external payable {}

    fallback() external payable {}

    function getDETFOracleAddress() external view returns (address) {
        return polybitDETFOracleAddress;
    }

    function setPolybitRebalancerAddress(address rebalancerAddress) external {
        require(address(rebalancerAddress) != address(0));
        polybitRebalancerAddress = rebalancerAddress;
    }

    function setPolybitRouterAddress(address routerAddress) external {
        require(address(routerAddress) != address(0));
        polybitRouterAddress = routerAddress;
    }

    function setRiskWeighting(uint8 riskWeightingSelector) external {
        require(
            riskWeightingSelector == 0 || riskWeightingSelector == 1,
            "Incorrect input for Risk Weighting. Try 0 (rwEquallyBalanced) or 1 (rwLiquidity)."
        );
        if (riskWeightingSelector == 0) {
            riskWeighting = 0;
        }
        if (riskWeightingSelector == 1) {
            riskWeighting = 1;
        }
    }

    function getRiskWeighting() external view returns (uint256) {
        return riskWeighting;
    }

    function getLockTimeLeft() external view returns (uint256) {
        if (unlockTime > block.timestamp) {
            return unlockTime - block.timestamp;
        } else {
            return uint256(0);
        }
    }

    function processFee(
        uint256 inputAmount,
        uint256 fee,
        address feeAddress
    ) internal {
        uint256 feeAmount = (inputAmount * fee) / 10000;
        uint256 cachedFeeAmount = feeAmount;
        feeAmount = 0;
        IERC20(wethAddress).safeTransfer(feeAddress, cachedFeeAmount);
    }

    function getOwnedAssets() public view returns (address[] memory) {
        return ownedAssets;
    }

    function getTargetAssets() external view returns (address[] memory) {
        address[] memory targetList = polybitDETFOracle.getTargetList();
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
        address priceOracleAddress = polybitDETFOracle.getPriceOracleAddress(
            tokenAddress
        );
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
        address[] memory targetList = polybitDETFOracle.getTargetList();
        address[] memory sellList = polybitRebalancer.createSellList(
            ownedAssets,
            targetList
        );
        address[] memory adjustList = polybitRebalancer.createAdjustList(
            ownedAssets,
            targetList
        );
        address[] memory adjustToSellList = polybitRebalancer
            .createAdjustToSellList(address(this), adjustList);
        address[] memory adjustToBuyList = polybitRebalancer
            .createAdjustToBuyList(address(this), adjustList);
        address[] memory buyList = polybitRebalancer.createBuyList(
            ownedAssets,
            targetList
        );
        return (sellList, adjustToSellList, adjustToBuyList, buyList);
    }

    function getLastRebalance() external view returns (uint256) {
        return lastRebalance;
    }

    event Deposited(string msg, uint256 ref);

    function rebalance() external {
        require(detfStatus != 2, "DETF has been closed by the owner.");
        // Set DETF status to active on first use
        if (detfStatus == 0) {
            detfStatus = 1;
        }
        //require current time is >= lastRebalance + rebalancePeriods
        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            totalDeposited = ethBalance + totalDeposited;
            emit Deposited("Deposited ETH into DETF", ethBalance);
            wrapETH();
            processFee(
                getWethBalance(),
                polybitDETFOracleFactory.getDepositFee(),
                polybitDETFOracleFactory.getFeeAddress()
            );
        }
        lastRebalance = block.timestamp;

        uint256 totalBalance = getTotalBalanceInWeth();
        require(totalBalance > 0, "No tokens to swap.");

        (
            address[] memory sellList,
            address[] memory adjustToSellList,
            address[] memory adjustToBuyList,
            address[] memory buyList
        ) = getRebalancerLists();

        if (sellList.length > 0) {
            (
                uint256[] memory sellListAmountsIn,
                uint256[] memory sellListAmountsOut
            ) = polybitRebalancer.createSellOrder(sellList, address(this));

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
            ) = polybitRebalancer.createAdjustToSellOrder(
                    adjustToSellList,
                    address(this)
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
        (uint256 wethBalance, uint256 totalTargetPercentage) = polybitRebalancer
            .calcTotalTargetBuyPercentage(
                adjustToBuyList,
                buyList,
                address(this)
            );

        totalBalance = getTotalBalanceInWeth();

        if (adjustToBuyList.length > 0) {
            (
                uint256[] memory adjustToBuyListAmountsIn,
                uint256[] memory adjustToBuyListAmountsOut
            ) = polybitRebalancer.createAdjustToBuyOrder(
                    totalBalance,
                    adjustToBuyList,
                    totalTargetPercentage,
                    address(this)
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
            ) = polybitRebalancer.createBuyOrder(
                    buyList,
                    wethBalance,
                    totalTargetPercentage,
                    address(this)
                );

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
            tokenIn,
            tokenOut,
            tokenAmountIn,
            tokenAmountOut,
            recipient
        );
        require(
            token.approve(address(polybitRouterAddress), 0),
            "TOKEN revoke approval failed"
        );
    }

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
        require(
            wethToken.approve(address(this), wethBalance),
            "WETH Token approve failed."
        );
        wethToken.withdraw(wethBalance);
        require(
            wethToken.approve(address(this), 0),
            "WETH Token revoke approval failed."
        );
    }

    event TransferToClose(string msg, uint256 ref);

    function transferToClose() external {
        require(
            block.timestamp >= unlockTime,
            "The wallet is locked. Check the time left."
        );
        detfStatus = 2;

        address[] memory ownedAssetList = ownedAssets; // Create temporary list to avoid re-entrancy
        delete ownedAssets;

        uint256 totalBalanceInWeth = getTotalBalanceInWeth();
        valueAtClose = totalBalanceInWeth;

        if (totalBalanceInWeth > totalDeposited) {
            uint256 profit = totalBalanceInWeth - totalDeposited;
            uint256 performanceFee = polybitDETFOracleFactory
                .getPerformanceFee();
            uint256 performanceFeeAmount = (performanceFee * profit) / 10000;
            uint256 performanceFeePercentage = (performanceFeeAmount /
                totalBalanceInWeth) * 10000;
            for (uint256 i = 0; i < ownedAssetList.length; i++) {
                uint256 tokenBalance = 0;
                (tokenBalance, ) = getTokenBalance(ownedAssetList[i]);
                uint256 transferAmount = ((10000 - performanceFeePercentage) *
                    tokenBalance) / 10000;
                emit TransferToClose(
                    "Transferred to DETF owner:",
                    transferAmount
                );
                IERC20(ownedAssetList[i]).safeTransfer(owner, transferAmount);

                uint256 transferFeeAmount = tokenBalance - transferAmount;
                emit TransferToClose(
                    "Transferred to Polybit fee address:",
                    transferFeeAmount
                );
                IERC20(ownedAssetList[i]).safeTransfer(
                    polybitDETFOracleFactory.getFeeAddress(),
                    transferFeeAmount
                );
            }

            uint256 wethBalance = getWethBalance();
            if (wethBalance > 0) {
                uint256 transferAmount = ((10000 - performanceFeePercentage) *
                    wethBalance) / 10000;
                emit TransferToClose(
                    "WETH transferred to DETF owner:",
                    transferAmount
                );
                IERC20(wethAddress).safeTransfer(owner, transferAmount);

                uint256 transferFeeAmount = wethBalance - transferAmount;
                emit TransferToClose(
                    "WETH transferred to Polybit fee address:",
                    transferFeeAmount
                );
                IERC20(wethAddress).safeTransfer(
                    polybitDETFOracleFactory.getFeeAddress(),
                    transferFeeAmount
                );
            }
        } else {
            for (uint256 i = 0; i < ownedAssetList.length; i++) {
                uint256 tokenBalance = 0;
                (tokenBalance, ) = getTokenBalance(ownedAssetList[i]);
                IERC20(ownedAssetList[i]).safeTransfer(owner, tokenBalance);
                emit TransferToClose(
                    "Transferred to DETF owner without fee:",
                    tokenBalance
                );

                uint256 wethBalance = getWethBalance();
                if (wethBalance > 0) {
                    IERC20(wethAddress).safeTransfer(owner, wethBalance);
                }
                emit TransferToClose(
                    "WETH transferred to DETF owner without fee:",
                    tokenBalance
                );
            }
        }

        uint256 ethBalance = getEthBalance();
        emit TransferToClose("ETH balance:", ethBalance);

        if (ethBalance > 0) {
            (bool sent, ) = owner.call{value: ethBalance}("");
            require(sent, "Failed to send ETH");
            emit TransferToClose(
                "ETH amount returned to wallet owner:",
                ethBalance
            );
        }
    }

    event SellToClose(string msg, uint256 ref);

    function sellToClose() external {
        require(
            block.timestamp >= unlockTime,
            "The wallet is locked. Check the time left."
        );
        detfStatus = 2;

        address[] memory ownedAssetList = ownedAssets; // Create temporary list to avoid re-entrancy
        delete ownedAssets;

        if (ownedAssetList.length > 0) {
            for (uint256 i = 0; i < ownedAssetList.length; i++) {
                address tokenAddress = ownedAssetList[i];
                (
                    uint256 tokenBalance,
                    uint256 tokenBalanceInWeth
                ) = getTokenBalance(tokenAddress);
                swapWithLiquidPath(
                    tokenAddress,
                    wethAddress,
                    tokenBalance,
                    tokenBalanceInWeth
                );
            }
        }

        uint256 wethBalance = getWethBalance();
        valueAtClose = wethBalance;

        if (wethBalance > totalDeposited) {
            uint256 profit = wethBalance - totalDeposited;
            processFee(
                profit,
                polybitDETFOracleFactory.getPerformanceFee(),
                polybitDETFOracleFactory.getFeeAddress()
            );
        }

        if (wethBalance > 0) {
            unwrapETH();
        }

        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            (bool sent, ) = owner.call{value: ethBalance}("");
            require(sent, "Failed to send ETH");
            emit SellToClose(
                "ETH amount returned to wallet owner:",
                ethBalance
            );
        }
    }
}
