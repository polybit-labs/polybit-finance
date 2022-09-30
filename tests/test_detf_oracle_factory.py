import pytest
from brownie import exceptions
from scripts.utils.polybit_utils import get_account
from scripts import (
    deploy_DETF_oracle_factory,
    deploy_DETF_oracle_from_factory,
    deploy_router,
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
    router = deploy_router.main(
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
    router = deploy_router.main(
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
Test setting a deposit fee, by the Owner account
"""


def test_set_deposit_fee__owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee = 1
    oracle_factory.setDepositFee(fee, {"from": OWNER})

    assert oracle_factory.getDepositFee() == fee


"""
Test setting a deposit fee, with an account that is not the Owner
"""


def test_set_deposit_fee__non_owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee = 1

    with pytest.raises(exceptions.VirtualMachineError):
        oracle_factory.setDepositFee(fee, {"from": NON_OWNER})
        assert oracle_factory.getDepositFee() == fee


"""
Test setting a performance fee, by the Owner account
"""


def test_set_performance_fee__owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee = 1
    oracle_factory.setPerformanceFee(fee, {"from": OWNER})

    assert oracle_factory.getPerformanceFee() == fee


"""
Test setting a performance fee, with an account that is not the Owner
"""


def test_set_performance_fee__non_owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee = 1

    with pytest.raises(exceptions.VirtualMachineError):
        oracle_factory.setPerformanceFee(fee, {"from": NON_OWNER})
        assert oracle_factory.getPerformanceFee() == fee


"""
Test setting a fee address, by the Owner account
"""


def test_set_fee_address__owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee_address = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"
    oracle_factory.setFeeAddress(fee_address, {"from": OWNER})

    assert oracle_factory.getFeeAddress() == fee_address


"""
Test setting a fee address, with an account that is not the Owner
"""


def test_set_fee_address__non_owner():
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)
    fee_address = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"

    with pytest.raises(exceptions.VirtualMachineError):
        oracle_factory.setFeeAddress(fee_address, {"from": NON_OWNER})
        assert oracle_factory.getFeeAddress() == fee_address


"""
Test transfer owner
"""


def test_transfer_owner_oracle_factory():
    router = deploy_router.main(
        OWNER, TEST_DETF_WETH_ADDRESS, TEST_DETF_SWAP_FACTORY_ADDRESS
    )
    oracle_factory = deploy_DETF_oracle_factory.main(OWNER)

    oracle_factory.transferOwnership(NON_OWNER, {"from": OWNER})

    assert oracle_factory.owner() == NON_OWNER

    detf_oracle = deploy_DETF_oracle_from_factory.main(
        NON_OWNER, oracle_factory.address, TEST_DETF_NAME, TEST_DETF_ID, router.address
    )

    assert detf_oracle.owner() == NON_OWNER

    detf_oracle.transferOwnership(OWNER, {"from": NON_OWNER})

    assert detf_oracle.owner() == OWNER
