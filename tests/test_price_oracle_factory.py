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
Test deploying the Oracle Factory, by the Owner account
"""


def test_deploy_price_oracle_factory__owner():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    assert oracle_factory.owner() == OWNER


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


"""
Test read functions
"""


def test_read_functions():
    oracle_factory = deploy_price_oracle_factory.main(OWNER)
    price_oracle = deploy_price_oracle_from_factory.main(
        OWNER, oracle_factory.address, TEST_TOKEN_ADDRESS
    )

    assert oracle_factory.getOracle(0) == price_oracle.address

    oracle_list = [price_oracle.address]

    assert oracle_factory.getListOfOracles() == oracle_list
