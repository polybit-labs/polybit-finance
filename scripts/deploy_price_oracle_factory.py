from brownie import PolybitPriceOracleFactory, network, config
from scripts.utils.polybit_utils import get_account


def deploy_price_oracle_factory(account):
    oracle_factory = PolybitPriceOracleFactory.deploy(
        account.address,
        config["polybit-finance"]["version"],  # Oracle Factory version
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return oracle_factory


def main(account):
    oracle_factory = deploy_price_oracle_factory(account)
    return oracle_factory
