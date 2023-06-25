-include .env

.PHONY: all test clean deploy-anvil

all: clean install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib/forge-std && rm -rf lib/openzeppelin-contracts &&  rm -rf lib/solmate && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install --no-commit transmissions11/solmate && forge install --no-commit foundry-rs/forge-std && forge install --no-commit OpenZeppelin/openzeppelin-contracts

# Update Dependencies
update:; forge update

build:; forge build

sizer:; forge build --sizes

compile:; forge compile

test :; forge test --fork-url ${ETH_RPC_URL} -vv
test-gas :; forge test --fork-url ${ETH_RPC_URL} -vv --gas-report

slither :; slither ./src 

format :; prettier --write src/**/*.sol && prettier --write src/*.sol

# solhint should be installed globally
lint :; solhint src/**/*.sol && solhint src/*.sol

anvil :; anvil -m 'test test test test test test test test test test test junk'

# use the "@" to hide the command from your shell 
deploy-sepolia :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url ${SEPOLIA_RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}  -vvvv

# This is the private key of account from the mnemonic from the "make anvil" command
deploy-anvil :; @forge script script/${contract}.s.sol:Deploy${contract} --rpc-url http://localhost:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast 

deploy-all :; make deploy-${network} contract=APIConsumer && make deploy-${network} contract=KeepersCounter && make deploy-${network} contract=PriceFeedConsumer && make deploy-${network} contract=VRFConsumerV2

-include ${FCT_PLUGIN_PATH}/makefile-external
