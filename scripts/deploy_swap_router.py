from brownie import PolybitSwapRouter, network, config
from scripts.utils.polybit_utils import get_account

WETH = config["networks"]["bsc-main"]["weth_address"]


def deploy_swap_router(
    account,
):
    swap_router = PolybitSwapRouter.deploy(
        WETH,
        {"from": account},
        publish_source=False,
    )
    return swap_router


def main(account):
    swap_router = deploy_swap_router(
        account,
    )
    return swap_router
