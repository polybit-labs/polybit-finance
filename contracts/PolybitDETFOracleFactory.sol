// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./PolybitDETFOracle.sol";
import "./Ownable.sol";

/**
 * @title Polybit DETF Oracle Factory
 * @author Matt Leeburn
 * @notice An oracle factory to spawn new price oracles for on-chain price referencing.
 */

contract PolybitDETFOracleFactory is Ownable {
    PolybitDETFOracle[] internal oracleArray;
    address[] internal oracleAddressList;
    string public oracleVersion;

    constructor(address _oracleOwner, string memory _oracleVersion) {
        require(address(_oracleOwner) != address(0));
        _transferOwnership(_oracleOwner);
        oracleVersion = _oracleVersion;
    }

    /**
     * @notice Creates a new Oracle and stores the address in the Oracle Factory's list.
     * @dev Only the Oracle Owner can create a new Oracle.
     */
    function createOracle(
        string memory strategyName,
        string memory strategyId,
        address polybitRouterAddress
    ) external onlyOwner {
        PolybitDETFOracle Oracle = new PolybitDETFOracle(
            oracleVersion,
            owner(),
            strategyName,
            strategyId,
            polybitRouterAddress
        );
        oracleArray.push(Oracle);
        oracleAddressList.push(address(Oracle));
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
