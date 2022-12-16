from scripts import (
    deploy_rebalancer,
    deploy_router,
    deploy_DETF_factory,
    deploy_DETF_from_factory,
)
from scripts.utils.polybit_utils import get_account
from brownie import config, network
from pycoingecko import CoinGeckoAPI
from web3 import Web3
import time

cg = CoinGeckoAPI(api_key=config["data_providers"]["coingecko"])

BNBUSD = cg.get_coin_by_id("binancecoin")["market_data"]["current_price"]["usd"]

TEST_ONE_ASSETS = [
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "0xBf5140A22578168FD562DCcF235E5D43A02ce9B1",
    "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    # "0xfb6115445bff7b52feb98650c87f44907e58f802",  # $0 liquidity test token AAVE
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
    "0xbA552586eA573Eaa3436f04027ff4effd0c0abbb",
    "0x477bC8d23c634C154061869478bce96BE6045D12",
]

TEST_ONE_WEIGHTS = [
    10**8 * (1 / 6),
    10**8 * (1 / 6),
    10**8 * (1 / 6),
    10**8 * (1 / 6),
    10**8 * (1 / 6),
    10**8 * (1 / 6),
]

TEST_TWO_ASSETS = [
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "0xBf5140A22578168FD562DCcF235E5D43A02ce9B1",
    "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
]

TEST_TWO_WEIGHTS = [
    10**8 * (1 / 4),
    10**8 * (1 / 4),
    10**8 * (1 / 4),
    10**8 * (1 / 4),
]

TEST_THREE_ASSETS = [
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "0xBf5140A22578168FD562DCcF235E5D43A02ce9B1",
    "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
]

TEST_THREE_WEIGHTS = [
    10**8 * (0.0052),
    10**8 * (0.0144),
    10**8 * (0.313),
    10**8 * (0.6674),
]

TEST_FOUR_ASSETS = [
    "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82",
    "0xBf5140A22578168FD562DCcF235E5D43A02ce9B1",
    "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F",
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
    "0xbA552586eA573Eaa3436f04027ff4effd0c0abbb",
]

TEST_FOUR_WEIGHTS = [
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
]


def get_coingecko_price(token_address):
    token_price = 0
    while token_price > 0:
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


def rebalance(
    account,
    detf,
    rebalancer,
    router,
    owned_assets,
    owned_assets_prices,
    target_assets,
    target_assets_weights,
    target_assets_prices,
):

    (sellList, sellListPrices) = rebalancer.createSellList(
        owned_assets, owned_assets_prices, target_assets
    )
    print("Sell List", sellList)
    print("Sell List Prices", sellListPrices)

    (adjustList, adjustListWeights, adjustListPrices) = rebalancer.createAdjustList(
        owned_assets, owned_assets_prices, target_assets, target_assets_weights
    )
    print("Adjust List", adjustList)
    print("Adjust List Weights", adjustListWeights)
    print("Adjust List Prices", adjustListPrices)

    (
        adjustToSellList,
        adjustToSellWeights,
        adjustToSellPrices,
    ) = rebalancer.createAdjustToSellList(
        detf.address,
        owned_assets_prices,
        adjustList,
        adjustListWeights,
        adjustListPrices,
    )
    print("Adjust To Sell List", adjustToSellList)
    print("Adjust To Sell List Weights", adjustToSellWeights)
    print("Adjust To Sell List Prices", adjustToSellPrices)

    (
        adjustToBuyList,
        adjustToBuyWeights,
        adjustToBuyPrices,
    ) = rebalancer.createAdjustToBuyList(
        detf.address,
        owned_assets_prices,
        adjustList,
        adjustListWeights,
        adjustListPrices,
    )
    print("Adjust To Buy List", adjustToBuyList)
    print("Adjust To Buy List Weights", adjustToBuyWeights)
    print("Adjust To Buy List Prices", adjustToBuyPrices)

    (buyList, buyListWeights, buyListPrices) = rebalancer.createBuyList(
        owned_assets, target_assets, target_assets_weights, target_assets_prices
    )
    print("Buy List", buyList)
    print("Buy List Weights", buyListWeights)
    print("Buy List Prices", buyListPrices)

    wethBalance = detf.getWethBalance({"from": account})

    sellOrder = [
        [
            [],
            [],
            [],
            [],
        ]
    ]
    if len(sellList) > 0:
        (sellListAmountsIn, sellListAmountsOut) = rebalancer.createSellOrder(
            sellList, sellListPrices, detf.address
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
                    sellOrder[0][0].append("0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73")
                    sellOrder[0][1].append(path)
                    sellOrder[0][2].append(sellListAmountsIn[i])
                    sellOrder[0][3].append(sellListAmountsOut[i])
                    wethBalance = wethBalance + sellListAmountsOut[i]  # simulate SELL
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    adjustToSellOrder = [
        [
            [],
            [],
            [],
            [],
        ]
    ]
    if len(adjustToSellList) > 0:
        (
            adjustToSellListAmountsIn,
            adjustToSellListAmountsOut,
        ) = rebalancer.createAdjustToSellOrder(
            owned_assets_prices,
            adjustToSellList,
            adjustToSellWeights,
            adjustToSellPrices,
            detf.address,
        )

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
                    adjustToSellOrder[0][0].append(
                        "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
                    )
                    adjustToSellOrder[0][1].append(path)
                    adjustToSellOrder[0][2].append(adjustToSellListAmountsIn[i])
                    adjustToSellOrder[0][3].append(adjustToSellListAmountsOut[i])
                    wethBalance = wethBalance + adjustToSellListAmountsOut[i]
                    # simulate SELL
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    # Begin buy orders
    totalTargetPercentage = 0
    tokenBalances = 0
    totalBalance = 0
    if len(adjustList) > 0:
        for i in range(0, len(adjustList)):
            (tokenBalance, tokenBalanceInWeth) = detf.getTokenBalance(
                adjustList[i], adjustListPrices[i]
            )
            tokenBalances = tokenBalances + tokenBalanceInWeth
        totalBalance = tokenBalances + wethBalance

    for i in range(0, len(adjustToBuyList)):
        if adjustToBuyList[i] != "0x0000000000000000000000000000000000000000":
            (tokenBalance, tokenBalanceInWeth) = detf.getTokenBalance(
                adjustToBuyList[i], adjustToBuyPrices[i]
            )
            tokenBalancePercentage = (10**8 * tokenBalanceInWeth) / totalBalance
            targetPercentage = adjustToBuyWeights[i]
            totalTargetPercentage += targetPercentage - tokenBalancePercentage

    for i in range(0, len(buyList)):
        if buyList[i] != "0x0000000000000000000000000000000000000000":
            targetPercentage = buyListWeights[i]
            totalTargetPercentage += targetPercentage

    adjustToBuyOrder = [
        [
            [],
            [],
            [],
            [],
        ]
    ]

    if len(adjustToBuyList) > 0:
        (
            adjustToBuyListAmountsIn,
            adjustToBuyListAmountsOut,
        ) = rebalancer.createAdjustToBuyOrder(
            totalBalance,
            wethBalance,
            adjustToBuyList,
            adjustToBuyWeights,
            adjustToBuyPrices,
            totalTargetPercentage,
            detf.address,
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
                    adjustToBuyOrder[0][0].append(
                        "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
                    )
                    adjustToBuyOrder[0][1].append(path)
                    adjustToBuyOrder[0][2].append(adjustToBuyListAmountsIn[i])
                    adjustToBuyOrder[0][3].append(adjustToBuyListAmountsOut[i])

                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    buyOrder = [
        [
            [],
            [],
            [],
            [],
        ]
    ]
    if len(buyList) > 0:
        (buyListAmountsIn, buyListAmountsOut) = rebalancer.createBuyOrder(
            buyList, buyListWeights, buyListPrices, wethBalance, totalTargetPercentage
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
                    buyOrder[0][0].append("0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73")
                    buyOrder[0][1].append(path)
                    buyOrder[0][2].append(buyListAmountsIn[i])
                    buyOrder[0][3].append(buyListAmountsOut[i])

                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    orderData = [
        [
            sellList,
            sellListPrices,
            sellOrder,
            adjustList,
            adjustListPrices,
            adjustToSellList,
            adjustToSellPrices,
            adjustToSellOrder,
            adjustToBuyList,
            adjustToBuyWeights,
            adjustToBuyPrices,
            adjustToBuyOrder,
            buyList,
            buyListWeights,
            buyListPrices,
            buyOrder,
        ]
    ]
    print("Order Data", orderData)

    tx = detf.rebalance(
        orderData,
        {"from": account},
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])


def get_owned_assets(detf):
    owned_assets = detf.getOwnedAssets()
    owned_assets_prices = []
    print("Getting owned asset prices from CoinGecko")

    for i in range(0, len(owned_assets)):
        try:
            owned_assets_prices.append(
                int(
                    cg.get_coin_info_from_contract_address_by_id(
                        id="binance-smart-chain",
                        contract_address=owned_assets[i],
                    )["market_data"]["current_price"]["bnb"]
                    * 10**18
                )
            )
        except:
            owned_assets_prices.append(
                int(
                    cg.get_coin_info_from_contract_address_by_id(
                        id="binance-smart-chain",
                        contract_address=owned_assets[i].lower(),
                    )["market_data"]["current_price"]["bnb"]
                    * 10**18
                )
            )

    return owned_assets, owned_assets_prices


def get_target_assets(detf, target_assets, target_assets_weights):
    target_assets_prices = []
    print("Getting target asset prices from CoinGecko")
    for i in range(0, len(target_assets)):
        try:
            target_assets_prices.append(
                int(
                    cg.get_coin_info_from_contract_address_by_id(
                        id="binance-smart-chain",
                        contract_address=target_assets[i],
                    )["market_data"]["current_price"]["bnb"]
                    * 10**18
                )
            )
        except:
            target_assets_prices.append(
                int(
                    cg.get_coin_info_from_contract_address_by_id(
                        id="binance-smart-chain",
                        contract_address=target_assets[i].lower(),
                    )["market_data"]["current_price"]["bnb"]
                    * 10**18
                )
            )
    return target_assets, target_assets_weights, target_assets_prices


def run_rebalance(account, detf, rebalancer, router, assets, weights):
    (owned_assets, owned_assets_prices) = get_owned_assets(detf)
    (
        target_assets,
        target_assets_weights,
        target_assets_prices,
    ) = get_target_assets(detf, assets, weights)
    print("Owned Assets Before:", owned_assets)
    print("Target Assets Before:", target_assets)

    rebalance(
        account,
        detf,
        rebalancer,
        router,
        owned_assets,
        owned_assets_prices,
        target_assets,
        target_assets_weights,
        target_assets_prices,
    )

    (owned_assets, owned_assets_prices) = get_owned_assets(detf)
    (
        target_assets,
        target_assets_weights,
        target_assets_prices,
    ) = get_target_assets(detf, assets, weights)
    print("Owned Assets After:", owned_assets)
    print("Target Assets After:", target_assets)

    total_balance = detf.getTotalBalanceInWeth(owned_assets_prices)
    print("Total Balance", total_balance)
    print("Total Balance %", round(total_balance / detf.getTotalDeposited(), 4))

    for i in range(0, len(owned_assets)):
        token_balance, token_balance_in_weth = detf.getTokenBalance(
            owned_assets[i], owned_assets_prices[i]
        )
        for x in range(0, len(assets)):
            if owned_assets[i] == assets[x]:
                print(
                    "Address",
                    owned_assets[i],
                    "Target",
                    round(
                        (weights[x] / 10**8),
                        4,
                    ),
                    "Actual",
                    round(token_balance_in_weth / total_balance, 4),
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

    detf_factory = deploy_DETF_factory.main(
        account, config["networks"][network.show_active()]["weth_address"]
    )

    detf_factory.setPolybitRebalancerAddress(rebalancer.address, {"from": account})
    detf_factory.setPolybitRouterAddress(router.address, {"from": account})
    detf_factory.setDepositFee(0, {"from": account})
    detf_factory.setFeeAddress(account.address, {"from": account})

    product_id = 5610001000
    product_category = "BSC Index Top 10"
    product_dimension = "Market Cap"

    """ detf = deploy_DETF_from_factory.main(
        account,
        detf_factory.address,
        account.address,
        product_id,
        product_category,
        product_dimension,
    )

    print("Product ID", detf.getProductId())
    print("Product Category", detf.getProductCategory())
    print("Product Dimension", detf.getProductDimension()) """

    """
    Data Check
    """
    print("Owned Assets", detf.getOwnedAssets())
    print("ETH Balance", detf.getEthBalance())

    """
    Addresses
    """
    print("router", router.address)
    print("rebalancer", rebalancer.address)
    print("detf_factory", detf_factory.address)

    print("DETF ABI")
    print(detf.abi)

    print("DETF Factory ABI")
    print(detf_factory.abi)

    print("Rebalancer ABI")
    print(rebalancer.abi)

    print("Router ABI")
    print(router.abi)

    lockDuration = 30 * 86400
    deposit_amount = Web3.toWei(0.001, "ether")
    """ tx = detf.deposit(
        time.time() + lockDuration, {"from": account, "value": deposit_amount}
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i]) """

    """
    REBALANCE #1
    """
    """print("REBALANCE #1")
    run_rebalance(
        account,
        detf,
        rebalancer,
        router,
        TEST_ONE_ASSETS,
        TEST_ONE_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited())"""

    """
    REBALANCE #2
    """
    """ print("REBALANCE #2")
    run_rebalance(
        account,
        detf,
        rebalancer,
        router,
        TEST_TWO_ASSETS,
        TEST_TWO_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited()) """

    """
    REBALANCE #3
    """
    """ print("REBALANCE #3")
    run_rebalance(
        account,
        detf,
        rebalancer,
        router,
        TEST_THREE_ASSETS,
        TEST_THREE_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited()) """

    """
    REBALANCE #4
    """
    """ print("REBALANCE #4")

    detf.deposit(
        time.time() + lockDuration, {"from": account, "value": Web3.toWei(5, "ether")}
    )
    run_rebalance(
        account,
        detf,
        rebalancer,
        router,
        TEST_FOUR_ASSETS,
        TEST_FOUR_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited()) """
