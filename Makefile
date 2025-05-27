.PHONY: deploy-factory

deploy-factory:
	npx hardhat ignition deploy ignition/modules/TokenFactory.ts --network base 

create-coupon:
	npx hardhat run contracts/scripts/createCoupon.js --network base

claim-coupon:
	npx hardhat run scripts/claimCoupon.js --network base
