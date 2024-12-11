// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const LazyMintFactoryModule = buildModule('LazyMintFactoryModule', (m) => {
  // Deploy the LazyMintFactory contract
  const lazyMintFactory = m.contract('LazyMintFactory');

  // Return the deployed contract
  return { lazyMintFactory };
});

export default LazyMintFactoryModule;
