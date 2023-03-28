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
    address internal wethAddress;
    IWETH wethToken;
    address public walletOwner;
    uint256 internal productId;
    string internal productCategory;
    string internal productDimension;
    uint256 internal entryFee;
    uint256 internal exitFee;
    address[] internal ownedAssets;
    uint256[][] internal deposits;
    uint256[][] internal feesPaid;
    uint256 internal lastRebalance = 0;
    uint256 internal creationTimestamp = 0;
    uint256 internal closeTimestamp = 0;
    uint256 internal timeLock = 0;
    uint256 internal status = 0; //Set status to active (0 = inactive, 1 = active)
    uint256 internal finalBalanceInWeth = 0;
    address[] internal finalAssets;
    uint256[] internal finalAssetsPrices;
    uint256[] internal finalAssetsBalances;
    uint256[] internal finalAssetsBalancesInWeth;
    bool internal initialised = false;

    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    function init(
        address _polybitAccessAddress,
        address _polybitConfigAddress,
        address _walletOwnerAddress,
        address _polybitDETFFactoryAddress,
        uint256 _productId,
        string memory _productCategory,
        string memory _productDimension,
        uint256 _entryFee,
        uint256 _exitFee,
        SwapOrders[] memory _orderData
    ) public payable {
        require(initialised != true, "Already initialised");
        require(address(_walletOwnerAddress) != address(0));
        require(address(_polybitDETFFactoryAddress) != address(0));
        initialised = true;
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
        polybitDETFFactoryAddress = _polybitDETFFactoryAddress;
        polybitDETFFactory = IPolybitDETFFactory(polybitDETFFactoryAddress);
        wethAddress = polybitConfig.getWethAddress();
        wethToken = IWETH(wethAddress);
        walletOwner = _walletOwnerAddress;
        productId = _productId;
        productCategory = _productCategory;
        productDimension = _productDimension;
        entryFee = _entryFee;
        exitFee = _exitFee;
        creationTimestamp = block.timestamp;
        status = 1;
        initialDeposit(0, _orderData);
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

    function setTimeLock(uint256 unixTimeLock) public onlyWalletOwner {
        require(
            unixTimeLock > block.timestamp,
            "Unlock time should be in the future"
        );
        timeLock = unixTimeLock;
    }

    /* struct DETFAccountDetail {
        uint256 status;
        uint256 creationTimestamp;
        uint256 closeTimestamp;
        string productCategory;
        string productDimension;
        uint256[][] deposits;
        uint256 totalDeposited;
        uint256[][] feesPaid;
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
        data.productCategory = productCategory;
        data.productDimension = productDimension;
        data.deposits = deposits;
        data.totalDeposited = getTotalDeposited();
        data.feesPaid = feesPaid;
        data.timeLock = timeLock;
        data.timeLockRemaining = getTimeLockRemaining();
        data.finalBalanceInWeth = finalBalanceInWeth;
        return data;
    } */

    event EthBalance(string, uint256);

    function initialDeposit(
        uint256 lockTimestamp,
        SwapOrders[] memory orderData
    ) internal {
        if (lockTimestamp > 0) {
            setTimeLock(lockTimestamp);
        }
        rebalance(orderData);
    }

    function deposit(
        uint256 lockTimestamp,
        SwapOrders[] memory orderData
    ) public payable onlyWalletOwner {
        if (lockTimestamp > 0) {
            setTimeLock(lockTimestamp);
        }
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
                entryFee,
                polybitConfig.getFeeAddress()
            );
        }
    }

    event ProcessFee(string, uint256);

    function processFee(
        uint256 inputAmount,
        uint256 fee,
        address feeAddress
    ) internal {
        uint256 feeAmount = (inputAmount * fee) / 10000;
        uint256 cachedFeeAmount = feeAmount;
        feesPaid.push([block.timestamp, feeAmount]);
        feeAmount = 0;
        emit ProcessFee("Fee paid", feeAmount);
        IERC20(wethAddress).safeTransfer(feeAddress, cachedFeeAmount);
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
        address[] factory;
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
                            polybitRouterAddress,
                            polybitRouter,
                            orderData[0].sellOrders[0].factory[i],
                            orderData[0].sellOrders[0].path[i],
                            orderData[0].sellOrders[0].amountsIn[i],
                            orderData[0].sellOrders[0].amountsOut[i]
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
                i < orderData[0].adjustToSellOrders[0].factory.length;
                i++
            ) {
                if (orderData[0].adjustToSellOrders[0].path[i].length > 0) {
                    swap(
                        polybitRouterAddress,
                        polybitRouter,
                        orderData[0].adjustToSellOrders[0].factory[i],
                        orderData[0].adjustToSellOrders[0].path[i],
                        orderData[0].adjustToSellOrders[0].amountsIn[i],
                        orderData[0].adjustToSellOrders[0].amountsOut[i]
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
                            polybitRouterAddress,
                            polybitRouter,
                            orderData[0].adjustToBuyOrders[0].factory[i],
                            orderData[0].adjustToBuyOrders[0].path[i],
                            ordersInfo.adjustToBuyListAmountsIn[i],
                            ordersInfo.adjustToBuyListAmountsOut[i]
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
                            polybitRouterAddress,
                            polybitRouter,
                            orderData[0].buyOrders[0].factory[i],
                            orderData[0].buyOrders[0].path[i],
                            ordersInfo.buyListAmountsIn[i],
                            ordersInfo.buyListAmountsOut[i]
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

    function rebalanceDETF(
        SwapOrders[] memory orderData
    ) external onlyAuthorised {
        rebalance(orderData);
    }

    function swap(
        address polybitRouterAddress,
        IPolybitRouter polybitRouter,
        address factory,
        address[] memory path,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        uint256 slippage = 500;
        uint256 amountOutMin = ((10000 - slippage) * amountOut) / 10000; // e.g. 0.05% calculated as 50/10000
        uint256 deadline = block.timestamp + 30;
        address recipient = address(this);
        IERC20 token = IERC20(path[0]);

        require(
            token.approve(address(polybitRouterAddress), amountIn),
            "PolybitDETF: TOKEN_APPROVE_FAILED"
        );

        uint256[] memory routerAmounts = polybitRouter.swapTokens(
            factory,
            path,
            amountIn,
            amountOutMin,
            recipient,
            deadline
        );

        require(
            routerAmounts[routerAmounts.length - 1] >= amountOutMin,
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

    event EmergencyWithdrawal(address asset, uint256 amount, uint256 feeAmount);

    function emergencyWithdrawal() external onlyAuthorised {
        for (uint256 i = 0; i < ownedAssets.length; i++) {
            uint256 tokenBalance = IERC20(ownedAssets[i]).balanceOf(
                address(this)
            );
            uint256 feeAmount = (tokenBalance * exitFee) / 10000;
            uint256 withdrawalAmount = tokenBalance - feeAmount;
            emit EmergencyWithdrawal(
                ownedAssets[i],
                withdrawalAmount,
                feeAmount
            );
            IERC20(ownedAssets[i]).safeTransfer(
                polybitConfig.getFeeAddress(),
                feeAmount
            );
            IERC20(ownedAssets[i]).safeTransfer(walletOwner, withdrawalAmount);
        }
    }

    event Withdraw(string msg, uint256 ref);

    function withdraw(SwapOrders[] memory orderData) external onlyAuthorised {
        require(
            block.timestamp >= timeLock,
            "The wallet is locked. Check the time left."
        );
        status = 0; // Set status to inactive
        finalAssets = orderData[0].sellList;
        finalAssetsPrices = orderData[0].sellListPrices;
        finalAssetsBalances = orderData[0].sellOrders[0].amountsIn;
        finalAssetsBalancesInWeth = orderData[0].sellOrders[0].amountsOut;
        delete ownedAssets; // Clear owned assets list
        closeTimestamp = block.timestamp;

        rebalance(orderData);

        uint256 wethBalance = getWethBalance();
        finalBalanceInWeth = wethBalance;

        processFee(wethBalance, exitFee, polybitConfig.getFeeAddress());

        if (wethBalance > 0) {
            unwrapETH();
        }

        uint256 ethBalance = getEthBalance();
        if (ethBalance > 0) {
            (bool sent, ) = walletOwner.call{value: ethBalance}("");
            require(sent, "Failed to send ETH");
            emit Withdraw("ETH amount returned to wallet owner:", ethBalance);
        }
    }

    /* 
    Interface / Getter functions 
    */
    function getStatus() external view returns (uint256) {
        return status;
    }

    function getProductCategory() external view returns (string memory) {
        return productCategory;
    }

    function getProductDimension() external view returns (string memory) {
        return productDimension;
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
            uint256[] memory,
            uint256[] memory
        )
    {
        return (
            finalAssets,
            finalAssetsPrices,
            finalAssetsBalances,
            finalAssetsBalancesInWeth
        );
    }

    function getFeesPaid() external view returns (uint256[][] memory) {
        return feesPaid;
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

    function getTokenBalance(
        address tokenAddress,
        uint256 tokenPrice
    ) public view returns (uint256, uint256) {
        IERC20 token = IERC20(tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 tokenDecimals = token.decimals();
        uint256 tokenBalanceInWeth = (tokenBalance * tokenPrice) /
            10 ** tokenDecimals;
        return (tokenBalance, tokenBalanceInWeth);
    }

    function getTotalBalanceInWeth(
        uint256[] memory ownedAssetsPrices
    ) public view returns (uint256) {
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
}
