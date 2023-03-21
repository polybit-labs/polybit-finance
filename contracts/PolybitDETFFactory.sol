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
    address public polybitDETFAddress;
    address[] internal detfAddressList;
    mapping(address => address[]) internal detfAccounts;

    constructor(
        address _polybitAccessAddress,
        address _polybitConfigAddress,
        address _polybitDETFAddress
    ) {
        polybitAccessAddress = _polybitAccessAddress;
        polybitAccess = IPolybitAccess(polybitAccessAddress);
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
        polybitDETFAddress = _polybitDETFAddress;
    }

    function createClone(
        address implementation
    ) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(
                0x00,
                or(
                    shr(0xe8, shl(0x60, implementation)),
                    0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000
                )
            )
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(
                0x20,
                or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3)
            )
            instance := create(0, 0x09, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    event DETFCreated(string msg, address ref);

    /**
     * @notice Creates a new DETF and stores the address in the Factory's list.
     */
    function createDETF(
        address _walletOwner,
        string memory _productCategory,
        string memory _productDimension
    ) public {
        address DETF = createClone(polybitDETFAddress);
        PolybitDETF(payable(DETF)).init(
            polybitAccessAddress,
            polybitConfigAddress,
            _walletOwner,
            address(this),
            _productCategory,
            _productDimension
        );
        detfAddressList.push(address(DETF));
        setDETFAccounts(_walletOwner, address(DETF));
        emit DETFCreated("New DETF created", address(DETF));
    }

    /**
     * @return detfAddressList is an array of DETF addresses.
     */
    function getListOfDETFs() external view returns (address[] memory) {
        return detfAddressList;
    }

    function setDETFAccounts(
        address _walletOwner,
        address _detfAddress
    ) internal {
        detfAccounts[_walletOwner].push(_detfAddress);
    }

    function getDETFAccounts(
        address _walletOwner
    ) external view returns (address[] memory) {
        return detfAccounts[_walletOwner];
    }
}
