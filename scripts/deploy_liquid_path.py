from brownie import PolybitLiquidPath, network, config
from scripts.utils.polybit_utils import get_account

WETH = config["networks"]["bsc-main"]["weth_address"]
PANCAKESWAP_V2_FACTORY = config["networks"]["bsc-main"]["pancakeswap_factory_address"]
SUSHISWAP_V2_FACTORY = "0xc35DADB65012eC5796536bD9864eD8773aBc74C4"
BISWAP_FACTORY = "0x858E3312ed3A876947EA49d572A7C42DE08af7EE"
TEST_WETH = "0xE188A6B87fc5964c0f340a7745a1d9CB7baA0B05"
POLYBITSWAP_FACTORY = "0x1c12836972879e62BD2350987A38577C5b1757c2"


def deploy_liquid_path(
    account,
    polybit_swap_router_address
):
    liquid_path = PolybitLiquidPath.deploy(
        [WETH, polybit_swap_router_address, PANCAKESWAP_V2_FACTORY, SUSHISWAP_V2_FACTORY, BISWAP_FACTORY],
        #[TEST_WETH, POLYBITSWAP_FACTORY],
        {"from": account},
        publish_source=False,
    )
    return liquid_path


def main(account, polybit_swap_router_address):
    liquid_path = deploy_liquid_path(
        account,
        polybit_swap_router_address
    )
    return liquid_path
