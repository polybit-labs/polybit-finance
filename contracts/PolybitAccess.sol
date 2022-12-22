// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

contract PolybitAccess {
    constructor() {
        _transferPolybitOwnership(msg.sender);
    }

    /* 
    Polybit Owner / Master Access
    */
    address private _polybitOwner;

    event PolybitOwnershipTransferred(
        address indexed previousPolybitOwner,
        address indexed newPolybitOwner
    );

    modifier onlyPolybitOwner() {
        _checkPolybitOwner();
        _;
    }

    function polybitOwner() public view virtual returns (address) {
        return _polybitOwner;
    }

    function _checkPolybitOwner() internal view virtual {
        require(
            polybitOwner() == msg.sender,
            "PolybitOwner: caller is not the owner"
        );
    }

    function transferPolybitOwnership(address newPolybitOwner)
        external
        virtual
        onlyPolybitOwner
    {
        require(
            newPolybitOwner != address(0),
            "PolybitOwner: new owner is the zero address"
        );
        _transferPolybitOwnership(newPolybitOwner);
    }

    function _transferPolybitOwnership(address newPolybitOwner)
        internal
        virtual
    {
        address oldPolybitOwner = _polybitOwner;
        _polybitOwner = newPolybitOwner;
        emit PolybitOwnershipTransferred(oldPolybitOwner, newPolybitOwner);
    }

    /* 
    Rebalancer Owner
    */
    address private _rebalancerOwner;

    event RebalancerOwnershipTransferred(
        address indexed previousRebalancerOwner,
        address indexed newRebalancerOwner
    );

    function rebalancerOwner() public view virtual returns (address) {
        return _rebalancerOwner;
    }

    function transferRebalancerOwnership(address newRebalancerOwner)
        external
        virtual
        onlyPolybitOwner
    {
        require(
            newRebalancerOwner != address(0),
            "RebalancerOwner: new owner is the zero address"
        );
        _transferRebalancerOwnership(newRebalancerOwner);
    }

    function _transferRebalancerOwnership(address newRebalancerOwner)
        internal
        virtual
    {
        address oldRebalancerOwner = _rebalancerOwner;
        _rebalancerOwner = newRebalancerOwner;
        emit RebalancerOwnershipTransferred(
            oldRebalancerOwner,
            newRebalancerOwner
        );
    }

    /* 
    Router Owner
    */
    address private _routerOwner;

    event RouterOwnershipTransferred(
        address indexed previousRouterOwner,
        address indexed newRouterOwner
    );

    function routerOwner() public view virtual returns (address) {
        return _routerOwner;
    }

    function transferRouterOwnership(address newRouterOwner)
        external
        virtual
        onlyPolybitOwner
    {
        require(
            newRouterOwner != address(0),
            "RouterOwner: new owner is the zero address"
        );
        _transferRouterOwnership(newRouterOwner);
    }

    function _transferRouterOwnership(address newRouterOwner) internal virtual {
        address oldRouterOwner = _routerOwner;
        _routerOwner = newRouterOwner;
        emit RouterOwnershipTransferred(oldRouterOwner, newRouterOwner);
    }
}
