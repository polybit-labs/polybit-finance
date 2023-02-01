from scripts import (
    deploy_access,
    deploy_config,
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
    "0x949D48EcA67b17269629c7194F4b727d4Ef9E5d6",
    "0x477bC8d23c634C154061869478bce96BE6045D12",
]

TEST_ONE_WEIGHTS = [
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
    10**8 * (1 / 5),
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

def first_deposit_order_data(
    rebalancer,
    router,
    owned_assets,
    target_assets,
    target_assets_weights,
    target_assets_prices,
    weth_input_amount):
    (buyList, buyListWeights, buyListPrices) = rebalancer.createBuyList(
        owned_assets, target_assets, target_assets_weights, target_assets_prices
    )
    print("Buy List", buyList)
    print("Buy List Weights", buyListWeights)
    print("Buy List Prices", buyListPrices)

    wethBalance = int(weth_input_amount)

    # Begin buy orders
    totalTargetPercentage = 0
    tokenBalances = 0
    totalBalance = 0

    for i in range(0, len(buyList)):
        if buyList[i] != "0x0000000000000000000000000000000000000000":
            targetPercentage = buyListWeights[i]
            totalTargetPercentage += targetPercentage

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
                time.sleep(3)
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
            [],
            [],
            [[[],[],[],[],]],
            [],
            [],
            [],
            [],
            [[[],[],[],[],]],
            [],
            [],
            [],
            [[[],[],[],[],]],
            buyList,
            buyListWeights,
            buyListPrices,
            buyOrder,
        ]
    ]
    print("Order Data", orderData)
    print("totalTargetPercentage",totalTargetPercentage)
    return orderData

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

    total_balance = detf.getTotalBalanceInWeth(owned_assets_prices)

    (
        adjustToSellList,
        adjustToSellWeights,
        adjustToSellPrices,
    ) = rebalancer.createAdjustToSellList(
        detf.address,
        total_balance,
        #owned_assets_prices,
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
        total_balance,
        #owned_assets_prices,
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

    print("totalTargetPercentage",totalTargetPercentage)

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

    tx = detf.rebalanceDETF(
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
    print(network.show_active())
    polybit_owner_account = get_account(type="polybit_owner")
    rebalancer_account = get_account(type="rebalancer_owner")
    router_account = get_account(type="router_owner")
    non_owner = get_account(type="non_owner")
    wallet_owner = get_account(type="wallet_owner")
    print("Polybit Owner", polybit_owner_account.address)
    
    ##
    #Deploy Polybit Access
    ##
    print("Deploying Access")
    polybit_access = deploy_access.main(polybit_owner_account)

    print("Polybit Owner", polybit_access.polybitOwner())
    print("Rebalancer Owner", polybit_access.rebalancerOwner())
    print("Router Owner", polybit_access.routerOwner())

    tx = polybit_access.transferRebalancerOwnership(rebalancer_account.address, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    
    tx = polybit_access.transferRouterOwnership(router_account.address, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

    print("Polybit Owner", polybit_access.polybitOwner())
    print("Rebalancer Owner", polybit_access.rebalancerOwner())
    print("Router Owner", polybit_access.routerOwner())

    ##
    #Deploy Config
    ##
    polybit_config = deploy_config.main(polybit_owner_account, polybit_access.address)
    
    tx = polybit_config.setDepositFee(50, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Deposit Fee", polybit_config.getDepositFee())

    tx = polybit_config.setPerformanceFee(1000, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Performance Fee", polybit_config.getPerformanceFee())

    tx = polybit_config.setFeeAddress(get_account(type="polybit_fee_address").address, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Fee Address",polybit_config.getFeeAddress())
    
    ##
    #Deploy Rebalancer
    ##
    polybit_rebalancer = deploy_rebalancer.main(polybit_owner_account)
    tx = polybit_config.setPolybitRebalancerAddress(polybit_rebalancer.address,{"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Rebalancer Address", polybit_config.getPolybitRebalancerAddress())

    ##
    #Deploy Router
    ##
    polybit_router = deploy_router.main(
        polybit_owner_account,
        polybit_access.address,
        polybit_config.address,
        config["networks"][network.show_active()]["pancakeswap_factory_address"],
    )
    add_base_tokens_to_router(polybit_router, polybit_access.routerOwner())

    tx = polybit_config.setPolybitRouterAddress(polybit_router.address,{"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Router Address", polybit_config.getPolybitRouterAddress())
     
    polybit_detf_factory = deploy_DETF_factory.main(
        polybit_owner_account, polybit_access.address, polybit_config.address
    )

    tx = polybit_config.setPolybitDETFFactoryAddress(polybit_detf_factory.address,{"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("DETF Factory Address", polybit_config.getPolybitDETFFactoryAddress())

    ##
    #Establish first DETF
    ##
    product_id = 5610001000
    product_category = "BSC Index Top 10"
    product_dimension = "Market Cap"

    detf = deploy_DETF_from_factory.main(
        polybit_owner_account,
        polybit_detf_factory.address,
        wallet_owner,
        product_id,
        product_category,
        product_dimension,
    )


    ##
    #Print Contract Info for Export
    ##
    print("router", polybit_router.address)
    print("rebalancer", polybit_rebalancer.address)
    print("detf_factory", polybit_detf_factory.address)
    print("config",polybit_config.address)

    """ print("DETF ABI")
    print(detf.abi) """

    print("DETF Factory ABI")
    print(polybit_detf_factory.abi)

    print("Rebalancer ABI")
    print(polybit_rebalancer.abi)

    print("Router ABI")
    print(polybit_router.abi)

    print("Config ABI")
    print(polybit_config.abi)

    ##
    #First Programmatic Deposit
    ##
    lock_duration = 30 * 86400
    deposit_amount = Web3.toWei(1, "ether")
    owned_assets = []
    (
        target_assets,
        target_assets_weights,
        target_assets_prices,
    ) = get_target_assets(detf, TEST_ONE_ASSETS,TEST_ONE_WEIGHTS)
    order_data = first_deposit_order_data(
    polybit_rebalancer,
    polybit_router,
    owned_assets,
    target_assets,
    target_assets_weights,
    target_assets_prices,
    deposit_amount)

    tx = detf.deposit(
        time.time() + lock_duration, order_data, {"from": wallet_owner, "value": deposit_amount}
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

    """deposit_fees = detf.getDepositFees()


    print("Deposit fee", deposit_fees) """
    print("account data", detf.getDETFAccountDetail())
    """ print("deposit fees",detf.fees()) """
    #print("%", deposit_fees/deposit_amount)
    """
    ##
    #First rebalance
    ##
    print("REBALANCE #1")
    run_rebalance(
        rebalancer_account,
        detf,
        polybit_rebalancer,
        polybit_router,
        TEST_ONE_ASSETS,
        TEST_ONE_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited())
    """
    ##
    #Second rebalance
    ##
    print("REBALANCE #2")
    run_rebalance(
        rebalancer_account,
        detf,
        polybit_rebalancer,
        polybit_router,
        TEST_TWO_ASSETS,
        TEST_TWO_WEIGHTS,
    )
    print("Deposits", detf.getDeposits())
    print("Total Deposits", detf.getTotalDeposited())  