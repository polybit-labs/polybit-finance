import pytest
from brownie import exceptions
from scripts.utils.polybit_utils import get_account
from scripts import (
    deploy_DETF_oracle_factory,
    deploy_DETF_oracle_from_factory,
    deploy_Router,
)

OWNER = get_account(type="owner")
NON_OWNER = get_account(type="non_owner")
TEST_DETF_NAME = "Test Name"
TEST_DETF_ID = "Test ID"
TEST_DETF_WETH_ADDRESS = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
TEST_DETF_SWAP_FACTORY_ADDRESS = "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"
TEST_TOKEN_SYMBOL = "BTCB"
TEST_TOKEN_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c"
TEST_TOKEN_PRICE_ORACLE_ADDRESS = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"

"""
Test deploying the Oracle Factory, by the Owner account
"""


def test_deploy_detf_oracle_factory__owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    assert oracle_factory.owner() == OWNER


"""
Test deploying a DETF Oracle from the Oracle Factory, by the Owner account
"""


def test_deploy_detf_oracle_from_factory__owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )
    assert detf_oracle.owner() == OWNER


"""
Test deploying a DETF Oracle from the Oracle Factory, with an account that is not the Owner
"""


def test_deploy_detf_oracle_from_factory_non_owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)

    with pytest.raises(exceptions.VirtualMachineError):
        detf_oracle = deploy_DETF_oracle_from_factory.main(
            NON_OWNER,
            oracle_factory.address,
            TEST_DETF_NAME,
            TEST_DETF_ID,
            router.address,
        )


"""
Test changing the status of the DETF Oracle, by the Owner account
"""


def test_change_detf_oracle_status__owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Change status to 1 (active)
    tx0 = detf_oracle.setOracleStatus(1, {"from": OWNER})
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert detf_oracle.oracleStatus() == 1


"""
Test changing the status of the DETF Oracle, with an account that is not the Owner
"""


def test_change_detf_oracle_status__non_owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Change status to 1 (active)
    with pytest.raises(exceptions.VirtualMachineError):
        tx0 = detf_oracle.setOracleStatus(1, {"from": NON_OWNER})
        tx0.wait(1)
        for i in range(0, len(tx0.events)):
            print(tx0.events[i])


"""
Test adding an asset to the DETF Oracle, by the Owner account
"""


def test_add_asset_to_detf_oracle__owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert (
        detf_oracle.getPriceOracleAddress(TEST_TOKEN_ADDRESS)
        == TEST_TOKEN_PRICE_ORACLE_ADDRESS
    )


"""
Test adding an asset to the DETF Oracle, with an account that is not the Owner
"""


def test_add_asset_to_detf_oracle__non_owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    with pytest.raises(exceptions.VirtualMachineError):
        # Add asset to Oracle
        tx0 = detf_oracle.addAsset(
            TEST_TOKEN_ADDRESS,
            TEST_TOKEN_PRICE_ORACLE_ADDRESS,
            {"from": NON_OWNER},
        )
        tx0.wait(1)
        for i in range(0, len(tx0.events)):
            print(tx0.events[i])


"""
Test adding an asset to the DETF Oracle that already exists, by the Owner account
"""


def test_add_duplicate_asset_to_detf_oracle__owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    # Add the same asset to the Oracle
    with pytest.raises(exceptions.VirtualMachineError):
        tx1 = detf_oracle.addAsset(
            TEST_TOKEN_ADDRESS,
            TEST_TOKEN_PRICE_ORACLE_ADDRESS,
            {"from": OWNER},
        )
        tx1.wait(1)
        for i in range(0, len(tx1.events)):
            print(tx1.events[i])


"""
Test removing an asset in the DETF Oracle, by the Owner account
"""


def test_removing_asset_from_detf_oracle__owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    # Remove asset
    tx1 = detf_oracle.removeAsset(
        TEST_TOKEN_ADDRESS,
        {"from": OWNER},
    )
    tx1.wait(1)
    for i in range(0, len(tx1.events)):
        print(tx1.events[i])

    target_list = detf_oracle.getTargetList()
    assert TEST_TOKEN_ADDRESS not in target_list


"""
Test removing an asset in the DETF Oracle, with an account that is not the Owner
"""


def test_removing_asset_from_detf_oracle__non_owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    # Remove asset
    with pytest.raises(exceptions.VirtualMachineError):
        tx1 = detf_oracle.removeAsset(
            TEST_TOKEN_ADDRESS,
            {"from": NON_OWNER},
        )
        tx1.wait(1)
        for i in range(0, len(tx1.events)):
            print(tx1.events[i])


"""
Test removing an asset in the DETF Oracle that does not exist, by the Owner account
"""


def test_removing_asset_from_detf_oracle_that_does_not_exist__non_owner():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    # Remove asset
    with pytest.raises(exceptions.VirtualMachineError):
        tx1 = detf_oracle.removeAsset(
            "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419",
            {"from": OWNER},
        )
        tx1.wait(1)
        for i in range(0, len(tx1.events)):
            print(tx1.events[i])


"""
Test read functions
"""


def test_read_functions():
    router = deploy_Router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    detf_oracle = deploy_DETF_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    # Add asset to Oracle
    tx0 = detf_oracle.addAsset(
        TEST_TOKEN_ADDRESS,
        TEST_TOKEN_PRICE_ORACLE_ADDRESS,
        {"from": OWNER},
    )
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert (
        detf_oracle.getPriceOracleAddress(TEST_TOKEN_ADDRESS)
        == TEST_TOKEN_PRICE_ORACLE_ADDRESS
    )
