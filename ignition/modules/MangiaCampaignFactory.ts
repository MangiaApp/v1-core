import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const MangiaCampaignFactoryModule = buildModule('MangiaCampaignFactoryModule', (m) => {
  // Deploy the MangiaCampaignFactory contract
  // Note: Unlike TokenFactory, this doesn't need an implementation contract
  // because it creates direct instances of MangiaCampaign1155 using "new"
  const mangiaCampaignFactory = m.contract('MangiaCampaignFactory');

  // Return the deployed contract
  return { mangiaCampaignFactory };
});

export default MangiaCampaignFactoryModule; 