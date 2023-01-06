// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitAccess.sol";
import "./interfaces/IPolybitConfig.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";

contract PolybitRouter {
    address public polybitAccessAddress;
    IPolybitAccess polybitAccess;
    address public polybitConfigAddress;
    IPolybitConfig polybitConfig;

    using SafeMath for uint256;

    address internal immutable swapFactory;
    address internal immutable wethAddress;
    uint256 internal slippage = 500;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PolybitRouter: EXPIRED");
        _;
    }
    address[] internal baseTokens;

    constructor(
        address _polybitAccessAddress,
        address _polybitConfigAddress,
        address _swapFactory
    ) {
        require(address(_swapFactory) != address(0));
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
        swapFactory = _swapFactory;
        wethAddress = polybitConfig.getWethAddress();
    }

    modifier onlyRouterOwner() {
        _checkRouterOwner();
        _;
    }

    function _checkRouterOwner() internal view virtual {
        require(
            polybitAccess.routerOwner() == msg.sender,
            "PolybitRouter: caller is not the routerOwner"
        );
    }

    function getSwapFactory() external view returns (address) {
        return swapFactory;
    }

    function getWethAddress() external view returns (address) {
        return wethAddress;
    }

    function addBaseToken(address tokenAddress) external onlyRouterOwner {
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

    function removeBaseToken(address tokenAddress) external onlyRouterOwner {
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

    function setSlippage(uint256 _slippage) external onlyRouterOwner {
        slippage = _slippage;
    }

    function getSlippage() external view returns (uint256) {
        return slippage;
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

    function getLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut
    ) public view returns (address[] memory) {
        address[] memory dualPath;
        address[] memory triPath;
        address[] memory bestPath;
        address[] memory bestTriPath;
        uint256 bestAmountOut = 0;
        uint256 dualPathAmountsOut = 0;
        uint256 triPathAmountsOut = 0;
        address token = address(0);
        uint256 tokenAmount = 0;

        if (tokenIn == wethAddress) {
            token = tokenOut;
            tokenAmount = tokenAmountOut;
        } else {
            token = tokenIn;
            tokenAmount = tokenAmountIn;
        }

        if (
            UniswapV2Library.pairFor(swapFactory, wethAddress, token) !=
            address(0)
        ) {
            (, uint256 tokenLiquidity) = UniswapV2Library.getReserves(
                swapFactory,
                wethAddress,
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

        /* for (uint256 i = 1; i < baseTokens.length; i++) {
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
        } */

        if (dualPathAmountsOut > triPathAmountsOut) {
            bestPath = dualPath;
            bestAmountOut = dualPathAmountsOut;
        } else {
            bestPath = bestTriPath;
            bestAmountOut = triPathAmountsOut;
        }

        return bestPath;
    }

    function getLiquidPaths(
        address[] memory tokensIn,
        address[] memory tokensOut,
        uint256[] memory tokenAmountsIn,
        uint256[] memory tokenAmountsOut
    ) external view returns (address[][] memory) {
        address[][] memory paths = new address[][](tokensIn.length);

        uint256 index = 0;
        for (uint256 i = 0; i < tokensIn.length; i++) {
            address[] memory path = getLiquidPath(
                tokensIn[i],
                tokensOut[i],
                tokenAmountsIn[i],
                tokenAmountsOut[i]
            );
            paths[index] = path;
            index++;
        }

        return paths;
    }

    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = UniswapV2Library.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? UniswapV2Library.pairFor(swapFactory, output, path[i + 2])
                : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(swapFactory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {
        amounts = UniswapV2Library.getAmountsOut(swapFactory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(swapFactory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
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
