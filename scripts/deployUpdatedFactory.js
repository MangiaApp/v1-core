const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying updated MangiaCampaignFactory...");

  try {
    // Get network and deployer
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Deploy the updated factory
    console.log("Deploying MangiaCampaignFactory...");
    const MangiaCampaignFactory = await ethers.getContractFactory("MangiaCampaignFactory");
    
    // Estimate gas
    const deployTx = MangiaCampaignFactory.getDeployTransaction();
    const gasEstimate = await ethers.provider.estimateGas(deployTx);
    console.log(`Estimated gas: ${gasEstimate.toString()}`);
    
    // Check if we have enough ETH
    const gasPrice = await ethers.provider.getGasPrice();
    const estimatedCost = gasEstimate.mul(gasPrice);
    console.log(`Estimated cost: ${ethers.utils.formatEther(estimatedCost)} ETH`);
    
    if (balance.lt(estimatedCost)) {
      console.error("❌ Insufficient ETH for deployment");
      console.log(`Need: ${ethers.utils.formatEther(estimatedCost)} ETH`);
      console.log(`Have: ${ethers.utils.formatEther(balance)} ETH`);
      process.exit(1);
    }

    // Deploy
    const factory = await MangiaCampaignFactory.deploy({
      gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
    });

    console.log("Waiting for deployment...");
    await factory.deployed();
    
    console.log("\n🎉 Deployment successful!");
    console.log(`📄 Updated Factory Address: ${factory.address}`);
    console.log(`🔗 Transaction hash: ${factory.deployTransaction.hash}`);
    console.log(`⛽ Gas used: ${(await factory.deployTransaction.wait()).gasUsed.toString()}`);
    
    // Verify the fix works
    console.log("\n🧪 Testing the fix...");
    const totalCampaigns = await factory.getTotalCampaignCount();
    console.log(`✅ Factory is working. Total campaigns: ${totalCampaigns}`);
    
    console.log("\n📝 Next steps:");
    console.log("1. Update your scripts to use the new factory address:");
    console.log(`   OLD: 0x1686BEC98221F77C58F13e5AF430A512cF15f1dC`);
    console.log(`   NEW: ${factory.address}`);
    console.log("2. Test campaign creation with the new factory");
    console.log("3. Update your frontend/app to use the new factory address");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error.message);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 