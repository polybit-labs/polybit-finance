from scripts import (
    deploy_access,
    deploy_config,
    deploy_rebalancer,
    deploy_router,
    deploy_DETF_factory,
    deploy_DETF_from_factory,
)
from scripts.utils.polybit_utils import get_account
from brownie import config, network, PolybitRouter, Contract, PolybitAccess, PolybitConfig
from pycoingecko import CoinGeckoAPI
from web3 import Web3
import time

def add_base_tokens_to_router(router, account):
    tx = router.addBaseToken(
        config["networks"][network.show_active()]["weth_address"],
        {"from": account},
    )
    tx.wait(1)

    tx = router.addBaseToken(
        config["networks"][network.show_active()]["busd_address"],
        {"from": account},
    )
    tx.wait(1)

    tx = router.addBaseToken(
        config["networks"][network.show_active()]["usdt_address"],
        {"from": account},
    )
    tx.wait(1)

    tx = router.addBaseToken(
        config["networks"][network.show_active()]["usdc_address"],
        {"from": account},
    )
    tx.wait(1)

def main():
    print(network.show_active())
    polybit_owner_account = get_account(type="polybit_owner")
    rebalancer_account = get_account(type="rebalancer_owner")
    router_account = get_account(type="router_owner")
    non_owner = get_account(type="non_owner")
    wallet_owner = get_account(type="wallet_owner")
    fee_address = get_account(type="polybit_fee_address")
    print("Polybit Owner", polybit_owner_account.address)

    #polybit_router = Contract.from_abi("","0x33dC9335C1048B8e970601Ccd17De3D6407EEbFA",PolybitRouter.abi)


    polybit_config = Contract.from_abi("","0xc3D2aab8024396D35cB41417F888c7bB21a329f5",PolybitConfig.abi)
    polybit_access = Contract.from_abi("","0x7A18aFFFA76D74DfB9Bf2A920ccEd2FfB33ce811", PolybitAccess.abi)

    polybit_router = deploy_router.main(
        polybit_owner_account,
        polybit_access.address,
        polybit_config.address,
        config["networks"][network.show_active()]["pancakeswap_factory_address"],
    )
    add_base_tokens_to_router(polybit_router, polybit_access.routerOwner())

    tx = polybit_config.setPolybitRouterAddress(polybit_router.address,{"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])
    print("Router Address", polybit_config.getPolybitRouterAddress())
    
    ##
    #Deploy Router
    ##
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a",174925458000000000,8195456283205742075))
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x629495808b0BdE749e4058832CCf2D1cdA4abCeF",22888846000000000,1801414602818816877))

    #['0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a', '0x629495808b0BdE749e4058832CCf2D1cdA4abCeF', '0x7049d503d845A32C174C1d8EA2a8A7AaD05672D7', '0x337E22035DC87Acd5D182B62A0F056aBAFF1e63C']
    #[174925458000000000, 22888846000000000, 1477854000000000, 707840000000000]
    #[8195456283205742075, 1801414602818816877, 1513465851485452702, 978287609702162946]

    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x7049d503d845A32C174C1d8EA2a8A7AaD05672D7",1477854000000000,1513465851485452702))
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x337E22035DC87Acd5D182B62A0F056aBAFF1e63C",707840000000000,978287609702162946))

    """ ['0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a', '0x629495808b0BdE749e4058832CCf2D1cdA4abCeF', '0x7049d503d845A32C174C1d8EA2a8A7AaD05672D7', '0x337E22035DC87Acd5D182B62A0F056aBAFF1e63C']
    [174925458000000000, 22888846000000000, 1477854000000000, 707840000000000]
    [8148153610168757286, 1795362726265151342, 1513837927537567991, 976317568033544364] """

    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a",174925458000000000,8148153610168757286))
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x629495808b0BdE749e4058832CCf2D1cdA4abCeF",22888846000000000,1795362726265151342))
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x7049d503d845A32C174C1d8EA2a8A7AaD05672D7",1477854000000000,1513837927537567991))
    #print(polybit_router.getLiquidPath("0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x337E22035DC87Acd5D182B62A0F056aBAFF1e63C",707840000000000,976317568033544364))
    print(polybit_router.getAmountsOut(174925458000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a"]))
    #print(polybit_router.getAmountsOut(174925458000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0xE3c966bc5529aD7219B49F69Ab01AC05d0E153F6", "0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a"]))
    #print(polybit_router.getAmountsOut(174925458000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x3F0ab9b22e64645a1BEfA84f6B888C71A2798c94", "0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a"]))
    #print(polybit_router.getAmountsOut(174925458000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0xd533F685Ae10F7DD61eCC03fbe47358084b4E8ac", "0x8DDa9b090421D031617Bde0766Dc1EC27AB4c33a"]))

    print(polybit_router.getAmountsOut(22888846000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x629495808b0BdE749e4058832CCf2D1cdA4abCeF"]))
    print(polybit_router.getAmountsOut(1477854000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x7049d503d845A32C174C1d8EA2a8A7AaD05672D7"]))
    print(polybit_router.getAmountsOut(707840000000000,["0x652415C1E99FE1dD82b18C55C8Fe74B1EE933243","0x337E22035DC87Acd5D182B62A0F056aBAFF1e63C"]))
    print(8141309498621994604 / 8148153610168757286)
    print(1790920691512487094 / 1795362726265151342)
    print(1505546075360057396 / 1513837927537567991)
    print(976317568033544364 / 981721493772518134 )

