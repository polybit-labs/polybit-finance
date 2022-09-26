from brownie import PolybitRouter, network, config
from scripts.utils.polybit_utils import get_account


def deploy_router(account, factory_address, weth_address):
    router = PolybitRouter.deploy(
        factory_address,
        weth_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return router


def main(account, factory_address, weth_address):
    router = deploy_router(account, factory_address, weth_address)
    return router
