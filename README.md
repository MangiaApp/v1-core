# Mangia Contracts

![Lint](https://img.shields.io/badge/Lint-passing-brightgreen) ![Tests](https://img.shields.io/badge/Tests-passing-brightgreen) ![License](https://img.shields.io/badge/License-MIT-blue) ![Solidity](https://img.shields.io/badge/Solidity-0.8.19-orange)

A smart contract system for managing influencer marketing campaigns, enabling restaurants and brands to create budget-allocated campaigns that micro influencers can claim in exchange for social media content creation on TikTok, with built-in off-chain content validation and automated payment distribution.

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

Mangia Contracts implements a comprehensive platform for influencer marketing campaigns in the restaurant and brand industry. The system allows restaurants and brands to create marketing campaigns with allocated budgets, which micro influencers can claim in exchange for creating and posting content on TikTok.

The platform uses ERC1155 tokens to represent campaign participation rights, enabling efficient campaign management with built-in budget allocation, content validation workflows, and automatic payment distribution to successful influencers upon content approval.

This solution bridges the gap between traditional marketing spend and social media influence, providing a transparent, blockchain-based system for campaign management and influencer compensation.

## Key Features

- **🏪 Brand Campaign Creation**: Restaurants and brands can create marketing campaigns with allocated budgets
- **📱 Influencer Participation**: Micro influencers can claim available campaigns and receive campaign tokens
- **🎬 Content Validation**: Built-in workflow for validating TikTok content before payment release
- **💰 Budget Management**: Automated budget allocation and payment distribution system
- **🎯 Lazy Minting**: Efficient ERC1155 token creation representing campaign participation
- **👥 Multi-Stakeholder**: Support for brands, influencers, and content validators
- **📊 Campaign Analytics**: Track campaign performance and influencer engagement
- **⏰ Time Controls**: Configurable campaign windows and content submission deadlines
- **🔒 Security**: Anti-fraud measures and secure payment escrow system

## Deployments

The contracts can be deployed to any EVM-compatible blockchain. Current deployments:

| Network | Factory Address | Status |
|---------|----------------|--------|
| Localhost | `0x1234...` | Development |
| Base Testnet | Coming Soon | Planned |
| Base Mainnet | Coming Soon | Planned |

## Architecture

The system consists of campaign management and validation contracts:

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   TokenFactory  │───▶│   Campaign Clone │    │  Content        │
│                 │    │   (ERC1155)      │◄──►│  Validator      │
│ - Deploy clones │    │ - Budget mgmt    │    │ - Review posts  │
│ - Gas efficient │    │ - Influencer sys │    │ - Release fees  │
└─────────────────┘    │ - Token minting  │    └─────────────────┘
                       └──────────────────┘
```

### Campaign Workflow

1. **Campaign Creation**: Brands deploy new campaign contracts with budget allocation
2. **Budget Deposit**: Brands deposit campaign budget into smart contract escrow
3. **Influencer Claims**: Micro influencers claim campaign slots and receive participation tokens
4. **Content Creation**: Influencers create and post TikTok content according to campaign requirements
5. **Content Validation**: Submitted content undergoes validation process *(upcoming feature)*
6. **Payment Release**: Upon validation approval, campaign fees are automatically distributed to influencers

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
- **Pinata**: IPFS pinning service for campaign metadata storage

## Usage

### Quick Start

1. **Deploy the factory**:
```bash
npx hardhat ignition deploy ignition/modules/TokenFactory.ts --network localhost
```

2. **Create a campaign contract**:
```bash
npx hardhat run scripts/createCampaign.js --network localhost
```

3. **Configure your campaign** with budget, requirements, and content submission deadlines

### Basic Integration

```solidity
// Example: Brand creating a campaign
function createCampaign(
    uint256 budget,
    uint256 maxInfluencers,
    uint256 feePerInfluencer
) external {
    campaign.initialize(budget, maxInfluencers, feePerInfluencer);
}

// Example: Influencer claiming campaign slot
function claimCampaignSlot() external {
    campaign.claimSlot(msg.sender);
}

// Example: Content validation and payment release (upcoming)
function validateAndPay(uint256 tokenId, bool approved) external onlyValidator {
    campaign.validateContent(tokenId, approved);
}
```

### Configuration Options

- **Campaign Window**: Set `campaignStart` and `campaignEnd` timestamps
- **Budget Limits**: Configure total budget and fee per influencer
- **Content Requirements**: Set TikTok post requirements and submission deadlines
- **Validation**: Configure content review process and approval criteria

## Smart Contracts

### Core Contracts

- **`Campaign.sol`**: Main ERC1155 implementation for campaign management and influencer participation
- **`TokenFactory.sol`**: Factory contract for efficient campaign contract deployment
- **`ContentValidator.sol`**: *(Upcoming)* Contract for managing content validation and payment release

### Key Functions

#### Campaign Management
```solidity
function createCampaign(
    uint256 budget,
    uint256 maxInfluencers,
    uint256 feePerInfluencer
) external onlyBrand
```
Creates a new marketing campaign with specified budget and parameters.

#### Influencer Participation
```solidity
function claimCampaignSlot() external returns (uint256)
```
Allows micro influencers to claim available campaign slots and receive participation tokens.

#### Content Validation *(Upcoming Feature)*
```solidity
function submitContent(uint256 tokenId, string calldata contentUrl) external
function validateContent(uint256 tokenId, bool approved) external onlyValidator
```
Handles content submission and validation workflow for payment release.

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
└── campaigns/         # Generated campaign data and records
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

- ✅ Campaign creation and budget management
- ✅ Influencer registration and slot claiming
- ✅ Token minting and supply limits
- ✅ Budget allocation and payment distribution  
- ✅ Content validation workflow *(in development)*
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

```

---

**Built with ❤️ for connecting brands with micro influencers**

For questions, support, or collaboration opportunities, please open an issue or reach out to the development team.


