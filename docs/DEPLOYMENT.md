# ShadowTrade Deployment Guide

This guide covers deployment of ShadowTrade contracts across different networks.

## Prerequisites

1. **Environment Setup**
   ```bash
   # Copy environment template
   cp .env.example .env
   
   # Edit .env with your values
   nano .env
   ```

2. **Required Environment Variables**
   - `PRIVATE_KEY`: Your deployment private key
   - `ALCHEMY_KEY`: Alchemy API key for Ethereum networks
   - `FHENIX_RPC_URL`: Fhenix testnet RPC URL

## Deployment Scripts

### 1. Local Development (Anvil)

```bash
# Start local Anvil node
anvil --port 8545 --host 0.0.0.0

# Deploy to Anvil
forge script script/DeployHookAnvil.s.sol --rpc-url http://localhost:8545 --broadcast
```

### 2. Fhenix Testnet

```bash
# Deploy to Fhenix testnet
forge script script/DeployLimitHook.s.sol --rpc-url fhenix --broadcast
```

### 3. Ethereum Mainnet

```bash
# Deploy to mainnet (when ready)
forge script script/DeployLimitHook.s.sol --rpc-url mainnet --broadcast
```

## Contract Addresses

### Fhenix Testnet
- **ShadowTradeLimitHook**: `TBD`
- **HybridFHERC20**: `TBD`

### Mainnet
- **ShadowTradeLimitHook**: `TBD`
- **HybridFHERC20**: `TBD`

## Verification

After deployment, verify contracts on block explorer:

```bash
# Verify on Etherscan
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> --etherscan-api-key $ETHERSCAN_API_KEY
```

## Post-Deployment Setup

1. **Initialize Hook**
   - Set execution fees
   - Configure access controls
   - Set up emergency pause if needed

2. **Token Setup**
   - Mint initial tokens
   - Set up liquidity pools
   - Configure token permissions

## Troubleshooting

### Common Issues

1. **Gas Estimation Failed**
   - Increase gas limit in foundry.toml
   - Check RPC endpoint connectivity

2. **Transaction Reverted**
   - Verify private key has sufficient funds
   - Check contract constructor parameters

3. **Verification Failed**
   - Ensure compiler settings match
   - Check constructor arguments

## Security Considerations

- **Private Key Security**: Never commit private keys to version control
- **Multi-sig Setup**: Use multi-sig wallets for production deployments
- **Gradual Rollout**: Deploy to testnet first, then mainnet
- **Monitoring**: Set up monitoring for deployed contracts
