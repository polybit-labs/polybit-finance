from brownie import PolybitConfig, network, config
from scripts.utils.polybit_utils import get_account

def deploy_polybit_config(account, polybit_access_address):
    polybit_config = PolybitConfig.deploy(
        polybit_access_address,
        config["networks"][network.show_active()]["weth_address"],
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return polybit_config

def main(account, polybit_access_address):
    polybit_config = deploy_polybit_config(account, polybit_access_address)
    return polybit_config
