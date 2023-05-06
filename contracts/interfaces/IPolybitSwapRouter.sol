pragma solidity >=0.8.7;

interface IPolybitSwapRouter {
    function swapExactTokensForTokens(
        address factory,
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        address factory,
        address[] calldata path,
        uint amountOut,
        uint amountInMax,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        address factory,
        address[] calldata path,
        uint amountOutMin,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        address factory,
        address[] calldata path,
        uint amountOut,
        uint amountInMax,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        address factory,
        address[] calldata path,
        uint amountIn,
        uint amountOutMin,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        address factory,
        address[] calldata path,
        uint amountOut,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        address factory,
        uint amountIn,
        address[] memory path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        address factory,
        uint amountOut,
        address[] memory path
    ) external view returns (uint[] memory amounts);
}
