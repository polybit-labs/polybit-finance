from brownie import Contract, PolybitDETFOracle, PolybitDETFOracleFactory
from scripts.utils.polybit_utils import get_account


def create_oracle(
    account,
    oracle_factory,
    portfolio_name,
    portfolio_id,
    polybitRouterAddress,
    weth_address,
    pancakeswap_factory_address,
):
    tx = oracle_factory.createOracle(
        portfolio_name,
        portfolio_id,
        polybitRouterAddress,
        weth_address,
        pancakeswap_factory_address,
        {"from": account},
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])


def main(
    account,
    oracle_factory_address,
    detfName,
    detfId,
    polybitRouterAddress,
    weth_address,
    pancakeswap_factory_address,
):
    oracle_factory_abi = PolybitDETFOracleFactory.abi
    oracle_factory = Contract.from_abi(
        "oracle", oracle_factory_address, oracle_factory_abi
    )
    create_oracle(
        account,
        oracle_factory,
        detfName,
        detfId,
        polybitRouterAddress,
        weth_address,
        pancakeswap_factory_address,
    )
    oracle_address = oracle_factory.getListOfOracles()[-1]
    oracle = Contract.from_abi("oracle", oracle_address, PolybitDETFOracle.abi)
    return oracle
