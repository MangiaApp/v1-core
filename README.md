# Mangia Contracts

![Lint](https://img.shields.io/badge/Lint-passing-brightgreen) ![Tests](https://img.shields.io/badge/Tests-passing-brightgreen) ![License](https://img.shields.io/badge/License-MIT-blue) ![Solidity](https://img.shields.io/badge/Solidity-0.8.19-orange)

A smart contract system for lazy minting ERC1155 tokens with affiliate marketing capabilities, enabling efficient token distribution with built-in referral rewards and coupon redemption features.

## Table of Contents

- [Background](#background)
- [Key Features](#key-features)
- [Deployments](#deployments)
- [Architecture](#architecture)
- [Install](#install)
- [Usage](#usage)
- [Smart Contracts](#smart-contracts)
- [Development](#development)
- [Testing](#testing)
- [Environment Setup](#environment-setup)
- [Contributing](#contributing)
- [License](#license)

## Background

Mangia Contracts implements a comprehensive system for conducting primary NFT drops with affiliate marketing integration. The system supports lazy minting of ERC1155 tokens, allowing users to claim tokens with optional affiliate referrals, and enables coupon redemption with automatic fee distribution to affiliates.

This solution is designed for businesses wanting to run promotional campaigns with trackable referrals, where digital coupons can be distributed as NFTs and later redeemed for real-world benefits while rewarding affiliates who helped drive adoption.

## Key Features

- **🎯 Lazy Minting**: Efficient ERC1155 token creation with on-demand minting
- **👥 Affiliate System**: Built-in referral program with unique affiliate IDs and automatic fee distribution
- **🎟️ Coupon Redemption**: Time-bound coupon system with configurable expiration dates
- **💰 Budget Management**: Automated affiliate payment system with budget allocation and withdrawal controls
- **📱 IPFS Integration**: Decentralized metadata storage using Pinata for coupon data
- **⏰ Time Controls**: Configurable claim windows and redemption periods
- **🔒 Security**: One token per address limit with anti-self-referral protection

## Deployments

The contracts can be deployed to any EVM-compatible blockchain. Current deployments:

| Network | Factory Address | Status |
|---------|----------------|--------|
| Localhost | `0x1234...` | Development |
| Base Testnet | Coming Soon | Planned |
| Base Mainnet | Coming Soon | Planned |

## Architecture

The system consists of two main contracts:

```
┌─────────────────┐    ┌──────────────────┐
│   TokenFactory  │───▶│   Coupon Clone   │
│                 │    │   (ERC1155)      │
│ - Deploy clones │    │ - Lazy minting   │
│ - Gas efficient │    │ - Affiliate sys  │
└─────────────────┘    │ - Redemption     │
                       └──────────────────┘
```

### Workflow

1. **Deploy**: Factory creates new Coupon contract instances
2. **Configure**: Set claim windows, supply limits, and affiliate settings
3. **Claim**: Users mint tokens (optionally with affiliate referral)
4. **Redeem**: Owner redeems coupons, triggering affiliate payments

## Install

### Prerequisites

- Node.js 16+ 
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/mangia-contracts.git
cd mangia-contracts

# Install dependencies
npm install

# Copy environment template
cp .env.example .env
# Edit .env with your configuration
```

### Dependencies

The project uses:
- **Hardhat**: Development environment and testing framework
- **Foundry**: Fast Solidity testing and gas optimization
- **OpenZeppelin**: Security-audited contract libraries
- **Pinata**: IPFS pinning service for metadata storage

## Usage

### Quick Start

1. **Deploy the factory**:
```bash
npx hardhat ignition deploy ignition/modules/TokenFactory.ts --network localhost
```

2. **Create a coupon contract**:
```bash
npx hardhat run scripts/createCoupon.js --network localhost
```

3. **Configure your campaign** with claim windows, supply limits, and IPFS metadata

### Basic Integration

```solidity
// Example: Claiming a token with affiliate referral
function claimToken(uint256 affiliateId) external {
    coupon.claim(msg.sender, affiliateId);
}

// Example: Redeeming coupons (owner only)
function redeemCoupons(uint256[] calldata tokenIds) external onlyOwner {
    coupon.redeemCoupons(tokenIds);
}
```

### Configuration Options

- **Claim Window**: Set `claimStart` and `claimEnd` timestamps
- **Supply Limits**: Configure `maxSupply` for token cap
- **Affiliate Fees**: Set fee amounts and payment tokens
- **Expiration**: Configure `redeemExpiration` for time limits

## Smart Contracts

### Core Contracts

- **`Coupon.sol`**: Main ERC1155 implementation with affiliate and redemption capabilities
- **`TokenFactory.sol`**: Factory contract for efficient clone deployment

### Key Functions

#### Claiming
```solidity
function claim(address to, uint256 affiliateId) external
```
Mints one token per address with optional affiliate referral.

#### Affiliate Registration
```solidity
function registerAffiliate() external returns (uint256)
```
Registers caller as affiliate and returns unique ID.

#### Coupon Redemption
```solidity
function redeemCoupons(uint256[] calldata tokenIds) external onlyOwner
```
Redeems coupons and distributes affiliate fees.

## Development

### Available Commands

```bash
# Development with Hardhat
npx hardhat help                    # Get help
npx hardhat test                    # Run tests
npx hardhat node                    # Start local node
REPORT_GAS=true npx hardhat test    # Gas reporting

# Development with Foundry (recommended for testing)
forge build                        # Compile contracts
forge test                         # Run tests (faster)
forge test -vvv --gas-report       # Verbose with gas reporting

# Shortcuts via Makefile
make deploy-factory                 # Deploy factory contract
make test                          # Run all tests
```

### Project Structure

```
contracts/
├── contracts/          # Solidity source files
├── scripts/           # Deployment and utility scripts
├── ignition/          # Hardhat Ignition deployment modules
├── test/              # Test files (Hardhat & Foundry)
├── deployments/       # Deployment records by network
└── coupons/           # Generated coupon data and records
```

## Testing

The project includes comprehensive test suites using both Hardhat and Foundry:

### Running Tests

```bash
# Hardhat tests (JavaScript/TypeScript)
npm test
npm run coverage

# Foundry tests (Solidity - faster execution)
forge test
forge test -vv          # With logs
forge test -vvv         # With stack traces
```

### Test Coverage

- ✅ Token claiming and supply limits
- ✅ Affiliate registration and fee distribution  
- ✅ Coupon redemption and expiration
- ✅ Budget management and withdrawals
- ✅ Access controls and security features
- ✅ Gas optimization and edge cases

## Environment Setup

Create a `.env` file with the following variables:

```bash
# Network Configuration
FACTORY_ADDRESS=0x1234567890123456789012345678901234567890

# IPFS Storage (Pinata)
PINATA_JWT=your_pinata_jwt_token_here
PINATA_GATEWAY=your_custom_gateway.mypinata.cloud

# Private Keys (for deployment)
PRIVATE_KEY=your_private_key_here

# API Keys (optional)
ETHERSCAN_API_KEY=your_etherscan_api_key
BASESCAN_API_KEY=your_basescan_api_key
```

### Getting Pinata Credentials

1. Sign up at [Pinata](https://app.pinata.cloud/)
2. Create an API key with "Admin" permissions
3. Copy the JWT token to your `.env` file
4. Configure your custom gateway domain

## Contributing

Contributions are welcome! Please follow these guidelines:

### Development Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Write or update tests
5. Ensure all tests pass: `npm test && forge test`
6. Update documentation if needed
7. Submit a pull request

### Code Standards

- **Testing**: Maintain 100% test coverage
- **Documentation**: Include NatSpec comments for all public functions
- **Gas Optimization**: Provide gas reports for contract changes
- **Linting**: Code must pass all lint checks (`npm run lint`)
- **Security**: Follow OpenZeppelin security patterns

### Pull Request Requirements

- [ ] All tests pass
- [ ] Gas snapshots provided for contract changes
- [ ] Documentation updated
- [ ] Code follows style guide
- [ ] Security considerations addressed

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 Mangia Contracts

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

**Built with ❤️ for the decentralized future**

For questions, support, or collaboration opportunities, please open an issue or reach out to the development team.


