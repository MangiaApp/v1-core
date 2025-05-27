import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const TokenFactoryModule = buildModule('TokenFactoryModule', (m) => {
  // First deploy the Coupon implementation contract
  const couponImpl = m.contract('Coupon');

  // Deploy the TokenFactory with the Coupon implementation address
  const tokenFactory = m.contract('TokenFactory', [couponImpl]);

  // Return both deployed contracts
  return { couponImpl, tokenFactory };
});

export default TokenFactoryModule;

