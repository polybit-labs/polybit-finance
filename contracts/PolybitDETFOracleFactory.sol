// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./PolybitDETFOracle.sol";
import "./Ownable.sol";

/**
 * @title Polybit DETF Oracle Factory
 * @author Matt Leeburn
 * @notice An oracle factory to spawn new Decentralised ETF strategy oracles.
 */

contract PolybitDETFOracleFactory is Ownable {
    PolybitDETFOracle[] internal oracleArray;
    address[] internal oracleAddressList;

    constructor(address _oracleOwner) {
        require(
            address(_oracleOwner) != address(0),
            "PolybitDETFOracleFactory: OWNER_ADDRESS_INVALID"
        );
        _transferOwnership(_oracleOwner);
    }

    event DETFOracleCreated(string msg, address ref);

    /**
     * @notice Creates a new Oracle and stores the address in the Oracle Factory's list.
     * @dev Only the Oracle Owner can create a new Oracle.
     */
    function createOracle(
        string memory strategyName,
        uint256 strategyId,
        address polybitRouterAddress
    ) external onlyOwner {
        PolybitDETFOracle Oracle = new PolybitDETFOracle(
            owner(),
            strategyName,
            strategyId,
            address(this),
            polybitRouterAddress
        );
        oracleArray.push(Oracle);
        oracleAddressList.push(address(Oracle));
        emit DETFOracleCreated("New DETF oracle created", address(Oracle));
    }

    /**
     * @param index is the index number of the Oracle in the list of oracles.
     * @return oracleAddressList[index] is the Oracle address in the list of oracles.
     */
    function getOracle(uint256 index) external view returns (address) {
        return oracleAddressList[index];
    }

    /**
     * @return oracleAddressList is an array of Oracle addresses.
     */
    function getListOfOracles() external view returns (address[] memory) {
        return oracleAddressList;
    }
}
