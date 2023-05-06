from scripts import deploy_liquid_path
from scripts.utils.polybit_utils import get_account
from brownie import (
    config,
    network,
    PolybitRouter,
    Contract,
    PolybitAccess,
    PolybitConfig,
)
from web3 import Web3


def main():
    polybit_owner_account = get_account(type="polybit_owner")
    print("Polybit Owner", polybit_owner_account.address)

    polybit_config = Contract.from_abi(
        "", "0x4A48402A0d3263D090A73bD8f3F19487bA0907db", PolybitConfig.abi
    )
    polybit_access = Contract.from_abi(
        "", "0x502C8da60d4A8847D5549A1858EA899478a05A7c", PolybitAccess.abi
    )

    polybit_router = deploy_liquid_path.main(
        polybit_owner_account,
    )
    tx = polybit_config.setPolybitRouterAddress(
        polybit_router.address, {"from": polybit_owner_account}
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Router Address", polybit_config.getPolybitRouterAddress())
    print("Router ABI", polybit_router.abi)
