from brownie import network, accounts, config

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
    if (type == "owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[0]
    if (type == "non_owner") & (network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS):
        return accounts[1]
    if type == "owner":
        return accounts.add(config["wallets"]["owner_key"])
    if type == "non_owner":
        return accounts.add(config["wallets"]["non_owner_key"])
