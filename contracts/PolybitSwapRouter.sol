// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./libraries/PolybitSwapLibrary.sol";
import "./PolybitRouterImmutables.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";

contract PolybitSwapRouter {
    /// @dev WETH address
    address internal immutable WETH_ADDRESS;

    /// @dev WETH contract
    IWETH internal immutable WETH;
    using SafeMath for uint256;

    constructor(address _wethAddress) {
        WETH_ADDRESS = _wethAddress;
        WETH = IWETH(_wethAddress);
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "PolybitRouter: EXPIRED");
        _;
    }

    receive() external payable {
        assert(msg.sender == WETH_ADDRESS); // only accept ETH via fallback from the WETH contract
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

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) public pure virtual returns (uint amountB) {
        return PolybitSwapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual returns (uint amountOut) {
        return PolybitSwapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) public pure virtual returns (uint amountIn) {
        return PolybitSwapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(
        address factory,
        uint amountIn,
        address[] memory path
    ) public view virtual returns (uint[] memory amounts) {
        return PolybitSwapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(
        address factory,
        uint amountOut,
        address[] memory path
    ) public view virtual returns (uint[] memory amounts) {
        return PolybitSwapLibrary.getAmountsIn(factory, amountOut, path);
    }
}
