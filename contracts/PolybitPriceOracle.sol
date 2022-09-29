// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.4;

import "./Ownable.sol";
import "./interfaces/IERC20.sol";

/**
 * @title Polybit Price Oracle
 * @author Matt Leeburn
 * @notice A price oracle for on-chain price referencing. Prices are updated using a
 * combination of on-chain and off-chain sources. Price updates are triggered by the
 * price monitor whenever the price deviates beyond a certain interval.
 * @dev Check the Oracle status to ensure the Oracle is actively being updated. You can
 * also use the lastUpdated timestamp to ensure data is fresh.
 */
contract PolybitPriceOracle is Ownable {
    uint256 public oracleStatus;
    address internal factoryAddress;
    address internal tokenAddress;
    uint256 internal latestPrice;
    uint256 internal lastUpdated;

    constructor(
        address _oracleOwner,
        address _tokenAddress,
        address _factoryAddress
    ) {
        require(address(_oracleOwner) != address(0));
        require(address(_tokenAddress) != address(0));
        require(address(_factoryAddress) != address(0));
        _transferOwnership(_oracleOwner);
        factoryAddress = _factoryAddress;
        tokenAddress = _tokenAddress;
    }

    event TokenPriceChange(
        string msg,
        uint256 priceChangedTo,
        uint256 updatedAt
    );

    /**
     * @notice Used to update the latest price of the token.
     * @param price is the latest price of the token.
     * @dev This function can only be called by the Oracle Owner.
     */
    function setTokenPrice(uint256 price) external onlyOwner {
        latestPrice = price;
        lastUpdated = block.timestamp;
        emit TokenPriceChange("Price updated", latestPrice, lastUpdated);
    }

    /**
     * @notice Used to set the status of the Oracle so the consumer knows
     * if it is actively being updated.
     * @param status should either be set to 0 (inactive) or 1 (active).
     * @dev Functions should revert if oracleStatus != 1.
     */
    function setOracleStatus(uint256 status) external onlyOwner {
        oracleStatus = status;
    }

    /**
     * @return oracleStatus is the status of the oracle
     */
    function getOracleStatus() external view returns (uint256) {
        return oracleStatus;
    }

    /**
     * @return factoryAddress is the address of the Price Oracle's Factory
     */
    function getFactoryAddress() external view returns (address) {
        return factoryAddress;
    }

    /**
     * @return tokenAddress is the address of the token the Price Oracle
     * relates too.
     */
    function getTokenAddress() external view returns (address) {
        return tokenAddress;
    }

    /**
     * @return symbol is the symbol of the token the Price Oracle
     * relates too.
     */
    function getSymbol() external view returns (string memory) {
        string memory symbol = IERC20(tokenAddress).symbol();
        return symbol;
    }

    /**
     * @return decimals is the decimals of the token the Price Oracle
     * relates too.
     */
    function getDecimals() external view returns (uint8) {
        uint8 decimals = IERC20(tokenAddress).decimals();
        return decimals;
    }

    /**
     * @return latestPrice is the decimals of the token the Price Oracle
     * relates too.
     */
    function getLatestPrice() external view returns (uint256) {
        return latestPrice;
    }

    /**
     * @return lastUpdated is a timestamp recorded when the price was
     * last updated.
     */
    function getLastUpdated() external view returns (uint256) {
        return lastUpdated;
    }
}
