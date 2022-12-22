// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitAccess {
    function polybitOwner() external view returns (address);

    function rebalancerOwner() external view returns (address);

    function routerOwner() external view returns (address);
}
