from brownie import PolybitDETFFactory, network, config
from scripts.utils.polybit_utils import get_account


def deploy_detf_factory(account, weth_address):
    detf_factory = PolybitDETFFactory.deploy(
        account.address,
        weth_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return detf_factory


def main(account, weth_address):
    detf_factory = deploy_detf_factory(account, weth_address)
    return detf_factory
