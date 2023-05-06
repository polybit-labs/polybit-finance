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

        /* //PolybitSwap
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
        params.bestAmountsOut = polybitswapAmountsOut; */

        //Pancakeswap
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
        }

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

    function _swap(
        address factory,
        address[] memory path,
        uint[] memory amounts,
        address _to
    ) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = PolybitSwapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0
                ? (uint(0), amountOut)
                : (amountOut, uint(0));
            address to = i < path.length - 2
                ? PolybitSwapLibrary.pairFor(factory, output, path[i + 2])
                : _to;
            IPolybitSwapPair(PolybitSwapLibrary.pairFor(factory, input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        address factory,
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = PolybitSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "PolybitRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(factory, path, amounts, to);
    }

    function swapTokensForExactTokens(
        address factory,
        address[] calldata path,
        uint amountOut,
        uint amountInMax,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        amounts = PolybitSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "PolybitRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(factory, path, amounts, to);
    }

    function swapExactETHForTokens(
        address factory,
        address[] calldata path,
        uint amountOutMin,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH_ADDRESS, "PolybitRouter: INVALID_PATH");
        amounts = PolybitSwapLibrary.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "PolybitRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        WETH.deposit{value: amounts[0]}();
        assert(
            WETH.transfer(
                PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(factory, path, amounts, to);
    }

    function swapTokensForExactETH(
        address factory,
        address[] calldata path,
        uint amountOut,
        uint amountInMax,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        require(
            path[path.length - 1] == WETH_ADDRESS,
            "PolybitRouter: INVALID_PATH"
        );
        amounts = PolybitSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "PolybitRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(factory, path, amounts, address(this));
        WETH.withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        address factory,
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external virtual ensure(deadline) returns (uint[] memory amounts) {
        require(
            path[path.length - 1] == WETH_ADDRESS,
            "PolybitRouter: INVALID_PATH"
        );
        amounts = PolybitSwapLibrary.getAmountsOut(factory, amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "PolybitRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(factory, path, amounts, address(this));
        WETH.withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        address factory,
        address[] calldata path,
        uint amountOut,
        address to,
        uint deadline
    )
        external
        payable
        virtual
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH_ADDRESS, "PolybitRouter: INVALID_PATH");
        amounts = PolybitSwapLibrary.getAmountsIn(factory, amountOut, path);
        require(
            amounts[0] <= msg.value,
            "PolybitRouter: EXCESSIVE_INPUT_AMOUNT"
        );
        WETH.deposit{value: amounts[0]}();
        assert(
            WETH.transfer(
                PolybitSwapLibrary.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(factory, path, amounts, to);
        // refund dust eth, if any
        if (msg.value > amounts[0])
            TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    function getAmountsOut(
        address swapFactory,
        uint256 amountIn,
        address[] memory path
    ) public view virtual returns (uint256[] memory amounts) {
        return PolybitSwapLibrary.getAmountsOut(swapFactory, amountIn, path);
    }
}
