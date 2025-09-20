# ShadowTrade Development Guide

This guide covers development setup, testing, and contribution guidelines for ShadowTrade.

## Development Setup

### Prerequisites

- **Node.js**: v18+ (recommended: v20)
- **pnpm**: Package manager
- **Foundry**: Solidity development framework
- **Git**: Version control

### Installation

```bash
# Clone repository
git clone https://github.com/your-org/shadowtrade.git
cd shadowtrade

# Install dependencies
pnpm install

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
```

### Environment Setup

```bash
# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
```

## Development Workflow

### 1. Build and Test

```bash
# Build contracts
make build
# or
forge build --via-ir

# Run tests
make test
# or
forge test --via-ir

# Run specific test file
make test-file FILE=test/ShadowTradeLimitHook.t.sol
```

### 2. Local Development

```bash
# Start local Anvil node
make anvil

# In another terminal, deploy contracts
make deploy-local
```

### 3. Code Quality

```bash
# Format code
make format

# Lint code
make lint

# Run security analysis
make security
```

## Testing

### Test Structure

```
test/
├── mocks/                    # Mock contracts for testing
│   ├── MockFHE.sol          # FHE operations mock
│   ├── MockCoFHE.sol        # CoFHE operations mock
│   └── ...
├── utils/                    # Test utilities
│   └── HookMiner.sol        # Hook address mining utility
├── HybridFHERC20.t.sol      # Token tests
├── HybridFHERC20Integration.t.sol  # Integration tests
├── ShadowTradeLimitHook.t.sol      # Hook tests
└── ShadowTradeLimitHookComprehensive.t.sol  # Comprehensive tests
```

### Test Categories

1. **Unit Tests**: Individual function testing
2. **Integration Tests**: Cross-contract interactions
3. **Comprehensive Tests**: End-to-end scenarios
4. **Fuzz Tests**: Random input testing

### Running Tests

```bash
# All tests
forge test --via-ir

# Specific test file
forge test --match-path test/ShadowTradeLimitHook.t.sol --via-ir

# Verbose output
forge test --via-ir -vvv

# Gas reporting
forge test --via-ir --gas-report
```

## FHE Development

### Mock Environment

ShadowTrade uses mock contracts for FHE operations during testing:

```solidity
// Example: Creating encrypted values
InEuint128 memory encryptedValue = createInEuint128(1000, user);

// Example: Decrypting values
uint128 decryptedValue = getDecryptResult(encryptedValue);
```

### FHE Operations

Key FHE operations used in ShadowTrade:

- `FHE.asEuint128()`: Convert to encrypted uint128
- `FHE.add()`: Encrypted addition
- `FHE.mul()`: Encrypted multiplication
- `FHE.lt()`: Encrypted less-than comparison
- `FHE.gt()`: Encrypted greater-than comparison

## Code Style

### Solidity Style Guide

1. **Naming Conventions**:
   - Contracts: `PascalCase`
   - Functions: `camelCase`
   - Variables: `camelCase`
   - Constants: `UPPER_SNAKE_CASE`

2. **Function Order**:
   - Constructor
   - External functions
   - Public functions
   - Internal functions
   - Private functions
   - View/Pure functions

3. **Documentation**:
   - Use NatSpec comments
   - Document all public functions
   - Include parameter descriptions
   - Add return value descriptions

### Example

```solidity
/// @title ShadowTradeLimitHook
/// @notice Main hook contract for private limit orders
/// @dev Implements FHE-based private order management
contract ShadowTradeLimitHook is BaseHook {
    
    /// @notice Places a new limit order
    /// @param poolId The Uniswap v4 pool identifier
    /// @param triggerPrice Encrypted price at which order executes
    /// @param orderSize Encrypted size of the order
    /// @param direction Encrypted direction (0 = sell, 1 = buy)
    /// @param expiration Encrypted expiration timestamp
    /// @return orderId Unique identifier for the order
    function placeLimitOrder(
        PoolId poolId,
        InEuint128 memory triggerPrice,
        InEuint128 memory orderSize,
        InEuint8 memory direction,
        InEuint64 memory expiration
    ) external returns (bytes32 orderId) {
        // Implementation...
    }
}
```

## Debugging

### Common Issues

1. **Stack Too Deep**:
   - Use `--via-ir` flag
   - Reduce local variables
   - Split complex functions

2. **FHE Mock Issues**:
   - Ensure proper mock setup
   - Check encrypted value creation
   - Verify decryption results

3. **Test Failures**:
   - Check test environment setup
   - Verify mock contract deployment
   - Review test data

### Debug Commands

```bash
# Verbose test output
forge test --via-ir -vvv

# Trace specific test
forge test --match-test testPlaceLimitOrder --via-ir -vvv

# Gas estimation
forge test --via-ir --gas-report
```

## Contributing

### Pull Request Process

1. **Fork Repository**: Create your fork
2. **Create Branch**: `git checkout -b feature/your-feature`
3. **Make Changes**: Implement your changes
4. **Add Tests**: Include comprehensive tests
5. **Run Tests**: Ensure all tests pass
6. **Format Code**: Run `make format`
7. **Submit PR**: Create pull request

### Code Review Checklist

- [ ] Tests pass
- [ ] Code is formatted
- [ ] Documentation updated
- [ ] No breaking changes
- [ ] Security considerations addressed
- [ ] Gas optimization reviewed

### Issue Reporting

When reporting issues, include:

1. **Environment**: OS, Node.js version, Foundry version
2. **Steps to Reproduce**: Clear reproduction steps
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Error Messages**: Complete error output
6. **Code**: Minimal reproduction code

## Security Considerations

### FHE Security

- **Encryption Keys**: Never expose private keys
- **Mock vs Real**: Distinguish between test and production
- **Key Management**: Proper key rotation and storage

### Smart Contract Security

- **Access Controls**: Verify permission systems
- **Reentrancy**: Use proper guards
- **Integer Overflow**: Use SafeMath or Solidity 0.8+
- **External Calls**: Validate all external interactions

### Testing Security

- **Fuzz Testing**: Test with random inputs
- **Edge Cases**: Test boundary conditions
- **Error Conditions**: Test failure scenarios
- **Gas Limits**: Test with gas constraints

## Performance Optimization

### Gas Optimization

1. **Storage Layout**: Optimize storage variables
2. **Function Optimization**: Reduce gas usage
3. **Loop Optimization**: Minimize loop iterations
4. **Memory vs Storage**: Use appropriate data locations

### FHE Optimization

1. **Operation Batching**: Batch FHE operations
2. **Key Reuse**: Reuse encryption keys when possible
3. **Operation Selection**: Choose efficient FHE operations

## Deployment

### Pre-deployment Checklist

- [ ] All tests passing
- [ ] Code reviewed
- [ ] Security audit completed
- [ ] Gas estimation verified
- [ ] Environment variables set
- [ ] Private keys secured
- [ ] Contract addresses documented

### Deployment Commands

```bash
# Local deployment
make deploy-local

# Fhenix testnet
make deploy-fhenix

# Mainnet (production)
make deploy-mainnet
```

## Resources

### Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Documentation](https://docs.soliditylang.org/)
- [Fhenix Documentation](https://docs.fhenix.io/)
- [Uniswap v4 Documentation](https://docs.uniswap.org/sdk/v4/)

### Tools

- [Remix IDE](https://remix.ethereum.org/)
- [Hardhat](https://hardhat.org/)
- [Slither](https://github.com/crytic/slither) (Security analysis)
- [Mythril](https://github.com/ConsenSys/mythril) (Security analysis)

---

For questions or support, please open an issue or contact the development team.
