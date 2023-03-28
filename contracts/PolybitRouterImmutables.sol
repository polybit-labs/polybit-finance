// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import {IERC20} from "./interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";

struct RouterParameters {
    address weth;
    address PolybitSwapFactory;
    /* address PancakeswapV2Factory;
    address SushiswapV2Factory;
    address BiswapFactory; */
    /*
    address UniswapV2Factory;
    address UniswapV3Factory;
    */
}

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract PolybitRouterImmutables {
    /// @dev WETH address
    address internal immutable WETH_ADDRESS;

    /// @dev WETH contract
    IWETH internal immutable WETH;

    /// @dev The address of PancakeswapV2Factory
    address internal immutable POLYBITSWAP_FACTORY;

    /* /// @dev The address of PancakeswapV2Factory
    address internal immutable PANCAKESWAP_V2_FACTORY;

    /// @dev The address of SushiswapV2Factory
    address internal immutable SUSHISWAP_V2_FACTORY;

    /// @dev The address of SushiswapV2Factory
    address internal immutable BISWAP_FACTORY; */

    /*     /// @dev The address of UniswapV2Factory
    address internal immutable UNISWAP_V2_FACTORY;

    /// @dev The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;*/

    constructor(RouterParameters memory params) {
        WETH_ADDRESS = params.weth;
        WETH = IWETH(params.weth);
        POLYBITSWAP_FACTORY = params.PolybitSwapFactory;
        /* PANCAKESWAP_V2_FACTORY = params.PancakeswapV2Factory;
        SUSHISWAP_V2_FACTORY = params.SushiswapV2Factory;
        BISWAP_FACTORY = params.BiswapFactory; */
        //UNISWAP_V3_FACTORY = params.UniswapV3Factory;
    }
}
