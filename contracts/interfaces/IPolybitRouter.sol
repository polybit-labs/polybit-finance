// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitRouter {
    function getSwapFactory() external view returns (address);

    function getWethAddress() external view returns (address);

    function getBaseTokens() external view returns (address[] memory);

    function getSlippage() external view returns (uint256);

    function getLiquidPath(
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut
    ) external returns (address[] memory);

    function swapTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}
