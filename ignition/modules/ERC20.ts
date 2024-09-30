// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';
import { parseUnits } from 'ethers/lib/utils';

// Definir valores por defecto (pueden ser cambiados durante el despliegue)
const DEFAULT_NAME = 'MyToken';
const DEFAULT_SYMBOL = 'MTK';
const DEFAULT_INITIAL_SUPPLY = parseUnits('1000000', 18); // 1 millón de tokens con 18 decimales

const TokenModule = buildModule('TokenModule', (m) => {
  // Obtener los parámetros de despliegue, con valores por defecto
  const tokenName = m.getParameter('name', DEFAULT_NAME);
  const tokenSymbol = m.getParameter('symbol', DEFAULT_SYMBOL);
  const initialSupply = m.getParameter(
    'initialSupply',
    DEFAULT_INITIAL_SUPPLY.toString(),
  );

  // Desplegar el contrato MyToken con los parámetros
  const myToken = m.contract('MyToken', [
    tokenName,
    tokenSymbol,
    initialSupply,
  ]);

  // Retornar el contrato desplegado
  return { myToken };
});

export default TokenModule;
