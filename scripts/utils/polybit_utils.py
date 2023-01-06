from brownie import network, accounts, config

POLYBIT_FORKED_ENVIRONMENTS = ["polybit-bsc-fork","polybit-bsc-main-fork"]
NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + [
    "mainnet-fork",
    "bsc-main-fork",
    "matic-fork",
]

BLOCK_CONFIRMATIONS_FOR_VERIFICATION = (
    1 if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS else 6
)


def is_verifiable_contract() -> bool:
    return config["networks"][network.show_active()].get("verify", False)


def get_account(index=None, id=None, type=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)

    if (type == "polybit_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[0]
    if (type == "rebalancer_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[1]
    if (type == "router_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[2]
    if (type == "wallet_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[3]
    if (type == "non_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[4]
    if (type == "polybit_fee_address") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[5]

    if (type == "polybit_owner") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_polybit_owner_key"])
    if (type == "rebalancer_owner") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_rebalancer_owner_key"])
    if (type == "router_owner") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_router_owner_key"])
    if (type == "wallet_owner") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_wallet_owner_key"])
    if (type == "non_owner") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_non_owner_key"])
    if (type == "polybit_fee_address") & (network.show_active() in POLYBIT_FORKED_ENVIRONMENTS):
        return accounts.add(config["wallets"]["test_polybit_fee_key"])

    if type == "polybit_owner":
        return accounts.add(config["wallets"]["polybit_owner_key"])
    if type == "rebalancer_owner":
        return accounts.add(config["wallets"]["rebalancer_owner_key"])
    if type == "router_owner":
        return accounts.add(config["wallets"]["router_owner_key"])
    if type == "wallet_owner":
        return accounts.add(config["wallets"]["wallet_owner_key"])
    if type == "non_owner":
        return accounts.add(config["wallets"]["non_owner_key"])
    if type == "polybit_fee_address":
        return accounts.add(config["wallets"]["polybit_fee_key"])
