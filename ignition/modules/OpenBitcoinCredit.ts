// Este script utiliza Hardhat Ignition para gestionar el despliegue de contratos inteligentes.
// Aprende más en https://hardhat.org/ignition

import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

// Definir valores por defecto (pueden ser cambiados durante el despliegue)
const DEFAULT_ADMIN_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; // Reemplaza con la dirección del administrador
const DEFAULT_PAUSER_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; // Reemplaza con la dirección de pausar
const DEFAULT_MINTER_ADDRESS = '0x44E91B3e2a0ACe8a174104B009F88Dbe60323d0a'; // Reemplaza con la dirección de minteo

const OpenBitcoinCreditModule = buildModule('OpenBitcoinCreditModule', (m) => {
  // Obtener los parámetros de despliegue, con valores por defecto
  const adminAddress = m.getParameter('admin', DEFAULT_ADMIN_ADDRESS);
  const pauserAddress = m.getParameter('pauser', DEFAULT_PAUSER_ADDRESS);
  const minterAddress = m.getParameter('minter', DEFAULT_MINTER_ADDRESS);

  // Desplegar el contrato OpenBitcoinCredit con los parámetros admin, pauser y minter
  const openBitcoinCredit = m.contract('OpenBitcoinCredit', [
    adminAddress,
    pauserAddress,
    minterAddress,
  ]);

  // Retornar el contrato desplegado
  return { openBitcoinCredit };
});

export default OpenBitcoinCreditModule;
