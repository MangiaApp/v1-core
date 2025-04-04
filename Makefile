.PHONY: deploy-factory

deploy-factory:
	npx hardhat ignition deploy ignition/modules/LazyMintFactory.ts --network base 