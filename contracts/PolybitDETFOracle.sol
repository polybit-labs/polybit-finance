// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./Ownable.sol";
import "./interfaces/IPolybitPriceOracle.sol";
import "./interfaces/IPolybitRouter.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";

/**
 * @title Polybit DETF Oracle
 * @author Matt Leeburn
 * @notice A DETF oracle that contains the information set for a specific
 * DETF / investment strategy. Liquidity and risk weighting are calculated live
 * from the relevant liquidity pools.
 * @dev Check the Oracle status to ensure the Oracle is actively being used
 * and updated. You can also use the lastUpdated timestamp to ensure data is
 * fresh.
 */

contract PolybitDETFOracle is Ownable {
    uint256 internal oracleStatus;
    string internal detfName;
    uint256 internal detfId;
    address internal polybitRouterAddress;
    IPolybitRouter polybitRouter;
    address internal polybitDETFOracleFactoryAddress;
    address internal wethAddress;
    address[] internal targetAssetList;
    address internal swapFactoryAddress;
    IUniswapV2Factory swapFactory;
    uint256 internal lastUpdated;

    struct LiquidityInfo {
        address priceOracleAddress;
        address pairAddress;
        uint112 reserve0;
        uint112 reserve1;
        uint256 tokenPrice;
        uint256 tokenDecimals;
        uint256 tokenBalance;
        uint256 baseTokenBalance;
        uint256 liquidity;
    }

    /**
     * @notice Holds the current assets set by the DETF Strategy for the Oracle
     */
    struct Assets {
        address tokenAddress;
        address priceOracleAddress;
    }

    Assets[] public assets;
    mapping(address => address) internal tokenAddressToPriceOracleAddress;

    constructor(
        address _oracleOwner,
        string memory _detfName,
        uint256 _detfId,
        address _polybitDETFOracleFactoryAddress,
        address _polybitRouterAddress
    ) {
        require(address(_oracleOwner) != address(0));
        _transferOwnership(_oracleOwner);
        detfName = _detfName;
        detfId = _detfId;
        require(address(_polybitDETFOracleFactoryAddress) != address(0));
        polybitDETFOracleFactoryAddress = _polybitDETFOracleFactoryAddress;
        require(address(_polybitRouterAddress) != address(0));
        polybitRouterAddress = _polybitRouterAddress;
        polybitRouter = IPolybitRouter(_polybitRouterAddress);
        swapFactoryAddress = polybitRouter.getSwapFactory();
        swapFactory = IUniswapV2Factory(swapFactoryAddress);
        wethAddress = polybitRouter.getWethAddress();
    }

    event SetStatus(string msg, uint256 ref);

    /**
     * @notice Used to set the status of the Oracle so the consumer knows
     * if it is actively being updated.
     * @param status should either be set to 0 (inactive) or 1 (active).
     * @dev Functions should revert if oracleStatus != 1.
     */
    function setOracleStatus(uint256 status) external onlyOwner {
        emit SetStatus("Oracle Status Set", status);
        oracleStatus = status;
    }

    /**
     * @return oracleStatus is the status of the oracle
     */
    function getOracleStatus() external view returns (uint256) {
        return oracleStatus;
    }

    /**
     * @return polybitDETFOracleFactoryAddress is the address of the Oracle Factory
     */
    function getFactoryAddress() external view returns (address) {
        return polybitDETFOracleFactoryAddress;
    }

    /**
     * @return polybitRouterAddress is the address of the Oracle Factory
     */
    function getRouterAddress() external view returns (address) {
        return polybitRouterAddress;
    }

    /**
     * @return detfName is the name of the DETF strategy
     */
    function getDetfName() external view returns (string memory) {
        return detfName;
    }

    /**
     * @return detfId is the ID of the DETF strategy
     */
    function getDetfId() external view returns (uint256) {
        return detfId;
    }

    event DetfOracleEvent(string msg, address tokenAddress);

    /**
     * @notice Used to add a new asset (token) to the target list. Checks if
     * asset already exists to prevent duplicate entries.
     * @param tokenAddress is the address of the token being added.
     * @param priceOracleAddress is the address of the price oracle for the
     * token being added.
     * @dev Function can only be user by an Oracle Owner.
     */
    function addAsset(address tokenAddress, address priceOracleAddress)
        external
        onlyOwner
    {
        bool assetExists = false;
        if (assets.length > 0) {
            for (uint256 i = 0; i < assets.length; i++) {
                if (address(tokenAddress) == address(assets[i].tokenAddress)) {
                    assetExists = true;
                }
            }
        }
        require(!assetExists, "Asset already exists.");
        assets.push(
            Assets({
                tokenAddress: tokenAddress,
                priceOracleAddress: priceOracleAddress
            })
        );
        tokenAddressToPriceOracleAddress[tokenAddress] = priceOracleAddress;
        targetAssetList.push(tokenAddress);
        lastUpdated = block.timestamp;
        emit DetfOracleEvent("New asset added to target list", tokenAddress);
    }

    /**
     * @notice Used to remocve a single asset (token) from the target list. Checks if
     * asset exists before processing.
     * @param tokenAddress is the address of the token being added.
     * @dev Function can only be user by an Oracle Owner.
     */
    function removeAsset(address tokenAddress) external onlyOwner {
        bool assetExists = false;
        if (assets.length > 0) {
            for (uint256 i = 0; i < assets.length; i++) {
                if (address(tokenAddress) == address(assets[i].tokenAddress)) {
                    assetExists = true;
                }
            }
        }
        require(assetExists, "Asset does not exist.");
        for (uint256 i = 0; i < assets.length; i++) {
            if (address(tokenAddress) == address(assets[i].tokenAddress)) {
                require(i < assets.length);
                assets[i] = assets[assets.length - 1];
                assets.pop();
            }
        }

        address[] memory targetList = new address[](targetAssetList.length - 1);
        uint8 index = 0;
        for (uint256 i = 0; i < targetAssetList.length; i++) {
            if (address(tokenAddress) != address(targetAssetList[i])) {
                targetList[index] = targetAssetList[i];
                index++;
            }
        }
        targetAssetList = targetList;
        lastUpdated = block.timestamp;
        emit DetfOracleEvent("Asset removed from target list", tokenAddress);
    }

    /**
     * @return targetAssetList is the target list of tokens set by the DETF's strategy
     * @dev this checks to see if Oracle is active. If it is not active, it returns an
     * empty target list, which will cause the Rebalancer to create sell orders for
     * any owned tokens.
     */
    function getTargetList() public view returns (address[] memory) {
        address[] memory target;
        if (oracleStatus == 1) {
            target = targetAssetList;
        }
        return target;
    }

    /**
     * @param tokenAddress is the address of the token you require information from
     * @return priceOracleAddress is the address of the token's Price Oracle
     */
    function getPriceOracleAddress(address tokenAddress)
        public
        view
        returns (address)
    {
        address priceOracleAddress = tokenAddressToPriceOracleAddress[
            tokenAddress
        ];
        return priceOracleAddress;
    }

    /**
     * @param baseToken is the address of the base token you require information from
     * @param tokenAddress is the address of the token you require information from
     * @return liquidity is the liquidity of the BASETOKEN / TOKEN pair in WETH
     */
    function getTokenLiquiditySingle(address baseToken, address tokenAddress)
        internal
        view
        returns (uint256)
    {
        LiquidityInfo memory info = LiquidityInfo(
            address(0),
            address(0),
            0,
            0,
            0,
            0,
            0,
            0,
            0
        );
        info.priceOracleAddress = getPriceOracleAddress(tokenAddress);
        info.pairAddress = swapFactory.getPair(baseToken, tokenAddress);
        IUniswapV2Pair tokenPair = IUniswapV2Pair(info.pairAddress);

        if (address(tokenPair) != address(0)) {
            (info.reserve0, info.reserve1, ) = tokenPair.getReserves();
            info.tokenPrice = IPolybitPriceOracle(info.priceOracleAddress)
                .getLatestPrice();
            info.tokenDecimals = IPolybitPriceOracle(info.priceOracleAddress)
                .getDecimals();

            if (tokenPair.token0() == tokenAddress) {
                info.tokenBalance = info.reserve0;
                info.baseTokenBalance = info.reserve1;
            } else {
                info.baseTokenBalance = info.reserve0;
                info.tokenBalance = info.reserve1;
            }
            if (baseToken == wethAddress) {
                info.liquidity = (info.baseTokenBalance +
                    ((info.tokenBalance * info.tokenPrice) /
                        10**info.tokenDecimals));
            } else {
                info.liquidity = (((2 * info.tokenBalance) * info.tokenPrice) /
                    10**info.tokenDecimals);
            }
        }

        return info.liquidity;
    }

    function getTokenLiquidity(address tokenAddress)
        public
        view
        returns (uint256)
    {
        uint256 liquidity = 0;
        address[] memory baseTokens = polybitRouter.getBaseTokens();

        for (uint256 i = 0; i < baseTokens.length; i++) {
            liquidity =
                liquidity +
                getTokenLiquiditySingle(baseTokens[i], tokenAddress);
        }

        return liquidity;
    }

    /**
     * @return totalLiquidity is the total liquidity of all of the WETH / TOKEN pairs in the target list
     */
    function getTotalLiquidity() public view returns (uint256) {
        uint256 totalLiquidity = 0;
        address[] memory targetList = getTargetList();
        if (targetList.length > 0) {
            for (uint256 i = 0; i < targetList.length; i++) {
                totalLiquidity =
                    totalLiquidity +
                    getTokenLiquidity(targetList[i]);
            }
        }
        return totalLiquidity;
    }

    /**
     * @return rwEquallyBalanced is the risk weighting of the asset where the asset
     * is equally balanced with all assets in the target list. For example: if
     * there are 5 assets in the target list, the risk weighting would be 20%.
     */
    function getRwEquallyBalanced() internal view returns (uint256) {
        uint256 targetAssets = getTargetList().length;
        uint256 rwEquallyBalanced = (10**8 * 1) / targetAssets;
        return rwEquallyBalanced;
    }

    /**
     * @return rwLiquidity is the risk weighting of the asset calculated as the
     * percentage of the total liquidity value of the target list. For example
     * if Asset A was worth 8 units and Asset B was worth 2 uints, Asset A's
     * rwLiquidity would be 80%.
     */
    function getRwLiquidity(address tokenAddress)
        internal
        view
        returns (uint256)
    {
        uint256 tokenLiquidity = getTokenLiquidity(tokenAddress);
        uint256 totalLiquidity = getTotalLiquidity();
        uint256 rwLiquidity = (10**8 * tokenLiquidity) / totalLiquidity;
        return rwLiquidity;
    }

    /**
     * @return target is the target percentage of the token based on the
     * chosen risk weighting.
     */
    function getTargetPercentage(address tokenAddress, uint256 riskWeighting)
        external
        view
        returns (uint256)
    {
        uint256 target = 0;
        if (riskWeighting == 0) {
            target = getRwEquallyBalanced();
        }
        if (riskWeighting == 1) {
            target = getRwLiquidity(tokenAddress);
        }
        return target;
    }

    /**
     * @return lastUpdated is the timestamp when the asset's Oracle was last updated
     */
    function getLastUpdated() external view returns (uint256) {
        return lastUpdated;
    }
}
