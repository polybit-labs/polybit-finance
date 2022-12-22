// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./PolybitDETF.sol";
import "./interfaces/IPolybitAccess.sol";

/**
 * @title Polybit DETF Factory
 * @author Matt Leeburn
 * @notice An factory to spawn new Decentralised ETF strategy accounts.
 */

contract PolybitDETFFactory {
    address public polybitAccessAddress;
    IPolybitAccess polybitAccess;
    address public polybitConfigAddress;
    IPolybitConfig polybitConfig;
    PolybitDETF[] internal detfArray;
    address[] internal detfAddressList;
    mapping(address => address[]) internal detfAccounts;

    constructor(address _polybitAccessAddress, address _polybitConfigAddress) {
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
    }

    event DETFCreated(string msg, address ref);

    /**
     * @notice Creates a new DETF and stores the address in the Factory's list.
     */
    function createDETF(
        address _walletOwner,
        uint256 _productId,
        string memory _productCategory,
        string memory _productDimension
    ) external returns (address) {
        PolybitDETF DETF = new PolybitDETF(
            polybitAccessAddress,
            polybitConfigAddress,
            _walletOwner,
            address(this),
            _productId,
            _productCategory,
            _productDimension
        );
        detfArray.push(DETF);
        detfAddressList.push(address(DETF));
        setDETFAccounts(_walletOwner, address(DETF));
        emit DETFCreated("New DETF created", address(DETF));
        return address(DETF);
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
}
