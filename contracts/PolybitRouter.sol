// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./libraries/PolybitSwapLibrary.sol";
import "./PolybitRouterImmutables.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";

contract PolybitRouter is PolybitRouterImmutables {
    using SafeMath for uint256;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PolybitRouter: EXPIRED");
        _;
    }

    constructor(
        RouterParameters memory params
    ) PolybitRouterImmutables(params) {}

    address[] internal baseTokens = [
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
        0x55d398326f99059fF775485246999027B3197955,
        0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
    ];

    function weth() external view returns (address) {
        return WETH_ADDRESS;
    }

    struct FactoryBestPathParameters {
        address[] dualPath;
        uint256 dualPathAmountsOut;
        address[] triPath;
        uint256 triPathAmountsOut;
        address[] bestPath;
        uint256 bestAmountOut;
        address[] bestTriPath;
    }

    function getFactoryBestPath(
        address swapFactory,
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        bool multihop
    ) internal view returns (address[] memory, uint256) {
        FactoryBestPathParameters memory params;

        if (
            PolybitSwapLibrary.pairFor(swapFactory, tokenIn, tokenOut) !=
            address(0)
        ) {
            params.dualPath = new address[](2);
            params.dualPath[0] = address(tokenIn);
            params.dualPath[1] = address(tokenOut);
            uint256[] memory amountsOut = getAmountsOut(
                swapFactory,
                tokenAmountIn,
                params.dualPath
            );
            params.dualPathAmountsOut = amountsOut[1];
        }

        if (multihop) {
            address token = address(0);
            if (tokenIn == WETH_ADDRESS) {
                token = tokenOut;
            } else {
                token = tokenIn;
            }

            for (uint256 i = 1; i < baseTokens.length; i++) {
                if (
                    PolybitSwapLibrary.pairFor(
                        swapFactory,
                        baseTokens[i],
                        token
                    ) != address(0)
                ) {
                    params.triPath = new address[](3);
                    params.triPath[0] = address(tokenIn);
                    params.triPath[1] = address(baseTokens[i]);
                    params.triPath[2] = address(tokenOut);

                    uint256[] memory amountsOut = getAmountsOut(
                        swapFactory,
                        tokenAmountIn,
                        params.triPath
                    );

                    if (amountsOut[2] > params.triPathAmountsOut) {
                        params.triPathAmountsOut = amountsOut[2];
                        params.bestTriPath = params.triPath;
                    }
                }
            }

            if (params.dualPathAmountsOut > params.triPathAmountsOut) {
                params.bestPath = params.dualPath;
                params.bestAmountOut = params.dualPathAmountsOut;
            } else {
                params.bestPath = params.bestTriPath;
                params.bestAmountOut = params.triPathAmountsOut;
            }
        } else {
            params.bestPath = params.dualPath;
            params.bestAmountOut = params.dualPathAmountsOut;
        }

        return (params.bestPath, params.bestAmountOut);
    }

    struct LiquidPathParameters {
        address bestFactory;
        address[] bestPath;
        uint256 bestAmountsOut;
        address token;
        uint256 tokenAmount;
    }

    function getLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn
    ) public view returns (address, address[] memory, uint256) {
        LiquidPathParameters memory params;

        //PolybitSwap
        (
            address[] memory polybitswapPath,
            uint256 polybitswapAmountsOut
        ) = getFactoryBestPath(
                POLYBITSWAP_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmountIn,
                true
            );

        //Set the initial challenger
        params.bestFactory = POLYBITSWAP_FACTORY;
        params.bestPath = polybitswapPath;
        params.bestAmountsOut = polybitswapAmountsOut;

        /* //Pancakeswap
        (
            address[] memory pancakeswapPath,
            uint256 pancakeswapAmountsOut
        ) = getFactoryBestPath(
                PANCAKESWAP_V2_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmountIn,
                true
            );

        //Set the initial challenger
        params.bestFactory = PANCAKESWAP_V2_FACTORY;
        params.bestPath = pancakeswapPath;
        params.bestAmountsOut = pancakeswapAmountsOut;

        //Sushiswap
        (
            address[] memory sushiswapPath,
            uint256 sushiswapAmountsOut
        ) = getFactoryBestPath(
                SUSHISWAP_V2_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmountIn,
                true
            );

        if (sushiswapAmountsOut > params.bestAmountsOut) {
            params.bestFactory = SUSHISWAP_V2_FACTORY;
            params.bestPath = sushiswapPath;
            params.bestAmountsOut = sushiswapAmountsOut;
        }

        //Biswap
        (
            address[] memory biswapPath,
            uint256 biswapAmountsOut
        ) = getFactoryBestPath(
                BISWAP_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmountIn,
                true
            );

        if (biswapAmountsOut > params.bestAmountsOut) {
            params.bestFactory = BISWAP_FACTORY;
            params.bestPath = biswapPath;
            params.bestAmountsOut = biswapAmountsOut;
        } */

        return (params.bestFactory, params.bestPath, params.bestAmountsOut);
    }

    struct SwapOrder {
        address tokenIn;
        address tokenOut;
        uint256 tokenAmountIn;
        uint256 tokenAmountOut;
    }

    struct SwapOrders {
        SwapOrder[] swapOrder;
    }

    function getLiquidPaths(
        SwapOrders[] memory swapOrders
    )
        external
        view
        returns (address[] memory, address[][] memory, uint256[] memory)
    {
        //SwapOrders memory swapOrders;
        address[] memory factories = new address[](
            swapOrders[0].swapOrder.length
        );
        address[][] memory paths = new address[][](
            swapOrders[0].swapOrder.length
        );
        uint256[] memory amounts = new uint256[](
            swapOrders[0].swapOrder.length
        );

        uint256 index = 0;
        for (uint256 i = 0; i < swapOrders[0].swapOrder.length; i++) {
            (
                address factory,
                address[] memory path,
                uint256 amountsOut
            ) = getLiquidPath(
                    swapOrders[0].swapOrder[i].tokenIn,
                    swapOrders[0].swapOrder[i].tokenOut,
                    swapOrders[0].swapOrder[i].tokenAmountIn
                );
            factories[index] = factory;
            paths[index] = path;
            amounts[index] = amountsOut;
            index++;
        }

        return (factories, paths, amounts);
    }

    // requires the initial amount to have already been sent to the first pair
    function _swap(
        address swapFactory,
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = PolybitSwapLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? PolybitSwapLibrary.pairFor(swapFactory, output, path[i + 2])
                : _to;
            IPolybitSwapPair(
                PolybitSwapLibrary.pairFor(swapFactory, input, output)
            ).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapTokens(
        address swapFactory,
        address[] memory path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {
        amounts = PolybitSwapLibrary.getAmountsOut(swapFactory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            PolybitSwapLibrary.pairFor(swapFactory, path[0], path[1]),
            amounts[0]
        );
        _swap(swapFactory, amounts, path, to);
    }

    function getAmountsOut(
        address swapFactory,
        uint256 amountIn,
        address[] memory path
    ) public view virtual returns (uint256[] memory amounts) {
        return PolybitSwapLibrary.getAmountsOut(swapFactory, amountIn, path);
    }
}
