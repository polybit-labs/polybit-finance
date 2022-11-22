from brownie import Contract, PolybitDETF, PolybitDETFFactory
from scripts.utils.polybit_utils import get_account


def create_detf(account, detf_factory, walletOwner):
    tx = detf_factory.createDETF(
        walletOwner,
        {"from": account},
    )
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])


def main(account, detf_factory_address, walletOwner):
    detf_factory_abi = PolybitDETFFactory.abi
    detf_factory = Contract.from_abi("detf", detf_factory_address, detf_factory_abi)
    create_detf(account, detf_factory, walletOwner)
    detf_address = detf_factory.getListOfDETFs()[-1]
    detf = Contract.from_abi("detf", detf_address, PolybitDETF.abi)
    return detf
