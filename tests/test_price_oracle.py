import pytest
from brownie import exceptions
from scripts.utils.polybit_utils import get_account
from scripts import (
    deploy_price_oracle_factory,
    deploy_price_oracle_from_factory,
)

OWNER = get_account(type="owner")
NON_OWNER = get_account(type="non_owner")
""" Test Asset """
TEST_TOKEN_ADDRESS = "0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c"
TEST_TOKEN_SYMBOL = "BTCB"
TEST_TOKEN_PRICE = 1000000000000000000
TEST_TOKEN_DECIMALS = 18


"""
Test deploying a Price Oracle from the Oracle Factory, by the Owner account
"""


def test_deploy_price_oracle_from_factory__owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER,
        oracle_factory.address,
        TEST_TOKEN_ADDRESS,
    )
    assert price_oracle.owner() == OWNER


"""
Test deploying a Price Oracle from the Oracle Factory, with an account that is not the Owner
"""


def test_deploy_price_oracle_from_factory_non_owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)

    with pytest.raises(exceptions.VirtualMachineError):
        price_oracle = deploy_price_oracle_from_factory.main(
            NON_OWNER,
            oracle_factory.address,
            TEST_TOKEN_ADDRESS,
        )


"""
Test changing the status of the Price Oracle, by the Owner account
"""


def test_change_price_oracle_status__owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER,
        oracle_factory.address,
        TEST_TOKEN_ADDRESS,
    )

    # Change status to 1 (active)
    tx0 = price_oracle.setOracleStatus(1, {"from": OWNER})
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert price_oracle.oracleStatus() == 1


"""
Test changing the status of the Price Oracle, with an account that is not the Owner
"""


def test_change_price_oracle_status__non_owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER,
        oracle_factory.address,
        TEST_TOKEN_ADDRESS,
    )

    # Change status to 1 (active)
    with pytest.raises(exceptions.VirtualMachineError):
        tx0 = price_oracle.setOracleStatus(1, {"from": NON_OWNER})
        tx0.wait(1)
        for i in range(0, len(tx0.events)):
            print(tx0.events[i])


"""
Test updating the latest price in the Price Oracle, by the Owner account
"""


def test_update_price_oracle_status__owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_TOKEN_ADDRESS
    )

    # Update price
    tx0 = price_oracle.setTokenPrice(TEST_TOKEN_PRICE, {"from": OWNER})
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert price_oracle.getLatestPrice() == TEST_TOKEN_PRICE


"""
Test updating the latest price in the Price Oracle, with an account that is not the Owner
"""


def test_update_price_oracle_status__non_owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_TOKEN_ADDRESS
    )

    # Update price
    with pytest.raises(exceptions.VirtualMachineError):
        tx0 = price_oracle.setTokenPrice(TEST_TOKEN_PRICE, {"from": NON_OWNER})
        tx0.wait(1)
        for i in range(0, len(tx0.events)):
            print(tx0.events[i])


"""
Test read functions
"""


def test_read_functions():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_TOKEN_ADDRESS
    )

    # Update price
    tx0 = price_oracle.setTokenPrice(TEST_TOKEN_PRICE, {"from": OWNER})
    tx0.wait(1)
    for i in range(0, len(tx0.events)):
        print(tx0.events[i])

    assert price_oracle.getTokenAddress() == TEST_TOKEN_ADDRESS
    assert price_oracle.getSymbol() == TEST_TOKEN_SYMBOL
    assert price_oracle.getDecimals() == TEST_TOKEN_DECIMALS
    assert price_oracle.getLatestPrice() == TEST_TOKEN_PRICE


"""
Test transfer owner
"""


def test_transfer_owner_oracle():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)

    oracle_factory.transferOwnership(NON_OWNER, {"from": OWNER})

    assert oracle_factory.owner() == NON_OWNER

    price_oracle = deploy_price_oracle_from_factory.main(
        NON_OWNER, oracle_factory.address, TEST_TOKEN_ADDRESS
    )

    assert price_oracle.owner() == NON_OWNER

    price_oracle.transferOwnership(OWNER, {"from": NON_OWNER})

    assert price_oracle.owner() == OWNER
