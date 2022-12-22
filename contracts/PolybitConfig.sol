// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./interfaces/IPolybitAccess.sol";

contract PolybitConfig {
    address public polybitAccessAddress;
    IPolybitAccess polybitAccess;
    address internal feeAddress = address(0);
    uint256 internal depositFee = 0;
    uint256 internal performanceFee = 0;
    address internal polybitRebalancerAddress = address(0);
    address internal polybitRouterAddress = address(0);
    address internal polybitDETFFactoryAddress = address(0);
    address internal immutable wethAddress;

    constructor(address _polybitAccessAddress, address _wethAddress) {
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        wethAddress = _wethAddress;
    }

    modifier onlyPolybitOwner() {
        _checkPolybitOwner();
        _;
    }

    function _checkPolybitOwner() internal view virtual {
        require(
            polybitAccess.polybitOwner() == msg.sender,
            "PolybitConfig: caller is not the owner"
        );
    }

    function setPolybitRebalancerAddress(address rebalancerAddress)
        external
        onlyPolybitOwner
    {
        require(address(rebalancerAddress) != address(0));
        polybitRebalancerAddress = rebalancerAddress;
    }

    function getPolybitRebalancerAddress() external view returns (address) {
        return polybitRebalancerAddress;
    }

    function setPolybitRouterAddress(address routerAddress)
        external
        onlyPolybitOwner
    {
        require(address(routerAddress) != address(0));
        polybitRouterAddress = routerAddress;
    }

    function getPolybitRouterAddress() external view returns (address) {
        return polybitRouterAddress;
    }

    function setPolybitDETFFactoryAddress(address detfFactoryAddress)
        external
        onlyPolybitOwner
    {
        require(address(detfFactoryAddress) != address(0));
        polybitDETFFactoryAddress = detfFactoryAddress;
    }

    function getPolybitDETFFactoryAddress() external view returns (address) {
        return polybitDETFFactoryAddress;
    }

    function setDepositFee(uint256 fee) external onlyPolybitOwner {
        // Fees use 2 decimal places e.g. (50 / 10000) = 0.5%
        emit FeeSetter("Set Deposit Fee", fee);
        depositFee = fee;
    }

    function getDepositFee() external view returns (uint256) {
        return depositFee;
    }

    event FeeSetter(string msg, uint256 ref);

    function setPerformanceFee(uint256 fee) external onlyPolybitOwner {
        // Fees use 2 decimal places e.g. (50 / 10000) = 0.5%
        emit FeeSetter("Set Performance Fee", fee);
        performanceFee = fee;
    }

    function getPerformanceFee() external view returns (uint256) {
        return performanceFee;
    }

    function setFeeAddress(address _feeAddress) external onlyPolybitOwner {
        require(
            _feeAddress != address(0),
            ("PolybitConfig: FEE_ADDRESS_INVALID")
        );
        feeAddress = _feeAddress;
    }

    function getFeeAddress() external view returns (address) {
        return feeAddress;
    }

    function getWethAddress() external view returns (address) {
        return wethAddress;
    }
}
