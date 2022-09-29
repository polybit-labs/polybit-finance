from brownie import PolybitRebalancer, network, config
from scripts.utils.polybit_utils import get_account


def deploy_rebalancer(account):
    rebalancer = PolybitRebalancer.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return rebalancer


def main(account):
    rebalancer = deploy_rebalancer(
        account,
    )
    return rebalancer
