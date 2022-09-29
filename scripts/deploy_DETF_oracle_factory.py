from brownie import PolybitDETFOracleFactory, network, config
from scripts.utils.polybit_utils import get_account


def deploy_oracle_factory(account):
    oracle_factory = PolybitDETFOracleFactory.deploy(
        account.address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return oracle_factory


def main(account):
    oracle_factory = deploy_oracle_factory(account)
    return oracle_factory
