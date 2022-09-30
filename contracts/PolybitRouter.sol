// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./libraries/UniswapV2Library.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";
import "./Ownable.sol";

contract PolybitRouter is Ownable {
    using SafeMath for uint256;

    address internal immutable swapFactory;
    address internal immutable weth;
    uint256 public slippage = 500;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PolybitRouter: EXPIRED");
        _;
    }
    address[] internal baseTokens;

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

    function addBaseToken(address tokenAddress) external onlyOwner {
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

    function setSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;
    }

    event LiquidPath(
        string msg1,
        uint256 ref1,
        string msg2,
        uint256 ref2,
        string msg3,
        address[] ref3
    );

    event LiquidityTest(string msg, address);

    function liquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut,
        address recipient
    ) external {
        address[] memory dualPath;
        address[] memory triPath;
        address[] memory bestPath;
        address[] memory bestTriPath;
        uint256 bestAmountOut = 0;
        uint256 dualPathAmountsOut = 0;
        uint256 triPathAmountsOut = 0;
        address token = address(0);
        uint256 tokenAmount = 0;

        if (tokenIn == weth) {
            token = tokenOut;
            tokenAmount = tokenAmountOut;
        } else {
            token = tokenIn;
            tokenAmount = tokenAmountIn;
        }

        if (UniswapV2Library.pairFor(swapFactory, weth, token) != address(0)) {
            (, uint256 tokenLiquidity) = UniswapV2Library.getReserves(
                swapFactory,
                weth,
                token
            );
            if (tokenLiquidity > (2 * tokenAmount)) {
                dualPath = new address[](2);
                dualPath[0] = address(tokenIn);
                dualPath[1] = address(tokenOut);
                uint256[] memory amountsOut = getAmountsOut(
                    tokenAmountIn,
                    dualPath
                );
                dualPathAmountsOut = amountsOut[1];
            }
        }

        for (uint256 i = 1; i < baseTokens.length; i++) {
            if (
                UniswapV2Library.pairFor(swapFactory, baseTokens[i], token) !=
                address(0)
            ) {
                (, uint256 tokenLiquidity) = UniswapV2Library.getReserves(
                    swapFactory,
                    baseTokens[i],
                    token
                );

                if (tokenLiquidity > (2 * tokenAmount)) {
                    triPath = new address[](3);
                    triPath[0] = address(tokenIn);
                    triPath[1] = address(baseTokens[i]);
                    triPath[2] = address(tokenOut);

                    uint256[] memory amountsOut = getAmountsOut(
                        tokenAmountIn,
                        triPath
                    );

                    if (amountsOut[2] > triPathAmountsOut) {
                        triPathAmountsOut = amountsOut[2];
                        bestTriPath = triPath;
                    }
                }
            }
        }

        if (dualPathAmountsOut > triPathAmountsOut) {
            bestPath = dualPath;
            bestAmountOut = dualPathAmountsOut;
        } else {
            bestPath = bestTriPath;
            bestAmountOut = triPathAmountsOut;
        }

        if (bestPath.length != 0) {
            uint256 amountOutMinimum = ((10000 - slippage) * tokenAmountOut) /
                10000; // e.g. 0.05% calculated as 50/10000
            uint256 deadline = block.timestamp + 15;

            emit LiquidPath(
                "Token Amount Min",
                amountOutMinimum,
                "Path Amount",
                bestAmountOut,
                "Path",
                bestPath
            );
            swapTokens(
                tokenAmountIn,
                amountOutMinimum,
                bestPath,
                recipient,
                deadline
            );
        } else {
            emit LiquidityTest(
                "PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY",
                token
            );
        }
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

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(swapFactory, amountIn, path);
    }
}
