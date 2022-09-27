from brownie import PolybitDETF, network, config
from scripts.utils.polybit_utils import get_account


def deploy_detf(
    account,
    detfOracleAddress,
    polybitDETFOracleFactoryAddress,
    riskWeighting,
    rebalancerAddress,
    pancakeswap_router_address,
):
    detf = PolybitDETF.deploy(
        # "0.0.1",  # DETF version
        detfOracleAddress,
        polybitDETFOracleFactoryAddress,
        riskWeighting,
        rebalancerAddress,
        pancakeswap_router_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()]["verify"],
    )
    return detf


def main(
    account,
    detfOracleAddress,
    polybitDETFOracleFactoryAddress,
    riskWeighting,
    rebalancerAddress,
    pancakeswap_router_address,
):
    detf = deploy_detf(
        account,
        detfOracleAddress,
        polybitDETFOracleFactoryAddress,
        riskWeighting,
        rebalancerAddress,
        pancakeswap_router_address,
    )
    return detf
