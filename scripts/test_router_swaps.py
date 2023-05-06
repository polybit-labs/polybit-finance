from scripts import deploy_liquid_path, deploy_swap_router
from scripts.utils.polybit_utils import get_account
from brownie import (
    config,
    network,
    PolybitSwapRouter,
    PolybitLiquidPath,
    Contract,
    PolybitAccess,
    PolybitConfig)
from web3 import Web3
import json
import pandas as pd
import urllib.request, json
import time

WETH = config["networks"]["bsc-main"]["weth_address"]
IERC20 = [
    {
        "constant": False,
        "inputs": [
            {
                "name": "_spender",
                "type": "address"
            },
            {
                "name": "_value",
                "type": "uint256"
            }
        ],
        "name": "approve",
        "outputs": [
            {
                "name": "",
                "type": "bool"
            }
        ],
        "payable": False,
        "stateMutability": "nonpayable",
        "type": "function"
    }
]

FACTORY_ABI = [{"constant":True,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"getPair","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"}]
PAIR_ABI = [{"inputs":[],"payable":False,"stateMutability":"nonpayable","type":"constructor"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"address","name":"owner","type":"address"},{"indexed":True,"internalType":"address","name":"spender","type":"address"},{"indexed":False,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Approval","type":"event"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"address","name":"sender","type":"address"},{"indexed":False,"internalType":"uint256","name":"amount0","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amount1","type":"uint256"},{"indexed":True,"internalType":"address","name":"to","type":"address"}],"name":"Burn","type":"event"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"address","name":"sender","type":"address"},{"indexed":False,"internalType":"uint256","name":"amount0","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amount1","type":"uint256"}],"name":"Mint","type":"event"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"address","name":"sender","type":"address"},{"indexed":False,"internalType":"uint256","name":"amount0In","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amount1In","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amount0Out","type":"uint256"},{"indexed":False,"internalType":"uint256","name":"amount1Out","type":"uint256"},{"indexed":True,"internalType":"address","name":"to","type":"address"}],"name":"Swap","type":"event"},{"anonymous":False,"inputs":[{"indexed":False,"internalType":"uint112","name":"reserve0","type":"uint112"},{"indexed":False,"internalType":"uint112","name":"reserve1","type":"uint112"}],"name":"Sync","type":"event"},{"anonymous":False,"inputs":[{"indexed":True,"internalType":"address","name":"from","type":"address"},{"indexed":True,"internalType":"address","name":"to","type":"address"},{"indexed":False,"internalType":"uint256","name":"value","type":"uint256"}],"name":"Transfer","type":"event"},{"constant":True,"inputs":[],"name":"DOMAIN_SEPARATOR","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"MINIMUM_LIQUIDITY","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"PERMIT_TYPEHASH","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"","type":"address"},{"internalType":"address","name":"","type":"address"}],"name":"allowance","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"}],"name":"approve","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"to","type":"address"}],"name":"burn","outputs":[{"internalType":"uint256","name":"amount0","type":"uint256"},{"internalType":"uint256","name":"amount1","type":"uint256"}],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"decimals","outputs":[{"internalType":"uint8","name":"","type":"uint8"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"factory","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"getReserves","outputs":[{"internalType":"uint112","name":"_reserve0","type":"uint112"},{"internalType":"uint112","name":"_reserve1","type":"uint112"},{"internalType":"uint32","name":"_blockTimestampLast","type":"uint32"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"_token0","type":"address"},{"internalType":"address","name":"_token1","type":"address"}],"name":"initialize","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"kLast","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"to","type":"address"}],"name":"mint","outputs":[{"internalType":"uint256","name":"liquidity","type":"uint256"}],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"name","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"nonces","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"owner","type":"address"},{"internalType":"address","name":"spender","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"uint8","name":"v","type":"uint8"},{"internalType":"bytes32","name":"r","type":"bytes32"},{"internalType":"bytes32","name":"s","type":"bytes32"}],"name":"permit","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"price0CumulativeLast","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"price1CumulativeLast","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"to","type":"address"}],"name":"skim","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":False,"inputs":[{"internalType":"uint256","name":"amount0Out","type":"uint256"},{"internalType":"uint256","name":"amount1Out","type":"uint256"},{"internalType":"address","name":"to","type":"address"},{"internalType":"bytes","name":"data","type":"bytes"}],"name":"swap","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"symbol","outputs":[{"internalType":"string","name":"","type":"string"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[],"name":"sync","outputs":[],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":True,"inputs":[],"name":"token0","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"token1","outputs":[{"internalType":"address","name":"","type":"address"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":True,"inputs":[],"name":"totalSupply","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"payable":False,"stateMutability":"view","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"}],"name":"transfer","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":False,"stateMutability":"nonpayable","type":"function"},{"constant":False,"inputs":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"}],"name":"transferFrom","outputs":[{"internalType":"bool","name":"","type":"bool"}],"payable":False,"stateMutability":"nonpayable","type":"function"}]

def get_approved_list():
    approved_list_url = "https://raw.githubusercontent.com/polybit-labs/token-list/main/polybit-labs.tokenlist.json"
    with urllib.request.urlopen(approved_list_url) as url:
        approved_list = json.load(url)
    approved_token_list = []
    for i in range(0, len(approved_list["tokens"])):
        approved_token_list.append(
            Web3.toChecksumAddress(approved_list["tokens"][i]["address"])
        )
    return approved_token_list


def main():
    polybit_owner_account = get_account(type="polybit_owner")
    print("Polybit Owner", polybit_owner_account.address)

    polybit_swap_router = deploy_swap_router.main(
        polybit_owner_account,
    )

    """ polybit_swap_router = Contract.from_abi("","0x2dc9C40916D7a23257F269DF0fa4ed788558ED18",PolybitSwapRouter.abi)

    polybit_liquid_path = deploy_liquid_path.main(
        polybit_owner_account,
        polybit_swap_router.address
    ) """

    print("Swap Router Address",polybit_swap_router.address)
    #print("Swap Router ABI",polybit_swap_router.abi)

    """ print("Liquid Path Address",polybit_liquid_path.address)
    #print("Liquid Path ABI",polybit_liquid_path.abi)

    CAKE = "0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82"
    ALPACA = "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F"

    approved_list = get_approved_list() """

    """
    Test amountOut
    """
    """ amount_in = 10*10**18
    amount_type = 0
    slippage = 0.01

    factory_address, path, amount_out = polybit_liquid_path.getLiquidPath(WETH,CAKE,amount_in,amount_type)
    print("AmountsOut", factory_address, path, amount_out)

    amount_out_min = amount_out * (1-slippage) """
    """ tx = polybit_swap_router.swapExactETHForTokens(
        factory_address,
        path,
        amount_out_min,
        polybit_owner_account.address,
        int(time.time() + 300),
        {"from":polybit_owner_account, "value":amount_in}
    )
    tx.wait(1) """

    """
    Test amountIn
    """
    """ amount_out = 10*10**18
    amount_type = 1
    slippage = 0.01

    factory_address, path, amount_in = polybit_liquid_path.getLiquidPath(WETH,CAKE,amount_out,amount_type)
    print("AmountsIn", factory_address, path, amount_in)

    print("OG AmountsOut",polybit_swap_router.getAmountsOut(
        "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
        10*10**18,
        [WETH,CAKE]))
    
    print("OG AmountsIn",polybit_swap_router.getAmountsIn(
        "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
        10*10**18,
        [WETH,CAKE]))
    
    print("OG AmountsIn sushi",polybit_swap_router.getAmountsIn(
        "0xc35DADB65012eC5796536bD9864eD8773aBc74C4",
        10*10**18,
        [WETH,CAKE]))

    amount_in_max = amount_in * (1+slippage) """
    """ tx = polybit_swap_router.swapETHForExactTokens(
        factory_address,
        path,
        amount_in_max,
        polybit_owner_account.address,
        int(time.time() + 300),
        {"from":polybit_owner_account, "value":amount_in_max}
    )
    tx.wait(1) """

    """
    Test amountsIn tripath
    """
    """ weth_address = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    busd_address = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
    alpaca_address = "0x8F0528cE5eF7B51152A59745bEfDD91D97091d2F"
    biswap_factory = "0x858E3312ed3A876947EA49d572A7C42DE08af7EE"
    amount_in = polybit_liquid_path.getAmountsIn(
        biswap_factory,
        1000000000000000000*10**18,
        [weth_address,busd_address,alpaca_address])
    
    print(amount_in) """

    """for i in range(0,len(approved_list)):
        try:
            factory_address, path, amount_out = polybit_liquid_path.getLiquidPath(WETH,approved_list[i],amount_in,amount_type)
            amount_out_min = amount_out * (1-.03)
            tx = polybit_swap_router.swapExactETHForTokens(
                factory_address,
                path,
                amount_out_min,
                polybit_owner_account.address,
                int(time.time() + 300),
                {"from":polybit_owner_account, "value":amount_in}
            )

        except:
            print(approved_list[i],"failed")

    tx.wait(1) """
    """ tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i]) """
    
    """     token = Contract.from_abi("",WETH,IERC20)
    tx = token.approve(polybit_router.address, amount_in, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i])  """
    """ factory_contract = Contract.from_abi("",factory_address,FACTORY_ABI )
    pair_address = factory_contract.getPair(token_address,WETH)
    #pair_contract = Contract.from_abi("",pair_address,FACTORY_ABI )

    tx = token.approve(pair_address, amount_in, {"from":polybit_owner_account})
    tx.wait(1)
    for i in range(0, len(tx.events)):
        print(tx.events[i]) """
    

    """     tx = polybit_router.swapTokens(
        factory_address,
        path,
        amount_in,
        amount_out_min,
        polybit_owner_account.address,
        int(time.time() + 300),
        {"from":polybit_owner_account}) """
    
