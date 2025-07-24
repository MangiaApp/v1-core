import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const TokenFactoryModule = buildModule('TokenFactoryModule', (m) => {
  // First deploy the Campaign implementation contract
  const campaignImpl = m.contract('Campaign');

  // Deploy the ProjectFactory with the Campaign implementation address
  const projectFactory = m.contract('ProjectFactory', [campaignImpl]);

  // Return both deployed contracts
  return { campaignImpl, projectFactory };
});

export default TokenFactoryModule;

