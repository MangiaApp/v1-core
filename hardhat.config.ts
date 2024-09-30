import '@nomicfoundation/hardhat-toolbox-viem';

const YOUR_PRIVATE_KEY =
  '5c11c7d8f7eb3d7eae4a7331aa377ba26436ebac45eae194a0090c5778418a25';

const config = {
  solidity: '0.8.27',
  networks: {
    localhost: {
      url: 'http://127.0.0.1:8545',
    },
    baseTestnet: {
      url: 'https://sepolia.base.org', // URL para la Base Testnet
      accounts: [`0x${YOUR_PRIVATE_KEY}`], // Reemplaza con tu clave privada
    },
  },
  ethernal: {
    workspace: '737-bot', // Asegúrate de que coincida con tu workspace
    trace: true, // Habilitar tracing
    sync: true, // Sincronizar bloques
    resetOnStart: false, // Desactiva reset para evitar reiniciar datos del workspace cada vez que arranca
  },
};

export default config;
