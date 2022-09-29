from scripts import (
    deploy_DETF,
    deploy_price_oracle_factory,
    deploy_price_oracle_from_factory,
    deploy_DETF_oracle_factory,
    deploy_DETF_oracle_from_factory,
    deploy_rebalancer,
    deploy_router,
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


def main():
    account = get_account(type="owner")
    router = deploy_router.main(
        account,
        config["networks"][network.show_active()]["pancakeswap_factory_address"],
        config["networks"][network.show_active()]["weth_address"],
    )
    add_base_tokens_to_router(router, account)

    price_oracle_factory = deploy_price_oracle_factory.main(account)
    price_oracles = deploy_price_oracles(account, price_oracle_factory)

    detf_factory = deploy_DETF_oracle_factory.main(account)

    detf_oracle = deploy_DETF_oracle_from_factory.main(
        account, detf_factory.address, "Test DETF Name", "Tes DETF ID", router.address
    )
    rebalancer = deploy_rebalancer.main(account)

    lockDuration = 10

    detf = deploy_DETF.main(
        account,
        detf_oracle.address,
        detf_factory.address,
        0,
        rebalancer.address,
        router.address,
        lockDuration,
    )

    add_assets_to_detf_oracle(account, detf_oracle, price_oracles)

    target_list = detf_oracle.getTargetList()

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

    tx = detf.wrapETH({"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

    """
    REBALANCE #1
    """
    tx = detf.rebalance({"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

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

    tx = detf.rebalance({"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

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

    tx = detf.rebalance({"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])

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
