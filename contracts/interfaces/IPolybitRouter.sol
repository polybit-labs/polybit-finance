// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitRouter {
    function weth() external returns (address);

    function getLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn
    ) external returns (address, address[] memory, uint256);

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
        returns (address[] memory, address[][] memory, uint256[] memory);

    function swapTokens(
        address factory,
        address[] memory path,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}
