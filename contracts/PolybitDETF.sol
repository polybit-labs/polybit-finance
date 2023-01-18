// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitAccess.sol";
import "./interfaces/IPolybitConfig.sol";
import "./interfaces/IPolybitDETFFactory.sol";
import "./interfaces/IPolybitRebalancer.sol";
import "./interfaces/IPolybitRouter.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IERC20.sol";
import "./libraries/SafeERC20.sol";

contract PolybitDETF {
    address public polybitAccessAddress;
    IPolybitAccess polybitAccess;
    address public polybitConfigAddress;
    IPolybitConfig polybitConfig;
    address public polybitDETFFactoryAddress;
    IPolybitDETFFactory polybitDETFFactory;
    address public immutable walletOwner;
    uint256 internal productId;
    string internal productCategory;
    string internal productDimension;
    address internal wethAddress;
    IWETH wethToken;
    address[] internal ownedAssets;
    uint256[][] internal deposits;
    uint256[][] public fees;
    uint256 internal lastRebalance = 0;
    uint256 internal creationTimestamp = 0;
    uint256 internal closeTimestamp = 0;
    uint256 internal timeLock = 0;
    uint256 internal status = 1; //Set status to active (0 = inactive, 1 = active)
    uint256 internal finalBalanceInWeth = 0;
    address[] internal finalTokenList;
    uint256[] internal finalTokenBalances;
    uint256[] internal finalTokenBalancesInWeth;

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    constructor(
        address _polybitAccessAddress,
        address _polybitConfigAddress,
        address _walletOwnerAddress,
        address _polybitDETFFactoryAddress,
        uint256 _productId,
        string memory _productCategory,
        string memory _productDimension
    ) {
        require(address(_walletOwnerAddress) != address(0));
        require(address(_polybitDETFFactoryAddress) != address(0));
        require(_productId > 0);
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
        polybitDETFFactoryAddress = _polybitDETFFactoryAddress;
        polybitDETFFactory = IPolybitDETFFactory(polybitDETFFactoryAddress);
        walletOwner = _walletOwnerAddress;
        productId = _productId;
        productCategory = _productCategory;
        productDimension = _productDimension;
        wethAddress = polybitConfig.getWethAddress();
        wethToken = IWETH(wethAddress);
        creationTimestamp = block.timestamp;
    }

    modifier onlyAuthorised() {
        _checkOnlyAuthorised();
        _;
    }

    function _checkOnlyAuthorised() internal view virtual {
        require(
            polybitAccess.rebalancerOwner() == msg.sender ||
                walletOwner == msg.sender,
            "PolybitDETF: caller is not the rebalancerOwner or walletOwner"
        );
    }

    modifier onlyWalletOwner() {
        _checkWalletOwner();
        _;
    }

    function _checkWalletOwner() internal view virtual {
        require(
            walletOwner == msg.sender,
            "PolybitDETF: caller is not the walletOwner"
        );
    }

    receive() external payable {}

    function getProductId() external view returns (uint256) {
        return productId;
    }

    function getProductCategory() external view returns (string memory) {
        return productCategory;
    }

    function getProductDimension() external view returns (string memory) {
        return productDimension;
    }

    function getDETFStatus() external view returns (uint256) {
        return status;
    }

    function setTimeLock(uint256 unixTimeLock) public onlyWalletOwner {
        require(
            unixTimeLock > block.timestamp,
            "Unlock time should be in the future"
        );
        timeLock = unixTimeLock;
    }

    function getTimeLock() external view returns (uint256) {
        return timeLock;
    }

    function getTimeLockRemaining() public view returns (uint256) {
        if (timeLock > block.timestamp) {
            return timeLock - block.timestamp;
        } else {
            return uint256(0);
        }
    }

    function getCreationTimestamp() external view returns (uint256) {
        return creationTimestamp;
    }

    function getCloseTimestamp() external view returns (uint256) {
        return closeTimestamp;
    }

    struct DETFAccountDetail {
        uint256 status;
        uint256 creationTimestamp;
        uint256 closeTimestamp;
        uint256 productId;
        string productCategory;
        string productDimension;
        uint256[][] deposits;
        uint256 totalDeposited;
        uint256[][] fees;
        uint256 timeLock;
        uint256 timeLockRemaining;
        uint256 finalBalanceInWeth;
    }

    function getDETFAccountDetail()
        external
        view
        returns (DETFAccountDetail memory)
    {
        DETFAccountDetail memory data;

        data.status = status;
        data.creationTimestamp = creationTimestamp;
        data.closeTimestamp = closeTimestamp;
        data.productId = productId;
        data.productCategory = productCategory;
        data.productDimension = productDimension;
        data.deposits = deposits;
        data.totalDeposited = getTotalDeposited();
        data.fees = fees;
        data.timeLock = timeLock;
        data.timeLockRemaining = getTimeLockRemaining();
        data.finalBalanceInWeth = finalBalanceInWeth;
        return data;
    }

    event EthBalance(string, uint256);

    function deposit(uint256 lockTimestamp, SwapOrders[] memory orderData)
        public
        payable
        onlyWalletOwner
    {
        if (lockTimestamp > 0) {
            setTimeLock(lockTimestamp);
        }
        //checkForDeposits();
        rebalance(orderData);
    }

    function checkForDeposits() internal {
        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            deposits.push([block.timestamp, ethBalance]);
            emit Deposited("Deposited ETH into DETF", ethBalance);
            wrapETH();
            processFee(
                getWethBalance(),
                polybitConfig.getDepositFee(),
                polybitConfig.getFeeAddress()
            );
        }
    }

    function getDeposits() external view returns (uint256[][] memory) {
        return deposits;
    }

    function getTotalDeposited() public view returns (uint256) {
        uint256 totalDeposited = 0;
        for (uint256 i = 0; i < deposits.length; i++) {
            totalDeposited = totalDeposited + deposits[i][1];
        }
        return totalDeposited;
    }

    function getFinalBalance() external view returns (uint256) {
        return finalBalanceInWeth;
    }

    function getFinalAssets()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        return (finalTokenList, finalTokenBalances, finalTokenBalancesInWeth);
    }

    event ProcessFee(string, uint256);

    function processFee(
        uint256 inputAmount,
        uint256 fee,
        address feeAddress
    ) internal {
        uint256 feeAmount = (inputAmount * fee) / 10000;
        uint256 cachedFeeAmount = feeAmount;
        fees.push([block.timestamp, feeAmount]);
        feeAmount = 0;
        emit ProcessFee("Fee paid", feeAmount);
        IERC20(wethAddress).safeTransfer(feeAddress, cachedFeeAmount);
    }

    function getOwnedAssets() external view returns (address[] memory) {
        return ownedAssets;
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getWethBalance() public view returns (uint256) {
        return IERC20(wethAddress).balanceOf(address(this));
    }

    function getTokenBalance(address tokenAddress, uint256 tokenPrice)
        public
        view
        returns (uint256, uint256)
    {
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 tokenDecimals = token.decimals();
        uint256 tokenBalanceInWeth = (tokenBalance * tokenPrice) /
            10**tokenDecimals;
        return (tokenBalance, tokenBalanceInWeth);
    }

    function getTotalBalanceInWeth(uint256[] memory ownedAssetsPrices)
        public
        view
        returns (uint256)
    {
        uint256 tokenBalances = 0;
        if (ownedAssets.length > 0) {
            for (uint256 x = 0; x < ownedAssets.length; x++) {
                (, uint256 tokenBalanceInWeth) = getTokenBalance(
                    ownedAssets[x],
                    ownedAssetsPrices[x]
                );
                tokenBalances = tokenBalances + tokenBalanceInWeth;
            }
        }
        uint256 totalBalance = tokenBalances +
            getEthBalance() +
            getWethBalance();
        return totalBalance;
    }

    function getLastRebalance() external view returns (uint256) {
        return lastRebalance;
    }

    function updateOwnedAssetsForRebalance(
        address[] memory adjustToSellList,
        address[] memory adjustToBuyList,
        address[] memory buyList
    ) internal {
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
    }

    event Deposited(string msg, uint256 ref);
    event LiquidityTest(string msg);

    struct SwapOrder {
        address[] swapFactory;
        address[][] path;
        uint256[] amountsIn;
        uint256[] amountsOut;
    }

    struct SwapOrders {
        address[] sellList;
        uint256[] sellListPrices;
        SwapOrder[] sellOrders;
        address[] adjustList;
        uint256[] adjustListPrices;
        address[] adjustToSellList;
        uint256[] adjustToSellPrices;
        SwapOrder[] adjustToSellOrders;
        address[] adjustToBuyList;
        uint256[] adjustToBuyWeights;
        uint256[] adjustToBuyPrices;
        SwapOrder[] adjustToBuyOrders;
        address[] buyList;
        uint256[] buyListWeights;
        uint256[] buyListPrices;
        SwapOrder[] buyOrders;
    }

    event OwnedAssets(string msg, address[]);
    struct OrdersInfo {
        uint256[] sellListAmountsIn;
        uint256[] sellListAmountsOut;
        uint256[] adjustToBuyListAmountsIn;
        uint256[] adjustToBuyListAmountsOut;
        uint256[] buyListAmountsIn;
        uint256[] buyListAmountsOut;
        uint256 wethBalance;
        uint256 totalTargetPercentage;
        uint256 totalBalance;
    }

    function rebalance(SwapOrders[] memory orderData) internal {
        lastRebalance = block.timestamp;
        OrdersInfo memory ordersInfo;

        address polybitRebalancerAddress = polybitConfig
            .getPolybitRebalancerAddress();
        IPolybitRebalancer polybitRebalancer = IPolybitRebalancer(
            polybitRebalancerAddress
        );
        address polybitRouterAddress = polybitConfig.getPolybitRouterAddress();
        IPolybitRouter polybitRouter = IPolybitRouter(polybitRouterAddress);

        checkForDeposits();

        // SELL ORDERS
        if (orderData[0].sellList.length > 0) {
            for (uint256 i = 0; i < orderData[0].sellList.length; i++) {
                if (orderData[0].sellList[i] != address(0)) {
                    if (orderData[0].sellOrders[0].path[i].length > 0) {
                        swap(
                            orderData[0].sellOrders[0].amountsIn[i],
                            orderData[0].sellOrders[0].amountsOut[i],
                            orderData[0].sellOrders[0].path[i],
                            polybitRouterAddress,
                            polybitRouter
                        );
                    } else {
                        emit LiquidityTest(
                            "PolybitRouter: CANNOT_GET_PATH_FOR_TOKEN"
                        );
                    }
                }
            }
        }

        // ADJUST TO SELL ORDERS
        if (orderData[0].adjustToSellList.length > 0) {
            for (
                uint256 i = 0;
                i < orderData[0].adjustToSellOrders[0].swapFactory.length;
                i++
            ) {
                if (orderData[0].adjustToSellOrders[0].path[i].length > 0) {
                    swap(
                        orderData[0].adjustToSellOrders[0].amountsIn[i],
                        orderData[0].adjustToSellOrders[0].amountsOut[i],
                        orderData[0].adjustToSellOrders[0].path[i],
                        polybitRouterAddress,
                        polybitRouter
                    );
                } else {
                    emit LiquidityTest(
                        "PolybitRouter: CANNOT_GET_PATH_FOR_TOKEN"
                    );
                }
            }
        }

        //BEGIN BUY ORDERS
        ownedAssets = orderData[0].adjustList;
        ordersInfo.totalBalance = getTotalBalanceInWeth(
            orderData[0].adjustListPrices
        );
        ordersInfo.wethBalance = getWethBalance();
        ordersInfo.totalTargetPercentage = polybitRebalancer
            .calcTotalTargetBuyPercentage(
                orderData[0].adjustListPrices, //only get current owned
                orderData[0].adjustToBuyList,
                orderData[0].adjustToBuyWeights,
                orderData[0].adjustToBuyPrices,
                orderData[0].buyList,
                orderData[0].buyListWeights,
                address(this)
            );

        //ADJUST TO BUY ORDERS
        if (orderData[0].adjustToBuyList.length > 0) {
            (
                ordersInfo.adjustToBuyListAmountsIn,
                ordersInfo.adjustToBuyListAmountsOut
            ) = polybitRebalancer.createAdjustToBuyOrder(
                ordersInfo.totalBalance, //only get current owned
                getWethBalance(),
                orderData[0].adjustToBuyList,
                orderData[0].adjustToBuyWeights,
                orderData[0].adjustToBuyPrices,
                ordersInfo.totalTargetPercentage,
                address(this)
            );

            for (uint256 i = 0; i < orderData[0].adjustToBuyList.length; i++) {
                if (orderData[0].adjustToBuyList[i] != address(0)) {
                    if (orderData[0].adjustToBuyOrders[0].path[i].length > 0) {
                        swap(
                            ordersInfo.adjustToBuyListAmountsIn[i],
                            ordersInfo.adjustToBuyListAmountsOut[i],
                            orderData[0].adjustToBuyOrders[0].path[i],
                            polybitRouterAddress,
                            polybitRouter
                        );
                    } else {
                        emit LiquidityTest(
                            "PolybitRouter: CANNOT_GET_PATH_FOR_TOKEN"
                        );
                    }
                }
            }
        }

        //BUY ORDERS
        if (orderData[0].buyList.length > 0) {
            (
                ordersInfo.buyListAmountsIn,
                ordersInfo.buyListAmountsOut
            ) = polybitRebalancer.createBuyOrder(
                orderData[0].buyList,
                orderData[0].buyListWeights,
                orderData[0].buyListPrices,
                ordersInfo.wethBalance,
                ordersInfo.totalTargetPercentage
            );

            for (uint256 i = 0; i < orderData[0].buyList.length; i++) {
                if (orderData[0].buyList[i] != address(0)) {
                    if (orderData[0].buyOrders[0].path[i].length > 0) {
                        swap(
                            ordersInfo.buyListAmountsIn[i],
                            ordersInfo.buyListAmountsOut[i],
                            orderData[0].buyOrders[0].path[i],
                            polybitRouterAddress,
                            polybitRouter
                        );
                    } else {
                        emit LiquidityTest(
                            "PolybitRouter: CANNOT_GET_PATH_FOR_TOKEN"
                        );
                    }
                }
            }
        }
        updateOwnedAssetsForRebalance(
            orderData[0].adjustToSellList,
            orderData[0].adjustToBuyList,
            orderData[0].buyList
        );
    }

    function rebalanceDETF(SwapOrders[] memory orderData)
        external
        onlyAuthorised
    {
        rebalance(orderData);
    }

    event SwapSuccess(string msg, uint256, uint256, address);
    event SwapFailure(string msg, uint256, uint256, address[]);
    event Amounts(string msg, uint256[] ref);

    function swap(
        uint256 amountIn,
        uint256 amountOut,
        address[] memory path,
        address polybitRouterAddress,
        IPolybitRouter polybitRouter
    ) internal {
        uint256 amountOutMin = ((10000 - polybitRouter.getSlippage()) *
            amountOut) / 10000; // e.g. 0.05% calculated as 50/10000
        uint256 deadline = block.timestamp + 30;
        address recipient = address(this);
        IERC20 token = IERC20(path[0]);
        require(
            token.approve(address(polybitRouterAddress), amountIn),
            "PolybitDETF: TOKEN_APPROVE_FAILED"
        );

        uint256[] memory routerAmounts = polybitRouter.swapTokens(
            amountIn,
            amountOutMin,
            path,
            recipient,
            deadline
        );
        require(
            routerAmounts[1] >= amountOutMin,
            "PolybitDETF: SWAP_FAILED_MIN_OUT"
        );

        require(
            token.approve(address(polybitRouterAddress), 0),
            "PolybitDETF: TOKEN_REVOKE_APPROVE_FAILED"
        );
    }

    event EthWrap(string msg, uint256 amount);

    function wrapETH() internal {
        uint256 ethBalance = getEthBalance();
        require(ethBalance > 0, "No ETH available to wrap");
        emit EthWrap("Wrapped ETH", ethBalance);
        wethToken.deposit{value: ethBalance}();
    }

    function unwrapETH() internal {
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

    /* function transferToClose() external {
        require(
            block.timestamp >= timeLock,
            "The wallet is locked. Check the time left."
        );
        detfStatus = 0;

        address[] memory ownedAssetList = ownedAssets; // Create temporary list to avoid re-entrancy
        delete ownedAssets;

        uint256 totalBalanceInWeth = getTotalBalanceInWeth();
        valueAtClose = totalBalanceInWeth;

        if (totalBalanceInWeth > totalDeposited) {
            uint256 profit = totalBalanceInWeth - totalDeposited;
            uint256 performanceFee = polybitDETFFactory.getPerformanceFee();
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
                IERC20(ownedAssetList[i]).safeTransfer(owner(), transferAmount);

                uint256 transferFeeAmount = tokenBalance - transferAmount;
                emit TransferToClose(
                    "Transferred to Polybit fee address:",
                    transferFeeAmount
                );
                IERC20(ownedAssetList[i]).safeTransfer(
                    polybitDETFFactory.getFeeAddress(),
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
                IERC20(wethAddress).safeTransfer(owner(), transferAmount);

                uint256 transferFeeAmount = wethBalance - transferAmount;
                emit TransferToClose(
                    "WETH transferred to Polybit fee address:",
                    transferFeeAmount
                );
                IERC20(wethAddress).safeTransfer(
                    polybitDETFFactory.getFeeAddress(),
                    transferFeeAmount
                );
            }
        } else {
            for (uint256 i = 0; i < ownedAssetList.length; i++) {
                uint256 tokenBalance = 0;
                (tokenBalance, ) = getTokenBalance(ownedAssetList[i]);
                IERC20(ownedAssetList[i]).safeTransfer(owner(), tokenBalance);
                emit TransferToClose(
                    "Transferred to DETF owner without fee:",
                    tokenBalance
                );

                uint256 wethBalance = getWethBalance();
                if (wethBalance > 0) {
                    IERC20(wethAddress).safeTransfer(owner(), wethBalance);
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
            (bool sent, ) = owner().call{value: ethBalance}("");
            require(sent, "Failed to send ETH");
            emit TransferToClose(
                "ETH amount returned to wallet owner:",
                ethBalance
            );
        }
    } */

    event SellToClose(string msg, uint256 ref);

    function sellToClose(SwapOrders[] memory orderData)
        external
        onlyAuthorised
    {
        require(
            block.timestamp >= timeLock,
            "The wallet is locked. Check the time left."
        );
        status = 0; // Set status to inactive
        finalTokenList = orderData[0].sellList;
        finalTokenBalances = orderData[0].sellOrders[0].amountsIn;
        finalTokenBalancesInWeth = orderData[0].sellOrders[0].amountsOut;
        delete ownedAssets; // Clear owned assets list
        closeTimestamp = block.timestamp;

        rebalance(orderData);

        uint256 totalDeposited = getTotalDeposited();
        uint256 wethBalance = getWethBalance();
        finalBalanceInWeth = wethBalance;

        if (wethBalance > totalDeposited) {
            uint256 profit = wethBalance - totalDeposited;
            processFee(
                profit,
                polybitConfig.getPerformanceFee(),
                polybitConfig.getFeeAddress()
            );
        }

        if (wethBalance > 0) {
            unwrapETH();
        }

        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            (bool sent, ) = walletOwner.call{value: ethBalance}("");
            require(sent, "Failed to send ETH");
            emit SellToClose(
                "ETH amount returned to wallet owner:",
                ethBalance
            );
        }
    }
}
