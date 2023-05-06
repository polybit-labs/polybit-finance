// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./libraries/PolybitSwapLibrary.sol";
import "./PolybitRouterImmutables.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";

contract PolybitLiquidPath is PolybitRouterImmutables {
    using SafeMath for uint256;

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
        uint256 dualPathAmount;
        address[] triPath;
        uint256 triPathAmount;
        address[] bestPath;
        uint256 bestAmount;
        address[] bestTriPath;
    }

    function getFactoryBestPath(
        address factory,
        address tokenIn,
        address tokenOut,
        uint256 tokenAmount,
        uint8 amountType,
        bool multihop
    ) internal view returns (address[] memory, uint256) {
        FactoryBestPathParameters memory params;

        if (
            PolybitSwapLibrary.pairFor(factory, tokenIn, tokenOut) != address(0)
        ) {
            params.dualPath = new address[](2);
            params.dualPath[0] = address(tokenIn);
            params.dualPath[1] = address(tokenOut);

            if (amountType == 0) {
                bool success;
                uint256[] memory amountsOut;
                try
                    POLYBIT_SWAP_ROUTER.getAmountsOut(
                        factory,
                        tokenAmount,
                        params.dualPath
                    )
                returns (uint256[] memory amounts) {
                    amountsOut = amounts;
                    success = true;
                } catch (bytes memory /*lowLevelData*/) {
                    success = false;
                }
                if (success == true) {
                    params.dualPathAmount = amountsOut[1];
                }
            }

            if (amountType == 1) {
                bool success;
                uint256[] memory amountsIn;
                try
                    POLYBIT_SWAP_ROUTER.getAmountsIn(
                        factory,
                        tokenAmount,
                        params.dualPath
                    )
                returns (uint256[] memory amounts) {
                    amountsIn = amounts;
                    success = true;
                } catch (bytes memory /*lowLevelData*/) {
                    success = false;
                }
                if (success == true) {
                    params.dualPathAmount = amountsIn[0];
                }
            }
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
                    PolybitSwapLibrary.pairFor(factory, baseTokens[i], token) !=
                    address(0)
                ) {
                    params.triPath = new address[](3);
                    params.triPath[0] = address(tokenIn);
                    params.triPath[1] = address(baseTokens[i]);
                    params.triPath[2] = address(tokenOut);

                    if (amountType == 0) {
                        bool success;
                        uint256[] memory amountsOut;
                        try
                            POLYBIT_SWAP_ROUTER.getAmountsOut(
                                factory,
                                tokenAmount,
                                params.triPath
                            )
                        returns (uint256[] memory amounts) {
                            amountsOut = amounts;
                            success = true;
                        } catch (bytes memory /*lowLevelData*/) {
                            success = false;
                        }
                        if (
                            success == true &&
                            amountsOut[2] > params.triPathAmount
                        ) {
                            params.triPathAmount = amountsOut[2];
                            params.bestTriPath = params.triPath;
                        }
                    }
                    if (amountType == 1) {
                        bool success;
                        uint256[] memory amountsIn;
                        try
                            POLYBIT_SWAP_ROUTER.getAmountsIn(
                                factory,
                                tokenAmount,
                                params.triPath
                            )
                        returns (uint256[] memory amounts) {
                            amountsIn = amounts;
                            success = true;
                        } catch (bytes memory /*lowLevelData*/) {
                            success = false;
                        }
                        if (
                            success == true &&
                            amountsIn[0] > 0 &&
                            amountsIn[0] < params.triPathAmount
                        ) {
                            params.triPathAmount = amountsIn[0];
                            params.bestTriPath = params.triPath;
                        }
                    }
                }
            }

            if (amountType == 0) {
                if (params.dualPathAmount > params.triPathAmount) {
                    params.bestPath = params.dualPath;
                    params.bestAmount = params.dualPathAmount;
                } else {
                    params.bestPath = params.bestTriPath;
                    params.bestAmount = params.triPathAmount;
                }
            }

            if (amountType == 1) {
                if (
                    params.triPathAmount > 0 &&
                    params.dualPathAmount < params.triPathAmount
                ) {
                    params.bestPath = params.bestTriPath;
                    params.bestAmount = params.triPathAmount;
                } else {
                    params.bestPath = params.dualPath;
                    params.bestAmount = params.dualPathAmount;
                }
            }
        } else {
            params.bestPath = params.dualPath;
            params.bestAmount = params.dualPathAmount;
        }

        return (params.bestPath, params.bestAmount);
    }

    struct LiquidPathParameters {
        address bestFactory;
        address[] bestPath;
        uint256 bestAmount;
        address token;
        uint256 tokenAmount;
    }

    function getLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmount,
        uint8 amountType
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
            uint256 pancakeswapAmount
        ) = getFactoryBestPath(
                PANCAKESWAP_V2_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmount,
                amountType,
                true
            );

        //Set the initial challenger
        params.bestFactory = PANCAKESWAP_V2_FACTORY;
        params.bestPath = pancakeswapPath;
        params.bestAmount = pancakeswapAmount;

        //Sushiswap
        (
            address[] memory sushiswapPath,
            uint256 sushiswapAmount
        ) = getFactoryBestPath(
                SUSHISWAP_V2_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmount,
                amountType,
                true
            );

        if (amountType == 0 && sushiswapAmount > params.bestAmount) {
            params.bestFactory = SUSHISWAP_V2_FACTORY;
            params.bestPath = sushiswapPath;
            params.bestAmount = sushiswapAmount;
        } else if (
            amountType == 1 &&
            sushiswapAmount > 0 &&
            sushiswapAmount < params.bestAmount
        ) {
            params.bestFactory = SUSHISWAP_V2_FACTORY;
            params.bestPath = sushiswapPath;
            params.bestAmount = sushiswapAmount;
        }

        //Biswap
        (
            address[] memory biswapPath,
            uint256 biswapAmount
        ) = getFactoryBestPath(
                BISWAP_FACTORY,
                tokenIn,
                tokenOut,
                tokenAmount,
                amountType,
                true
            );

        if (amountType == 0 && biswapAmount > params.bestAmount) {
            params.bestFactory = BISWAP_FACTORY;
            params.bestPath = biswapPath;
            params.bestAmount = biswapAmount;
        } else if (
            amountType == 1 &&
            biswapAmount > 0 &&
            biswapAmount < params.bestAmount
        ) {
            params.bestFactory = BISWAP_FACTORY;
            params.bestPath = biswapPath;
            params.bestAmount = biswapAmount;
        }

        return (params.bestFactory, params.bestPath, params.bestAmount);
    }

    struct SwapOrder {
        address tokenIn;
        address tokenOut;
        uint256 tokenAmount;
        uint8 amountType;
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
                    swapOrders[0].swapOrder[i].tokenAmount,
                    swapOrders[0].swapOrder[i].amountType
                );
            factories[index] = factory;
            paths[index] = path;
            amounts[index] = amountsOut;
            index++;
        }

        return (factories, paths, amounts);
    }
}
