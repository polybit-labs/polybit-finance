// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitRouter {
    function getSwapFactory() external view returns (address);

    function getWethAddress() external view returns (address);

    function getBaseTokens() external view returns (address[] memory);

    function getBaseTokenType(address tokenAddress)
        external
        view
        returns (string memory);

    function liquidPath(
        address detfOracleAddress,
        address tokenIn,
        address tokenOut,
        uint256 tokenAmountIn,
        uint256 tokenAmountOut,
        address reipient
    ) external;

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}
