// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./PolybitDETF.sol";
import "./Ownable.sol";

/**
 * @title Polybit DETF Factory
 * @author Matt Leeburn
 * @notice An factory to spawn new Decentralised ETF strategy accounts.
 */

contract PolybitDETFFactory is Ownable {
    PolybitDETF[] internal detfArray;
    address[] internal detfAddressList;
    address internal feeAddress = address(0);
    uint256 internal depositFee = 0;
    uint256 internal performanceFee = 0;
    address internal polybitRebalancerAddress = address(0);
    address internal polybitRouterAddress = address(0);
    address internal immutable wethAddress;
    mapping(address => address[]) internal detfAccounts;

    constructor(address _factoryOwner, address _wethAddress) {
        require(
            address(_factoryOwner) != address(0),
            "PolybitDETFFactory: OWNER_ADDRESS_INVALID"
        );
        _transferOwnership(_factoryOwner);
        wethAddress = _wethAddress;
    }

    event DETFCreated(string msg, address ref);

    /**
     * @notice Creates a new DETF and stores the address in the Factory's list.
     */
    function createDETF(address _walletOwner) external returns (address) {
        PolybitDETF DETF = new PolybitDETF(
            owner(),
            _walletOwner,
            address(this)
        );
        detfArray.push(DETF);
        detfAddressList.push(address(DETF));
        setDETFAccounts(_walletOwner, address(DETF));
        emit DETFCreated("New DETF created", address(DETF));
        return address(DETF);
    }

    function setPolybitRebalancerAddress(address rebalancerAddress)
        external
        onlyOwner
    {
        require(address(rebalancerAddress) != address(0));
        polybitRebalancerAddress = rebalancerAddress;
    }

    function getPolybitRebalancerAddress() external view returns (address) {
        return polybitRebalancerAddress;
    }

    function setPolybitRouterAddress(address routerAddress) external onlyOwner {
        require(address(routerAddress) != address(0));
        polybitRouterAddress = routerAddress;
    }

    function getPolybitRouterAddress() external view returns (address) {
        return polybitRouterAddress;
    }

    function getWethAddress() external view returns (address) {
        return wethAddress;
    }

    /**
     * @param index is the index number of the DETF in the list of DETFs.
     * @return detfAddressList[index] is the DETF address in the list of DETFs.
     */
    function getDETF(uint256 index) external view returns (address) {
        return detfAddressList[index];
    }

    /**
     * @return detfAddressList is an array of DETF addresses.
     */
    function getListOfDETFs() external view returns (address[] memory) {
        return detfAddressList;
    }

    function setDETFAccounts(address _walletOwner, address _detfAddress)
        internal
    {
        detfAccounts[_walletOwner].push(_detfAddress);
    }

    function getDETFAccounts(address _walletOwner)
        external
        view
        returns (address[] memory)
    {
        return detfAccounts[_walletOwner];
    }

    function setDepositFee(uint256 fee) external onlyOwner {
        // Fees use 2 decimal places e.g. (50 / 10000) = 0.5%
        emit FeeSetter("Set Deposit Fee", fee);
        depositFee = fee;
    }

    function getDepositFee() external view returns (uint256) {
        return depositFee;
    }

    event FeeSetter(string msg, uint256 ref);

    function setPerformanceFee(uint256 fee) external onlyOwner {
        // Fees use 2 decimal places e.g. (50 / 10000) = 0.5%
        emit FeeSetter("Set Performance Fee", fee);
        performanceFee = fee;
    }

    function getPerformanceFee() external view returns (uint256) {
        return performanceFee;
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        require(
            _feeAddress != address(0),
            ("PolybitDETFFactory: FEE_ADDRESS_INVALID")
        );
        feeAddress = _feeAddress;
    }

    function getFeeAddress() external view returns (address) {
        return feeAddress;
    }
}
