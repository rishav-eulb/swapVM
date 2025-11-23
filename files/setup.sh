#!/bin/bash

# PseudoArbitrage AMM - Automated Setup Script
# This script automates the initial setup process

set -e  # Exit on error

echo "=================================="
echo "PseudoArbitrage AMM Setup Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

command -v forge >/dev/null 2>&1 || { 
    echo -e "${RED}Error: Foundry is not installed${NC}"
    echo "Install from: https://getfoundry.sh"
    exit 1
}
echo -e "${GREEN}✓ Foundry installed${NC}"

command -v git >/dev/null 2>&1 || { 
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
}
echo -e "${GREEN}✓ Git installed${NC}"

# Check Solidity version
SOLC_VERSION=$(forge --version | grep -o 'solc [0-9.]*' | cut -d' ' -f2 || echo "unknown")
echo -e "${GREEN}✓ Solc version: $SOLC_VERSION${NC}"

echo ""

# Create project directory
PROJECT_NAME="pseudo-arbitrage-amm"
echo "Creating project: $PROJECT_NAME"

if [ -d "$PROJECT_NAME" ]; then
    echo -e "${YELLOW}Warning: Directory $PROJECT_NAME already exists${NC}"
    read -p "Continue and overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    rm -rf "$PROJECT_NAME"
fi

mkdir "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Initialize Foundry
echo "Initializing Foundry project..."
forge init

# Clean default files
rm -f src/Counter.sol test/Counter.t.sol script/Counter.s.sol

# Install dependencies
echo "Installing dependencies..."
echo "This may take a few minutes..."

forge install OpenZeppelin/openzeppelin-contracts@v5.1.0
echo -e "${GREEN}✓ OpenZeppelin installed${NC}"

# Try to install SwapVM
echo "Attempting to install 1inch SwapVM..."
if forge install 1inch/swap-vm 2>/dev/null; then
    echo -e "${GREEN}✓ SwapVM installed${NC}"
else
    echo -e "${YELLOW}! SwapVM auto-install failed${NC}"
    echo "You'll need to manually clone it:"
    echo "  git clone https://github.com/1inch/swap-vm.git lib/swap-vm"
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p src/instructions
mkdir -p src/opcodes
mkdir -p src/routers
mkdir -p src/strategies
mkdir -p test
mkdir -p script
mkdir -p deployments

echo -e "${GREEN}✓ Directories created${NC}"

# Create foundry.toml
echo "Creating foundry.toml..."
cat > foundry.toml << 'EOF'
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc_version = "0.8.30"
evm_version = "cancun"
optimizer = true
optimizer_runs = 1000000
via_ir = false

remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/",
    "swap-vm/=lib/swap-vm/src/"
]

[rpc_endpoints]
mainnet = "${MAINNET_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"
base = "${BASE_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
base = { key = "${BASESCAN_API_KEY}" }
EOF

echo -e "${GREEN}✓ foundry.toml created${NC}"

# Create .env template
echo "Creating .env template..."
cat > .env.example << 'EOF'
# Network RPC URLs
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_KEY
BASE_RPC_URL=https://base-mainnet.g.alchemy.com/v2/YOUR_KEY

# Private key (NEVER commit this!)
PRIVATE_KEY=0x0000000000000000000000000000000000000000000000000000000000000000

# Etherscan API keys
ETHERSCAN_API_KEY=your_etherscan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key
BASESCAN_API_KEY=your_basescan_api_key

# Aqua address (from 1inch)
AQUA_ADDRESS=0x0000000000000000000000000000000000000000
EOF

# Create .gitignore
echo "Creating .gitignore..."
cat > .gitignore << 'EOF'
# Foundry
cache/
out/
broadcast/

# Environment
.env
.env.*
!.env.example

# Node
node_modules/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Deployments (optional - you may want to commit these)
deployments/*.json
!deployments/.gitkeep
EOF

touch deployments/.gitkeep

echo -e "${GREEN}✓ .env.example and .gitignore created${NC}"

# Create README
echo "Creating README..."
cat > README.md << 'EOF'
# PseudoArbitrage AMM

Implementation of the Engel & Herlihy pseudo-arbitrage AMM strategy for SwapVM.

## Setup

1. Copy `.env.example` to `.env` and fill in your values
2. Place your contract files in the appropriate directories:
   - `src/instructions/PseudoArbitrage.sol`
   - `src/opcodes/PseudoArbitrageOpcodes.sol`
   - `src/routers/PseudoArbitrageSwapVMRouter.sol`
   - `src/strategies/PseudoArbitrageAMM.sol`

3. Install dependencies (if not already done):
   ```bash
   forge install
   ```

4. Compile:
   ```bash
   forge build
   ```

5. Test:
   ```bash
   forge test
   ```

## Deployment

See `STEP_BY_STEP_GUIDE.md` for detailed instructions.

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [SwapVM Docs](https://github.com/1inch/swap-vm)
- [Engel & Herlihy Paper](https://arxiv.org/abs/2106.00667)
EOF

echo -e "${GREEN}✓ README created${NC}"

# Create a simple Makefile for common commands
echo "Creating Makefile..."
cat > Makefile << 'EOF'
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
EOF

echo -e "${GREEN}✓ Makefile created${NC}"

echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo ""
echo "1. Copy your contract files to the appropriate directories:"
echo "   - PseudoArbitrage.sol → src/instructions/"
echo "   - PseudoArbitrageOpcodes.sol → src/opcodes/"
echo "   - PseudoArbitrageSwapVMRouter.sol → src/routers/"
echo "   - PseudoArbitrageAMM.sol → src/strategies/"
echo ""
echo "2. Copy your test and script files:"
echo "   - *.t.sol → test/"
echo "   - *.s.sol → script/"
echo ""
echo "3. Configure environment:"
echo "   cp .env.example .env"
echo "   # Edit .env with your values"
echo ""
echo "4. If SwapVM installation failed, install manually:"
echo "   git clone https://github.com/1inch/swap-vm.git lib/swap-vm"
echo ""
echo "5. Compile and test:"
echo "   make build"
echo "   make test"
echo ""
echo "6. Read STEP_BY_STEP_GUIDE.md for detailed instructions"
echo ""
echo -e "${GREEN}Project initialized in: $(pwd)${NC}"
echo ""

# Try to compile to check if everything works
echo "Testing compilation..."
if forge build 2>/dev/null; then
    echo -e "${GREEN}✓ Initial compilation successful!${NC}"
else
    echo -e "${YELLOW}! Compilation requires contract files and SwapVM dependencies${NC}"
    echo "  This is expected - add your contracts and run 'make build'"
fi

echo ""
echo "Done! 🚀"
EOF
