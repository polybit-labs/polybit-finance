// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "./interfaces/IPolybitAccess.sol";

contract PolybitConfig {
    address public polybitAccessAddress;
    IPolybitAccess polybitAccess;
    address internal feeAddress = address(0);
    uint256 internal entryFee = 0;
    uint256 internal exitFee = 0;
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

    function setPolybitRebalancerAddress(
        address rebalancerAddress
    ) external onlyPolybitOwner {
        require(address(rebalancerAddress) != address(0));
        polybitRebalancerAddress = rebalancerAddress;
    }

    function getPolybitRebalancerAddress() external view returns (address) {
        return polybitRebalancerAddress;
    }

    function setPolybitRouterAddress(
        address routerAddress
    ) external onlyPolybitOwner {
        require(address(routerAddress) != address(0));
        polybitRouterAddress = routerAddress;
    }

    function getPolybitRouterAddress() external view returns (address) {
        return polybitRouterAddress;
    }

    function setPolybitDETFFactoryAddress(
        address detfFactoryAddress
    ) external onlyPolybitOwner {
        require(address(detfFactoryAddress) != address(0));
        polybitDETFFactoryAddress = detfFactoryAddress;
    }

    function getPolybitDETFFactoryAddress() external view returns (address) {
        return polybitDETFFactoryAddress;
    }

    struct DETFProductInfo {
        uint256 productId;
        string category;
        string dimension;
        uint256 entryFee;
        uint256 exitFee;
    }

    mapping(uint256 => string) internal productCategory;
    mapping(uint256 => string) internal productDimension;
    mapping(uint256 => uint256) internal productEntryFee;
    mapping(uint256 => uint256) internal productExitFee;

    DETFProductInfo[] DETFProducts;

    function createDETFProduct(
        uint256 _productId,
        string memory _category,
        string memory _dimension,
        uint256 _entryFee,
        uint256 _exitFee
    ) external onlyPolybitOwner {
        DETFProductInfo memory DETFProduct = DETFProductInfo(
            _productId,
            _category,
            _dimension,
            _entryFee,
            _exitFee
        );
        DETFProducts.push(DETFProduct);
        productCategory[_productId] = _category;
        productDimension[_productId] = _dimension;
        productEntryFee[_productId] = _entryFee;
        productExitFee[_productId] = _exitFee;
    }

    function getDETFProductInfo(
        uint256 _productId
    ) external view returns (string memory, string memory, uint256, uint256) {
        return (
            productCategory[_productId],
            productDimension[_productId],
            productEntryFee[_productId],
            productExitFee[_productId]
        );
    }

    event FeeSetter(string message, address newFeeAddress);

    function setFeeAddress(address _feeAddress) external onlyPolybitOwner {
        require(
            _feeAddress != address(0),
            ("PolybitConfig: FEE_ADDRESS_INVALID")
        );
        emit FeeSetter("Fee Address changed", _feeAddress);
        feeAddress = _feeAddress;
    }

    function getFeeAddress() external view returns (address) {
        return feeAddress;
    }

    function getWethAddress() external view returns (address) {
        return wethAddress;
    }
}
