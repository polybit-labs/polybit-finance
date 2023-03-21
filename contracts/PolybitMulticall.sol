// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.7;

import "./interfaces/IPolybitConfig.sol";
import "./interfaces/IPolybitDETF.sol";
import "./interfaces/IPolybitDETFFactory.sol";

contract PolybitMulticall {
    address public polybitConfigAddress;
    IPolybitConfig polybitConfig;

    constructor(address _polybitConfigAddress) {
        polybitConfigAddress = _polybitConfigAddress;
        polybitConfig = IPolybitConfig(polybitConfigAddress);
    }

    function getAllTokenBalancesInWeth(
        address _detfAddress,
        address[] memory _tokenAddresses,
        uint256[] memory _tokenPrices
    ) public view returns (uint256[] memory) {
        require(
            _tokenAddresses.length == _tokenPrices.length,
            "Token address length does not match token price lenth"
        );

        uint256[] memory tokenBalancesInWeth = new uint256[](
            _tokenAddresses.length
        );
        uint8 listIndex = 0;

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            (, uint256 tokenBalanceInWeth) = IPolybitDETF(_detfAddress)
                .getTokenBalance(_tokenAddresses[i], _tokenPrices[i]);
            tokenBalancesInWeth[listIndex] = tokenBalanceInWeth;
            listIndex++;
        }
        return tokenBalancesInWeth;
    }

    struct DETFAccountDetail {
        address detfAddress;
        uint256 status;
        uint256 creationTimestamp;
        string productCategory;
        string productDimension;
        uint256[][] deposits;
        uint256 totalDeposited;
        uint256[][] feesPaid;
        address[] ownedAssets;
        uint256 timeLock;
        uint256 timeLockRemaining;
        uint256 closeTimestamp;
        uint256 finalBalanceInWeth;
        address[] finalAssets;
        uint256[] finalAssetsPrices;
        uint256[] finalAssetsBalances;
        uint256[] finalAssetsBalancesInWeth;
    }

    function getDETFAccountDetail(
        address _detfAddress
    ) public view returns (DETFAccountDetail memory) {
        DETFAccountDetail memory data;
        data.detfAddress = _detfAddress;
        data.status = IPolybitDETF(_detfAddress).getStatus();
        data.deposits = IPolybitDETF(_detfAddress).getDeposits();
        data.creationTimestamp = IPolybitDETF(_detfAddress)
            .getCreationTimestamp();
        data.productCategory = IPolybitDETF(_detfAddress).getProductCategory();
        data.productDimension = IPolybitDETF(_detfAddress)
            .getProductDimension();
        data.totalDeposited = 0;
        data.feesPaid;
        data.ownedAssets;
        data.timeLock = 0;
        data.timeLockRemaining = 0;
        data.closeTimestamp = 0;
        data.finalBalanceInWeth = 0;
        data.finalAssets;
        data.finalAssetsPrices;
        data.finalAssetsBalances;
        data.finalAssetsBalancesInWeth;

        // If DETF is active and has more than one deposit
        if (data.status == 1 && data.deposits.length > 0) {
            data.totalDeposited = IPolybitDETF(_detfAddress)
                .getTotalDeposited();
            data.feesPaid = IPolybitDETF(_detfAddress).getFeesPaid();
            data.ownedAssets = IPolybitDETF(_detfAddress).getOwnedAssets();
            data.timeLock = IPolybitDETF(_detfAddress).getTimeLock();
            data.timeLockRemaining = IPolybitDETF(_detfAddress)
                .getTimeLockRemaining();
        }

        // If DETF is inactive and has more than one deposit
        if (data.status == 0 && data.deposits.length > 0) {
            data.totalDeposited = IPolybitDETF(_detfAddress)
                .getTotalDeposited();
            data.feesPaid = IPolybitDETF(_detfAddress).getFeesPaid();
            data.closeTimestamp = IPolybitDETF(_detfAddress)
                .getCloseTimestamp();
            data.finalBalanceInWeth = IPolybitDETF(_detfAddress)
                .getFinalBalance();
            (
                data.finalAssets,
                data.finalAssetsPrices,
                data.finalAssetsBalances,
                data.finalAssetsBalancesInWeth
            ) = IPolybitDETF(_detfAddress).getFinalAssets();
        }
        return data;
    }

    struct DETFAccountDetailAll {
        DETFAccountDetail detfData;
    }

    function getDETFAccountDetailAll(
        address[] memory _detfAddresses
    ) public view returns (DETFAccountDetailAll[] memory) {
        DETFAccountDetailAll[]
            memory detfAccountDetailAll = new DETFAccountDetailAll[](
                _detfAddresses.length
            );
        uint8 listIndex = 0;

        for (uint256 i = 0; i < _detfAddresses.length; i++) {
            DETFAccountDetail memory detfAccountDetail = getDETFAccountDetail(
                _detfAddresses[i]
            );
            detfAccountDetailAll[listIndex].detfData = detfAccountDetail;
            listIndex++;
        }
        return detfAccountDetailAll;
    }

    function getDETFAccountDetailFromWalletOwner(
        address _walletOwner
    ) public view returns (DETFAccountDetailAll[] memory) {
        address polybitDETFFactoryAddress = polybitConfig
            .getPolybitDETFFactoryAddress();
        address[] memory DETFAccounts = IPolybitDETFFactory(
            polybitDETFFactoryAddress
        ).getDETFAccounts(_walletOwner);
        DETFAccountDetailAll[]
            memory detfAccountDetailAll = getDETFAccountDetailAll(DETFAccounts);
        return detfAccountDetailAll;
    }
}
