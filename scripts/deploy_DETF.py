from brownie import PolybitDETF, network, config
from scripts.utils.polybit_utils import get_account


def deploy_detf(account):
    polybit_detf = PolybitDETF.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return polybit_detf


def main(account):
    polybit_detf = deploy_detf(account)
    return polybit_detf
