import '@nomicfoundation/hardhat-toolbox-viem';
require("@nomicfoundation/hardhat-verify");
require('@nomiclabs/hardhat-ethers');
import { vars } from "hardhat/config";

// Validate required environment variables
function validateEnvVars() {
  const requiredVars = [
    'PRIVATE_KEY',
    'BASESCAN_API_KEY'
  ];

  const missingVars = requiredVars.filter(varName => !vars.has(varName));
  
  if (missingVars.length > 0) {
    throw new Error(`Missing required variables. Please set them using:\n${
      missingVars.map(name => `npx hardhat vars set ${name}`).join('\n')
    }`);
  }
}

// Run validation
validateEnvVars();

const config = {
  solidity: {
    version: '0.8.28',
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      },
    },
  },
  sourcify: {
    enabled: true,
  },
  hardhat: {
    blockGasLimit: 100000212323213000429720
  },
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    base: {
      url: 'https://mainnet.base.org',
      accounts: [vars.get("PRIVATE_KEY")],
      chainId: 8453,
      verifyApiKey: vars.get("BASESCAN_API_KEY"),
    },
    baseTestnet: {
      url: 'https://sepolia.base.org',
      accounts: [vars.get("PRIVATE_KEY")],
      chainId: 84532,
      verifyApiKey: vars.get("BASESCAN_API_KEY"),
    },
  },
  etherscan: {
    apiKey: {
      base: vars.get("BASESCAN_API_KEY"),
      baseTestnet: vars.get("BASESCAN_API_KEY"),
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org",
        },
      },
      {
        network: "baseTestnet",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org",
        },
      },
    ],
  },
};

export default config;
