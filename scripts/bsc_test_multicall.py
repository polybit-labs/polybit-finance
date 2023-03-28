from brownie import config, network, Contract, PolybitMulticall, PolybitDETF
from scripts.utils.polybit_utils import get_account


def main():
    polybit_owner_account = get_account(type="polybit_owner")
    rebalancer_account = get_account(type="rebalancer_owner")
    router_account = get_account(type="router_owner")
    non_owner = get_account(type="non_owner")
    wallet_owner = get_account(type="wallet_owner")

    multicall = Contract.from_abi(
        "", "0x69a4E26ffE2CCde086248CF581A190Fb6cF17893", PolybitMulticall.abi
    )

    detf = Contract.from_abi(
        "", "0x9E228975c9a3e1168E946E29b61B02e9cAc1d3Aa", PolybitDETF.abi
    )

    print(
        multicall.getDETFAccountDetailFromWalletOwner(
            "0x1F131Ac2910242df1ee514127E748e7915DA8C52"
        )
    )

    print(detf.getProductCategory())
    print(detf.getProductDimension())
