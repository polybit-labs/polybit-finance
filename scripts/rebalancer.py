from scripts.utils.polybit_utils import get_account
from brownie import (
    config,
    network,
    Contract,
    PolybitDETFFactory,
    PolybitDETF,
    PolybitRebalancer,
    PolybitRouter,
)
from web3 import Web3


def rebalance(account, detf, rebalancer, router):
    """detf.checkForDeposits({"from": account})"""
    (sellList, adjustToSellList, adjustToBuyList, buyList) = detf.getRebalancerLists()

    if len(sellList) > 0:
        (sellListAmountsIn, sellListAmountsOut) = rebalancer.createSellOrder(
            sellList, detf.address
        )

        for i in range(0, len(sellList)):
            if sellList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    sellList[i],
                    router.getWethAddress(),
                    sellListAmountsIn[i],
                    sellListAmountsOut[i],
                )
                if len(path) > 0:
                    print("Sell", sellListAmountsIn[i], sellListAmountsOut[i], path)
                    detf.swap(
                        sellListAmountsIn[i],
                        sellListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    if len(adjustToSellList) > 0:
        (
            adjustToSellListAmountsIn,
            adjustToSellListAmountsOut,
        ) = rebalancer.createAdjustToSellOrder(adjustToSellList, detf.address)

        for i in range(0, len(adjustToSellList)):
            if adjustToSellList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    adjustToSellList[i],
                    router.getWethAddress(),
                    adjustToSellListAmountsIn[i],
                    adjustToSellListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Adjust To Sell",
                        adjustToSellListAmountsIn[i],
                        adjustToSellListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        adjustToSellListAmountsIn[i],
                        adjustToSellListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    # Begin buy orders
    (wethBalance, totalTargetPercentage) = rebalancer.calcTotalTargetBuyPercentage(
        adjustToBuyList, buyList, detf.address
    )

    if len(adjustToBuyList) > 0:
        (
            adjustToBuyListAmountsIn,
            adjustToBuyListAmountsOut,
        ) = rebalancer.createAdjustToBuyOrder(
            adjustToBuyList, totalTargetPercentage, detf.address
        )

        for i in range(0, len(adjustToBuyList)):
            if adjustToBuyList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    router.getWethAddress(),
                    adjustToBuyList[i],
                    adjustToBuyListAmountsIn[i],
                    adjustToBuyListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Adjust To Buy",
                        adjustToBuyListAmountsIn[i],
                        adjustToBuyListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        adjustToBuyListAmountsIn[i],
                        adjustToBuyListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    if len(buyList) > 0:
        (buyListAmountsIn, buyListAmountsOut) = rebalancer.createBuyOrder(
            buyList, wethBalance, totalTargetPercentage, detf.address
        )

        for i in range(0, len(buyList)):
            if buyList[i] != "0x0000000000000000000000000000000000000000":
                path = router.getLiquidPath(
                    router.getWethAddress(),
                    buyList[i],
                    buyListAmountsIn[i],
                    buyListAmountsOut[i],
                )
                if len(path) > 0:
                    print(
                        "Buy",
                        buyListAmountsIn[i],
                        buyListAmountsOut[i],
                        path,
                    )
                    detf.swap(
                        buyListAmountsIn[i],
                        buyListAmountsOut[i],
                        path,
                        {"from": account},
                    )
                else:
                    print("PolybitRouter: INSUFFICIENT_TOKEN_LIQUIDITY")

    detf.updateOwnedAssetsForRebalance(
        adjustToSellList, adjustToBuyList, buyList, {"from": account}
    )


def main():
    account = get_account(type="owner")
    print("Account Owner Address", account.address)
    detf_factory_address = "0xEcb7b6e856d4df9f10B8819EA979959674EC5F8A"
    detf_factory = Contract.from_abi(
        "DETF Factory", detf_factory_address, PolybitDETFFactory.abi
    )

    detfs = detf_factory.getListOfDETFs()
    router_address = detf_factory.getPolybitRouterAddress()
    router = Contract.from_abi("Router", router_address, PolybitRouter.abi)
    rebalancer_address = detf_factory.getPolybitRebalancerAddress()
    rebalancer = Contract.from_abi(
        "Rebalancer", rebalancer_address, PolybitRebalancer.abi
    )

    while True:
        for i in range(0, len(detfs)):
            detf = Contract.from_abi("DETF", detfs[i], PolybitDETF.abi)
            weth_balance = detf.getWethBalance()
            print(detfs[i], weth_balance)
            if weth_balance > 0:
                rebalance(account, detf, rebalancer, router)
                print("Rebalance Complete")
