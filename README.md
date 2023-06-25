# Mini Savings Account

## Getting Started

### Requirements

Please install the following:

-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)  
    -   You'll know you've done it right if you can run `git --version`
-   [Foundry / Foundryup](https://github.com/gakonst/foundry)
    -   This will install `forge`, `cast`, and `anvil`
    -   You can test you've installed them right by running `forge --version` and get an output like: `forge 0.2.0 (f016135 2022-07-04T00:15:02.930499Z)`
    -   To get the latest of each, just run `foundryup`

And you probably already have `make` installed... but if not [try looking here.](https://askubuntu.com/questions/161104/how-do-i-install-make)

### Quickstart

```sh
git clone https://github.com/beirao/mini-savings-account
cd mini-savings-account
mv .env.example .env
make test
```

### Testing

Ethereum mainnet fork testing.

```
make test
```

# Documentation

## Abstract

This document outlines the design and implementation process of MiniSavingsAccount, a decentralized savings account infrastructure developed with Foundry and utilizing Solidity for smart-contract. The system empowers users to seamlessly create, manage, and interact with their savings accounts, while supporting multiple tokens including but not limited to USD, EUR, and GBP.

The purpose of MiniSavingsAccount is to ensure user-oriented finance management with the added advantage of earning interest on deposits. The system's flexible architecture allows for the inclusion of new tokens in the future, making it adaptable and scalable to meet changing financial landscapes.

This system act like a controlled environment where all blockchain interaction are verified by the Bank owner (can be a centralized entity or a DAO).

### System Design

Our primary objective is to build a secure environment that facilitates a controlled interaction between users and both DeFi and CeFi platforms in a decentralized manner. This can be achieved by establishing a robust ecosystem with a “bank” contract, which could either be controlled by a centralized entity or a DAO.

There are two types of vaults in this system: the fully decentralized **DeFi vaults** (like Yearn) and the semi-centralized vaults managed by the bank, referred to as **CeFi Vaults**. These centralized vaults are designed to broaden investment opportunities by simplifying the access to conventional investment bonds. For instance, the bank will be able to create separate vaults for investing in the debt of different countries. These vaults would permit withdrawals by the centralized entity, which would then regularly deposit the accrued interest.

The system is engineered to be non-systemic. In practical terms, this means that if the centralized entity encounters a failure, only the CeFi vaults would be impacted. As a result, users' savings and DeFi vaults would remain secure and unaffected by such an event.

![Untitled](/img/miniImg.png)

Accounts are linked to a NFT that allow anyone to transfer all account fund. The NFT owner is the only one allow to interact with the account.

Accounts can be devised in sub-accounts and any sub-accounts can be linked to a specific vault to generate yield except the default account that has the 0 Id. If a sub-account is linked to a vault any compatible asset deposited into the sub-account will be invested in the underlying vault automatically.

![Untitled](/img/img1.png)

### System Actors

The proposed system comprises two key actors: the bank and the users (account owners).

**The Bank** has the capacity to:

- Establish new "bank" accounts for users.
- Initiate verified vaults to accrue interest. The vaults can be of two types:
    - DeFi Vaults
    - CeFi Vaults

**Users**, on the other hand, will have the ability to:

- Swap their tokens internally without needing to withdraw.
- Create accounts to oversee their savings.
- Allocate their savings in vaults to earn interest using verified strategies.

---

## Tech Stack

### Smart Contracts

We used the [foundry](https://github.com/smartcontractkit/foundry-starter-kit) framework and deploying on an Uniswap V3 compatible chain.

| Contract name | Description | Fork/Inspiration/Library |
| --- | --- | --- |
| Bank.sol | Bank contract | OZ https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol |
| Accountt.sol | User bank account | - |
| VaultCeFi.sol | CeFi vault | Solmate https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol |
| VaultDeFi.sol | DeFi vault | https://github.com/code-423n4/2023-02-ethos/blob/73687f32b934c9d697b97745356cdf8a1f264955/Ethos-Vault/contracts/ReaperVaultERC4626.sol |
| UniswapV3Helper.sol | Helper to internally swap on Uniswap | https://github.com/stakewithus/defi-by-example/tree/main/uni-v3/contracts |

### Bank

The Bank contract serves as the central point in the system, operating as a factory for Accounts and Vaults. This contract inherit from the ERC721 and Ownable contracts, both sourced from OpenZeppelin.

The owner of the Bank contract can be a centralized entity or a DAO.

Initiating an account is a straightforward process — any individual can establish one by executing the `Bank.createAccount()` function. However, the ability to add a new asset or create a new vault is exclusively reserved for the owner.

The creation of a new Account mint a NFT to the callee. Interaction with the Account is then exclusively confined to the NFT owner. Given the transferable nature of this NFT, it allows users the freedom to trade or sell their account to another user, thus ensuring flexibility and liquidity within the system.

### Accountt

*Account is a Foundry reserved interface name so let’s Accountt.*

Every account is associated with an NFT and includes a primary sub-account by default (ID = 0).

The account holder is permitted to transfer authorized ERC20 tokens (currently USDC, GBPT, and EURC) and establish subsidiary accounts. Such a sub-account can be connected to a verified vault to generate yield. Note that it is not possible to link the default sub-account to a vault.

Once linking a sub-account to a vault, any compatible tokens will be automatically invested in the vault.

Thanks to of `UniswapV3Helper`, account holders can perform internal token swaps without needing to make a withdrawal. However, token swaps are restricted to the default sub-account.

### VaultCeFi

VaultCeFi, which inherits the Solmate/ERC4626, allows the owner to borrow assets from the vault for traditional financial investment strategies. Once the strategy has compounded, the bank owner can refund the vault, with the original funds along with the accrued interest.

### VaultDeFi

For DeFi vaults, we need to create a proper strategy, which is not trivial. If I had to implement this feature, I would definitely use the ReaperVaultV2. This vault is a modern fork of the Yearn vault with some MEV protection.

## Security concern

- Implement a proper slippage protection in UniswapV3Helper
- FoT and Rebasing tokens are not compatible

## Coding conventions

This code convention is follow : https://docs.soliditylang.org/en/v0.8.16/style-guide.html

Adding these conventions :

### Errors

ContractName__ERROR_DESCRIPTION(uint var1, uint var2)

### Variables

Storage : *variable*

Memory : *variable_*

Calldata : *_variable*

Constant : *VARIABLE*

### Functions

External/Public : *functionName()*

Internal/Private : *_functionName()*
