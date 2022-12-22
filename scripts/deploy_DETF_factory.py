from brownie import PolybitDETFFactory, network, config
from scripts.utils.polybit_utils import get_account


def deploy_detf_factory(account, polybit_access_address, polybit_config_address):
    detf_factory = PolybitDETFFactory.deploy(
        polybit_access_address,
        polybit_config_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return detf_factory


def main(account, polybit_access_address, polybit_config_address):
    detf_factory = deploy_detf_factory(account, polybit_access_address, polybit_config_address)
    return detf_factory
