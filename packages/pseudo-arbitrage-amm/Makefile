.PHONY: build test clean deploy-local deploy-testnet

build:
	forge build

test:
	forge test -vv

test-gas:
	forge test --gas-report

coverage:
	forge coverage

clean:
	forge clean

format:
	forge fmt

deploy-local:
	forge script script/Deploy.s.sol:DeployWithMocksScript --rpc-url http://localhost:8545 --broadcast

deploy-testnet:
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify

anvil:
	anvil

help:
	@echo "Available commands:"
	@echo "  make build         - Compile contracts"
	@echo "  make test          - Run tests"
	@echo "  make test-gas      - Run tests with gas reporting"
	@echo "  make coverage      - Generate coverage report"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make format        - Format code"
	@echo "  make deploy-local  - Deploy to local Anvil"
	@echo "  make deploy-testnet- Deploy to testnet"
	@echo "  make anvil         - Start local Anvil node"
