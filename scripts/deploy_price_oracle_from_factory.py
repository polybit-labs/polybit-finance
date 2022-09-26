from brownie import Contract, PolybitPriceOracleFactory, PolybitPriceOracle
from scripts.utils.polybit_utils import get_account


def create_oracle(oracle_factory, account, token_address):
    tx = oracle_factory.createOracle(token_address, {"from": account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])


def main(account, oracle_factory_address, token_address):
    oracle_factory_abi = PolybitPriceOracleFactory.abi
    oracle_factory = Contract.from_abi(
        "oracle", oracle_factory_address, oracle_factory_abi
    )

    create_oracle(oracle_factory, account, token_address)

    price_oracle_address = oracle_factory.getOracle(
        len(oracle_factory.getListOfOracles()) - 1
    )

    price_oracle = Contract.from_abi(
        "Price Oracle", price_oracle_address, PolybitPriceOracle.abi
    )
    return price_oracle
