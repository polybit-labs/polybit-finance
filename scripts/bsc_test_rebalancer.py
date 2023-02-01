from scripts import (
    deploy_access,
    deploy_config,
    deploy_rebalancer,
    deploy_router,
    deploy_DETF_factory,
    deploy_DETF_from_factory,
)
from scripts.utils.polybit_utils import get_account
from brownie import config, network, PolybitRebalancer, Contract, PolybitAccess, PolybitConfig
from pycoingecko import CoinGeckoAPI
from web3 import Web3
import time

def main():
    print(network.show_active())
    polybit_owner_account = get_account(type="polybit_owner")
    rebalancer_account = get_account(type="rebalancer_owner")
    router_account = get_account(type="router_owner")
    non_owner = get_account(type="non_owner")
    wallet_owner = get_account(type="wallet_owner")
    fee_address = get_account(type="polybit_fee_address")
    print("Polybit Owner", polybit_owner_account.address)

    polybit_config = Contract.from_abi("","0xDbeFE0B8d5cD3588fC1AB5C19aE9234CC1aef433",PolybitConfig.abi)
    polybit_access = Contract.from_abi("","0x38958Bd0b57d054548415a3D373381D121729BD1", PolybitAccess.abi)

    polybit_rebalancer = deploy_rebalancer.main(polybit_owner_account)

    tx = polybit_config.setPolybitRebalancerAddress(polybit_rebalancer.address,{"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Rebalancer Address", polybit_config.getPolybitRebalancerAddress())
    
    