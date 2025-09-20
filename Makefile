# ShadowTrade Makefile
# Provides convenient commands for development and deployment

.PHONY: help build test test-verbose clean deploy-local deploy-fhenix deploy-mainnet coverage install

# Default target
help:
	@echo "ShadowTrade Development Commands"
	@echo "================================"
	@echo "build          - Compile contracts"
	@echo "test           - Run test suite"
	@echo "test-verbose   - Run tests with verbose output"
	@echo "coverage       - Run test coverage"
	@echo "clean          - Clean build artifacts"
	@echo "install        - Install dependencies"
	@echo ""
	@echo "Deployment Commands"
	@echo "==================="
	@echo "deploy-local   - Deploy to local Anvil"
	@echo "deploy-fhenix  - Deploy to Fhenix testnet"
	@echo "deploy-mainnet - Deploy to Ethereum mainnet"
	@echo ""
	@echo "Development Commands"
	@echo "===================="
	@echo "anvil          - Start local Anvil node"
	@echo "fork-mainnet   - Fork mainnet for testing"

# Build contracts
build:
	@echo "Building contracts..."
	forge build --via-ir

# Run tests
test:
	@echo "Running test suite..."
	forge test --via-ir

# Run tests with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	forge test --via-ir -vvv

# Run test coverage
coverage:
	@echo "Running test coverage..."
	forge coverage --via-ir

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out/
	rm -rf cache/
	rm -rf broadcast/

# Install dependencies
install:
	@echo "Installing dependencies..."
	pnpm install

# Start local Anvil node
anvil:
	@echo "Starting Anvil local node..."
	anvil --port 8545 --host 0.0.0.0

# Fork mainnet for testing
fork-mainnet:
	@echo "Forking mainnet for testing..."
	anvil --fork-url $(MAINNET_RPC_URL) --port 8545

# Deploy to local Anvil
deploy-local:
	@echo "Deploying to local Anvil..."
	forge script script/DeployHookAnvil.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to Fhenix testnet
deploy-fhenix:
	@echo "Deploying to Fhenix testnet..."
	forge script script/DeployToFhenix.s.sol --rpc-url fhenix --broadcast

# Deploy to mainnet
deploy-mainnet:
	@echo "Deploying to Ethereum mainnet..."
	@echo "WARNING: This will deploy to mainnet. Are you sure? (y/N)"
	@read -r confirm && [ "$$confirm" = "y" ] || exit 1
	forge script script/DeployToMainnet.s.sol --rpc-url mainnet --broadcast

# Verify contracts on Etherscan
verify-mainnet:
	@echo "Verifying contracts on Etherscan..."
	@echo "Please update contract addresses in the script before running"
	# forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --etherscan-api-key $(ETHERSCAN_API_KEY)

# Run specific test file
test-file:
	@echo "Running specific test file: $(FILE)"
	forge test --match-path $(FILE) --via-ir

# Run tests with gas reporting
test-gas:
	@echo "Running tests with gas reporting..."
	forge test --via-ir --gas-report

# Format code
format:
	@echo "Formatting code..."
	forge fmt

# Lint code
lint:
	@echo "Linting code..."
	forge fmt --check

# Security analysis
security:
	@echo "Running security analysis..."
	forge test --via-ir --gas-report
	@echo "Consider running additional security tools like Slither"

# Full development setup
setup: install build test
	@echo "Development setup complete!"
	@echo "Run 'make anvil' to start local node"
	@echo "Run 'make deploy-local' to deploy contracts"

# Production deployment checklist
deploy-check:
	@echo "Pre-deployment checklist:"
	@echo "1. All tests passing: make test"
	@echo "2. Code formatted: make format"
	@echo "3. Security review completed"
	@echo "4. Environment variables set"
	@echo "5. Private key secured"
	@echo "6. Gas estimation checked"
	@echo "7. Contract addresses documented"
