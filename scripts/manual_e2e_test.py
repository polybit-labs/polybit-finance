from scripts import (
    # deploy_DETF,
    deploy_rebalancer,
    deploy_router,
    deploy_price_oracle_factory,
    deploy_price_oracle_from_factory,
    deploy_DETF_oracle_factory,
    deploy_DETF_oracle_from_factory,
    deploy_DETF_factory,
    deploy_DETF_from_factory,
)
from scripts.utils.polybit_utils import get_account
from brownie import config, network, Contract, PolybitPriceOracle
from pycoingecko import CoinGeckoAPI
from web3 import Web3

cg = CoinGeckoAPI()

BNBUSD = cg.get_coin_by_id("binancecoin")["market_data"]["current_price"]["usd"]

TEST_ASSETS = [
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "0xBf5140A22578168FD562DCcF235E5D43A02ce9B1",
    "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    # "0xfb6115445bff7b52feb98650c87f44907e58f802",  # $0 liquidity test token AAVE
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
    "0xbA552586eA573Eaa3436f04027ff4effd0c0abbb",
    "0x477bC8d23c634C154061869478bce96BE6045D12",
]


def get_coingecko_price(token_address):
    token_price = 0
    try:
        token_price = cg.get_coin_info_from_contract_address_by_id(
            id="binance-smart-chain",
            contract_address=token_address,
        )["market_data"]["current_price"]["bnb"]
    except:
        print(token_address, "failed first CG attempt.")

    if token_price == 0:
        # Sometimes CG stores addresses in lowercase
        try:
            token_price = cg.get_coin_info_from_contract_address_by_id(
                id="binance-smart-chain",
                contract_address=token_address.lower(),
            )["market_data"]["current_price"]["bnb"]
        except:
            print(token_address, "failed to get price from CG.")
    return int(token_price * 10**18)


def add_base_tokens_to_router(router, account):
    router.addBaseToken(
        config["networks"][network.show_active()]["weth_address"],
        {"from": account},
    )
    router.addBaseToken(
        config["networks"][network.show_active()]["busd_address"],
        {"from": account},
    )
    router.addBaseToken(
        config["networks"][network.show_active()]["usdt_address"],
        {"from": account},
    )
    router.addBaseToken(
        config["networks"][network.show_active()]["usdc_address"],
        {"from": account},
    )


def deploy_price_oracles(account, oracle_factory):
    price_oracles = []

    for i in range(0, len(TEST_ASSETS)):
        price_oracle = deploy_price_oracle_from_factory.main(
            account, oracle_factory.address, TEST_ASSETS[i]
        )
        price_oracle.setOracleStatus(1, {"from": account})

        token_price = get_coingecko_price(TEST_ASSETS[i])
        price_oracle.setTokenPrice(token_price, {"from": account})
        price_oracles.append(price_oracle.address)
    return price_oracles


def add_assets_to_detf_oracle(account, oracle, price_oracles):

    for i in range(0, len(TEST_ASSETS)):
        oracle.addAsset(
            TEST_ASSETS[i],
            price_oracles[i],
            {"from": account},
        )


def rebalance(account, detf, rebalancer, router):
    detf.checkForDeposits({"from": account})
    (sellList, adjustToSellList, adjustToBuyList, buyList) = detf.getRebalancerLists()

    if len(sellList) > 0:
        (sellListAmountsIn, sellListAmountsOut) = rebalancer.createSellOrder(
            sellList, detf.address
        )

        for i in range(0, len(sellList)):
            if sellList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    sellList[i],
                    router.getWethAddress(),
                    sellListAmountsIn[i],
                    sellListAmountsOut[i],
                )
                if len(path) > 0:
                    print("Sell", sellListAmountsIn[i], sellListAmountsOut[i], path)
                    detf.swap(
                        sellListAmountsIn[i],
                        sellListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    if len(adjustToSellList) > 0:
        (
            adjustToSellListAmountsIn,
            adjustToSellListAmountsOut,
        ) = rebalancer.createAdjustToSellOrder(adjustToSellList, detf.address)

        for i in range(0, len(adjustToSellList)):
            if adjustToSellList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    adjustToSellList[i],
                    router.getWethAddress(),
                    adjustToSellListAmountsIn[i],
                    adjustToSellListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Adjust To Sell",
                        adjustToSellListAmountsIn[i],
                        adjustToSellListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        adjustToSellListAmountsIn[i],
                        adjustToSellListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    # Begin buy orders
    (wethBalance, totalTargetPercentage) = rebalancer.calcTotalTargetBuyPercentage(
        adjustToBuyList, buyList, detf.address
    )

    if len(adjustToBuyList) > 0:
        (
            adjustToBuyListAmountsIn,
            adjustToBuyListAmountsOut,
        ) = rebalancer.createAdjustToBuyOrder(
            adjustToBuyList, totalTargetPercentage, detf.address
        )

        for i in range(0, len(adjustToBuyList)):
            if adjustToBuyList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    router.getWethAddress(),
                    adjustToBuyList[i],
                    adjustToBuyListAmountsIn[i],
                    adjustToBuyListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Adjust To Buy",
                        adjustToBuyListAmountsIn[i],
                        adjustToBuyListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        adjustToBuyListAmountsIn[i],
                        adjustToBuyListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    if len(buyList) > 0:
        (buyListAmountsIn, buyListAmountsOut) = rebalancer.createBuyOrder(
            buyList, wethBalance, totalTargetPercentage, detf.address
        )

        for i in range(0, len(buyList)):
            if buyList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    router.getWethAddress(),
                    buyList[i],
                    buyListAmountsIn[i],
                    buyListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Buy",
                        buyListAmountsIn[i],
                        buyListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        buyListAmountsIn[i],
                        buyListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    detf.updateOwnedAssetsForRebalance(
        adjustToSellList, adjustToBuyList, buyList, {"from": account}
    )


def main():
    account = get_account(type="owner")
    print("Account Owner Address", account.address)
    rebalancer = deploy_rebalancer.main(account)
    router = deploy_router.main(
        account,
        config["networks"][network.show_active()]["pancakeswap_factory_address"],
        config["networks"][network.show_active()]["weth_address"],
    )
    add_base_tokens_to_router(router, account)

    price_oracle_factory = deploy_price_oracle_factory.main(account)
    price_oracles = deploy_price_oracles(account, price_oracle_factory)

    detf_oracle_factory = deploy_DETF_oracle_factory.main(account)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        account, detf_oracle_factory.address, "Test DETF Name", 100, router.address
    )
    detf_oracle.setOracleStatus(1, {"from": account})
    add_assets_to_detf_oracle(account, detf_oracle, price_oracles)

    detf_factory = deploy_DETF_factory.main(
        account, config["networks"][network.show_active()]["weth_address"]
    )

    detf_factory.setPolybitRebalancerAddress(rebalancer.address, {"from": account})
    detf_factory.setPolybitRouterAddress(router.address, {"from": account})

    lockDuration = 10
    riskWeighting = 0
    detf = deploy_DETF_from_factory.main(
        account,
        detf_factory.address,
        account.address,
        detf_oracle.address,
        riskWeighting,
        lockDuration,
    )

    detf2 = deploy_DETF_from_factory.main(
        account,
        detf_factory.address,
        account.address,
        detf_oracle.address,
        riskWeighting,
        lockDuration,
    )

    print("DETFs owned by Account", detf_factory.getDETFAccounts(account.address))

    """ detf = deploy_DETF.main(
        account,
        detf_oracle.address,
        detf_oracle_factory.address,
        0,
        rebalancer.address,
        router.address,
        lockDuration,
    ) """

    """
    Data Check
    """
    for i in range(0, len(price_oracles)):
        price_oracle = Contract.from_abi(
            "Price Oracle", price_oracles[i], PolybitPriceOracle.abi
        )
        print("Price Oracle Address", price_oracles[i])
        print("Token Address", price_oracle.getTokenAddress())
        print("Token Symbol", price_oracle.getSymbol())
        print("Latest Price", price_oracle.getLatestPrice())

    print("Owned Assets", detf.getOwnedAssets())
    print("Target Assets", detf.getTargetAssets())

    DEPOSIT_AMOUNT = Web3.toWei(1, "ether")
    # Transfer ETH into wallet
    account.transfer(detf.address, DEPOSIT_AMOUNT)

    print("ETH Balance", detf.getEthBalance())

    """
    Addresses
    """
    print("Router", router.address)
    print("Rebalancer", rebalancer.address)
    print("Price Oracle Factory", price_oracle_factory.address)
    po_counter = 0
    for i in range(0, len(price_oracles)):
        po_counter = po_counter + 1
        print("Price Oracle", po_counter, price_oracles[i])
    print("DETF Oracle Factory", detf_oracle_factory.address)
    print("DETF Oracle", detf_oracle)
    print("DETF", detf.address)

    """
    REBALANCE #1
    """
    print("REBALANCE #1")
    print(
        "Sell List",
        rebalancer.createSellList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )
    adjustList = rebalancer.createAdjustList(
        detf.getOwnedAssets(), detf.getTargetAssets()
    )

    print("Adjust List", adjustList)
    print(
        "Adjust To Sell List",
        rebalancer.createAdjustToSellList(detf.address, adjustList),
    )
    print(
        "Adjust To Buy List", rebalancer.createAdjustToBuyList(detf.address, adjustList)
    )
    print(
        "Buy List",
        rebalancer.createBuyList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )

    rebalance(account, detf, rebalancer, router)

    owned_assets = detf.getOwnedAssets()
    print("Owned Assets", owned_assets)
    total_balance = detf.getTotalBalanceInWeth()
    print("Total Balance", total_balance)
    print("Total Balance %", round(total_balance / DEPOSIT_AMOUNT, 4))

    for i in range(0, len(owned_assets)):
        token_balance, token_balance_in_weth = detf.getTokenBalance(owned_assets[i])
        print(
            "Address",
            owned_assets[i],
            "Target",
            round(
                (detf_oracle.getTargetPercentage(owned_assets[i], 0) / 10**8),
                4,
            ),
            "Actual",
            round(token_balance_in_weth / total_balance, 4),
        )

    """
    REBALANCE #2
    """
    detf_oracle.removeAsset(owned_assets[0], {"from": account})

    print("REBALANCE #2")
    print(
        "Sell List",
        rebalancer.createSellList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )
    adjustList = rebalancer.createAdjustList(
        detf.getOwnedAssets(), detf.getTargetAssets()
    )

    print("Adjust List", adjustList)
    print(
        "Adjust To Sell List",
        rebalancer.createAdjustToSellList(detf.address, adjustList),
    )
    print(
        "Adjust To Buy List", rebalancer.createAdjustToBuyList(detf.address, adjustList)
    )
    print(
        "Buy List",
        rebalancer.createBuyList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )

    rebalance(account, detf, rebalancer, router)

    owned_assets = detf.getOwnedAssets()
    print("Owned Assets", owned_assets)
    total_balance = detf.getTotalBalanceInWeth()
    print("Total Balance", total_balance)
    print("Total Balance %", round(total_balance / DEPOSIT_AMOUNT, 4))

    for i in range(0, len(owned_assets)):
        token_balance, token_balance_in_weth = detf.getTokenBalance(owned_assets[i])
        print(
            "Address",
            owned_assets[i],
            "Target",
            round(
                (detf_oracle.getTargetPercentage(owned_assets[i], 0) / 10**8),
                4,
            ),
            "Actual",
            round(token_balance_in_weth / total_balance, 4),
        )

    """
    REBALANCE #3
    """
    tx = detf.setRiskWeighting(1, {"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

    print("REBALANCE #3")
    print(
        "Sell List",
        rebalancer.createSellList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )
    adjustList = rebalancer.createAdjustList(
        detf.getOwnedAssets(), detf.getTargetAssets()
    )

    print("Adjust List", adjustList)
    print(
        "Adjust To Sell List",
        rebalancer.createAdjustToSellList(detf.address, adjustList),
    )
    print(
        "Adjust To Buy List", rebalancer.createAdjustToBuyList(detf.address, adjustList)
    )
    print(
        "Buy List",
        rebalancer.createBuyList(detf.getOwnedAssets(), detf.getTargetAssets()),
    )

    rebalance(account, detf, rebalancer, router)

    owned_assets = detf.getOwnedAssets()
    print("Owned Assets", owned_assets)
    total_balance = detf.getTotalBalanceInWeth()
    print("Total Balance", total_balance)
    print("Total Balance %", round(total_balance / DEPOSIT_AMOUNT, 4))

    for i in range(0, len(owned_assets)):
        token_balance, token_balance_in_weth = detf.getTokenBalance(owned_assets[i])
        print(
            "Address",
            owned_assets[i],
            "Target",
            round(
                (detf_oracle.getTargetPercentage(owned_assets[i], 1) / 10**8),
                4,
            ),
            "Actual",
            round(token_balance_in_weth / total_balance, 4),
        )
