// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

interface IPolybitDETF {
    function getStatus() external view returns (uint256);

    function getProductId() external view returns (uint256);

    function getProductCategory() external view returns (string memory);

    function getProductDimension() external view returns (string memory);

    function getTimeLock() external view returns (uint256);

    function getTimeLockRemaining() external view returns (uint256);

    function getCreationTimestamp() external view returns (uint256);

    function getCloseTimestamp() external view returns (uint256);

    function getDeposits() external view returns (uint256[][] memory);

    function getTotalDeposited() external view returns (uint256);

    function getFeesPaid() external view returns (uint256[][] memory);

    function getFinalBalance() external view returns (uint256);

    function getFinalAssets()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        );

    function getOwnedAssets() external view returns (address[] memory);

    function getEthBalance() external view returns (uint256);

    function getWethBalance() external view returns (uint256);

    function getTokenBalance(
        address tokenAddress,
        uint256 tokenPrice
    ) external view returns (uint256, uint256);

    function getTotalBalanceInWeth(
        uint256[] memory ownedAssetsPrices
    ) external view returns (uint256);

    function getLastRebalance() external view returns (uint256);
}
