// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./libraries/UniswapV2Library.sol";
import "./interfaces/IPolybitRouter.sol";
import "./interfaces/IPolybitDETFOracle.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";
import "./Ownable.sol";

contract PolybitRouter is Ownable {
    using SafeMath for uint256;

    address internal immutable swapFactory;
    address internal immutable weth;
    uint256 public slippage = 200;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PolybitRouter: EXPIRED");
        _;
    }
    address[] internal baseTokens;
    mapping(address => string) internal baseTokenType;

    constructor(
        address _routerOwner,
        address _swapFactory,
        address _weth
    ) {
        require(address(_routerOwner) != address(0));
        _transferOwnership(_routerOwner);
        require(address(_swapFactory) != address(0));
        require(address(_weth) != address(0));
        swapFactory = _swapFactory;
        weth = _weth;
    }

    function getSwapFactory() external view returns (address) {
        return swapFactory;
    }

    function getWethAddress() external view returns (address) {
        return weth;
    }

    function addBaseToken(address tokenAddress, string memory tokenType)
        external
        onlyOwner
    {
        bool tokenExists = false;
        if (baseTokens.length > 0) {
            for (uint256 i = 0; i < baseTokens.length; i++) {
                if (address(tokenAddress) == address(baseTokens[i])) {
                    tokenExists = true;
                }
            }
        }
        require(!tokenExists, "Base token already exists.");
        baseTokens.push(address(tokenAddress));
        baseTokenType[tokenAddress] = tokenType;
    }

    function removeBaseToken(address tokenAddress) external onlyOwner {
        bool tokenExists = false;
        if (baseTokens.length > 0) {
            for (uint256 i = 0; i < baseTokens.length; i++) {
                if (address(tokenAddress) == address(baseTokens[i])) {
                    tokenExists = true;
                }
            }
        }
        require(tokenExists, "Base token does not exist.");
        address[] memory tokenList = new address[](baseTokens.length - 1);
        uint8 index = 0;

        for (uint256 i = 0; i < baseTokens.length; i++) {
            if (address(tokenAddress) != address(baseTokens[i])) {
                tokenList[index] = baseTokens[i];
                index++;
            }
        }
        baseTokens = tokenList;
    }

    function getBaseTokens() external view returns (address[] memory) {
        return baseTokens;
    }

    function getBaseTokenType(address tokenAddress)
        external
        view
        returns (string memory)
    {
        return baseTokenType[tokenAddress];
    }

    function setSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;
    }

    event Path(string msg, address[]);

    function liquidPath(
        address detfOracleAddress,
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut,
        address recipient
    ) external {
        uint256 largest = 0;
        address[] memory path;
        address mostLiquidBaseToken = address(0);
        address token = address(0);

        if (tokenIn == weth) {
            token = tokenOut;
        } else {
            token = tokenIn;
        }

        for (uint256 i = 0; i < baseTokens.length; i++) {
            uint256 pairLiquidity = IPolybitDETFOracle(detfOracleAddress)
                .getTokenLiquiditySingle(baseTokens[i], token);
            if (pairLiquidity > largest) {
                largest = pairLiquidity;
                mostLiquidBaseToken = baseTokens[i];
            }
        }

        if (mostLiquidBaseToken == weth) {
            path = new address[](2);
            path[0] = address(tokenIn);
            path[1] = address(tokenOut);
        } else {
            path = new address[](3);
            path[0] = address(tokenIn);
            path[1] = address(mostLiquidBaseToken);
            path[2] = address(tokenOut);
        }

        uint256 amountOutMinimum = ((10000 - 200) * tokenAmountOut) / 10000; // e.g. 0.05% calculated as 50/10000
        uint256 deadline = block.timestamp + 15;

        emit Path("Path taken", path);
        swapTokens(tokenAmountIn, amountOutMinimum, path, recipient, deadline);
    }

    function swapTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address recipient,
        uint256 deadline
    ) internal virtual ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(swapFactory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "PolybitRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(swapFactory, path[0], path[1]),
            amounts[0]
        );

        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(swapFactory, output, path[i + 2])
                : recipient;
            IUniswapV2Pair(UniswapV2Library.pairFor(swapFactory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
        return amounts;
    }
}
