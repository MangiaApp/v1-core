import '@nomicfoundation/hardhat-toolbox-viem';
require("@nomicfoundation/hardhat-verify");
require('@nomiclabs/hardhat-ethers');

const YOUR_PRIVATE_KEY = '51c0c13204f5d04aa2062f4b2af07eaf0aebcf57fb966f749b84f7242a8842ba';

const config = {
  solidity: '0.8.27',
  sourcify: {
    enabled: true,
  },
  hardhat: {
    blockGasLimit: 100000212323213000429720 // whatever you want here
  },
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    baseTestnet: {
      url: 'https://sepolia.base.org', // URL para la Base Testnet
      accounts: [`0x${YOUR_PRIVATE_KEY}`], // Reemplaza con tu clave privada
    },
    base: {
      url: 'https://mainnet.base.org', // URL para la Base Testnet
      accounts: [`0x${YOUR_PRIVATE_KEY}`], // Reemplaza con tu clave privada
    },
    ethereumMainnet: {
      url: 'https://eth-mainnet.g.alchemy.com/v2/AiHJp8DqQ6baXmRekNj8FJ37igYDqsdg',
      accounts: [`0x${YOUR_PRIVATE_KEY}`], // Reemplaza con tu clave privada
    },
  },
  etherscan: {
    apiKey: {
      base: "5K58SQ4DXDSNXSCYY3SEIA3MX4KFNFGTA6",
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
    ],
  },
  ethernal: {
    workspace: '737-bot', // Asegúrate de que coincida con tu workspace
    trace: true, // Habilitar tracing
    sync: true, // Sincronizar bloques
    resetOnStart: false, // Desactiva reset para evitar reiniciar datos del workspace cada vez que arranca
  },
};

export default config;
