const { ethers, upgrades } = require("hardhat");

async function main() {
  // Dirección del proxy ya desplegado
  const proxyAddress = "0x8bFf438bC6CC9E946e2539181813ad031AA03aeE";
  
  // Valores necesarios para la inicialización
  const DEFAULT_ADMIN_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; 
  const DEFAULT_PAUSER_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; 
  const DEFAULT_MINTER_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; 
  const DEFAULT_UPGRADER_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a';

  // Obtén una instancia del contrato a través del proxy
  const OpenBitcoinCredit = await ethers.getContractAt("OpenBitcoinCredit", proxyAddress);

  // Llamar a la función initialize del contrato proxy
  const tx = await OpenBitcoinCredit.initialize(
    DEFAULT_ADMIN_ADDRESS, 
    DEFAULT_PAUSER_ADDRESS, 
    DEFAULT_MINTER_ADDRESS, 
    DEFAULT_UPGRADER_ADDRESS,
    { gasLimit: 1000000 } 
  );

  // Esperar a que la transacción sea confirmada
  await tx.wait();

  console.log("Contrato inicializado correctamente a través del proxy en:", proxyAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
