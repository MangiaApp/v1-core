# PushCola Contracts

![Lint](https://img.shields.io/badge/Lint-passing-brightgreen) ![Tests](https://img.shields.io/badge/Tests-passing-brightgreen)

This project implements a smart contract system for lazy minting ERC1155 tokens with affiliate marketing features. The system allows for token claiming, affiliate registration, and coupon redemption with a fee mechanism.

## Core Features

- **Lazy Minting** of ERC1155 tokens
- **Affiliate Registration** system with unique affiliate IDs
- **Coupon Redemption** with configurable fees
- **Time-bound Claims** with customizable start and end dates
- **Budget Management** for affiliate payments

## Contract Conditions

### Token Claiming
- Users can only claim one token per address
- Claims must be made between the configured `claimStart` and `claimEnd` dates
- Total supply cannot exceed `maxSupply`
- Optional affiliate ID can be provided during claim
- Claiming with an affiliate ID associates the token with that affiliate for future redemption

### Affiliate Registration
- Users must register to become affiliates and receive a unique affiliate ID
- Registration requires sufficient budget in the contract (minimum of 5x fee amount)
- Affiliate cannot claim their own affiliate link (prevents self-referral)
- Registered affiliates receive fees when tokens they referred are redeemed

### Coupon Redemption
- Only contract owner can redeem coupons for token holders
- Redemption must occur before `redeemExpiration` date
- Each token can only be redeemed once
- If the token was claimed with an affiliate ID, the affiliate receives the configured fee
- Fees can be paid in either native currency (ETH) or a specified ERC20 token

### Budget Management
- Contract requires a locked budget to pay affiliate fees
- Budget is released to affiliates during coupon redemption
- Owner can withdraw budget with restrictions:
  - Before expiration: must maintain sufficient funds for estimated affiliate payments
  - After expiration: can withdraw any remaining funds
- Budget can be increased by sending additional funds to the contract

## Smart Contracts

- `Coupon.sol` - Main ERC1155 implementation with affiliate and redemption capabilities
- `TokenFactory.sol` - Factory contract that deploys clones of the Coupon contract for efficient deployment

## Development Commands

```shell
# Hardhat Commands
# Get help information
npx hardhat help

# Run tests with Hardhat
npx hardhat test

# Run tests with gas reporting
REPORT_GAS=true npx hardhat test

# Start a local Ethereum node
npx hardhat node

# Deploy the factory contract to Base network
npx hardhat ignition deploy ignition/modules/TokenFactory.ts --network localhost
# Or use the Makefile shortcut
make deploy-factory

# Foundry Commands
# Run tests with Foundry (faster execution)
forge test

# Run tests with verbosity and gas reporting
forge test -vvv --gas-report

# Build contracts
forge build
```

## Project Structure

- `/contracts`: Smart contract source files
- `/scripts`: Deployment and interaction scripts
- `/ignition`: Hardhat Ignition deployment modules
- `/deployments`: Records of deployed contracts by network


