from brownie import PolybitRouter, network, config
from scripts.utils.polybit_utils import get_account


def deploy_router(account, polybit_access_address, polybit_config_address, factory_address):
    router = PolybitRouter.deploy(
        polybit_access_address,
        polybit_config_address,
        factory_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return router


def main(account, polybit_access_address, polybit_config_address, factory_address):
    router = deploy_router(account, polybit_access_address, polybit_config_address, factory_address)
    return router
