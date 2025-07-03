.PHONY: deploy-factory deploy-mangia extract-abis

deploy-factory:
	npx hardhat ignition deploy ignition/modules/TokenFactory.ts --network base 

create-coupon:
	npx hardhat run contracts/scripts/createCoupon.js --network base

claim-coupon:
	npx hardhat run scripts/claimCoupon.js --network base

deploy-mangia-factory:
	npx hardhat ignition deploy ignition/modules/MangiaCampaignFactory.ts --network base

create-campaign:
	npx hardhat run scripts/createCampaign.js --network base