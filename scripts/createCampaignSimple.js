const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting simplified campaign creation...");

  try {
    // Get network and signers
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Creating campaign with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Warn if balance is low
    const minETH = ethers.utils.parseEther("0.01"); // 0.01 ETH minimum
    if (balance.lt(minETH)) {
      console.log("⚠️  WARNING: Low ETH balance. You may need more ETH for deployment.");
      console.log("Consider getting ETH from a faucet or bridge for Base network");
    }

    // Get factory address
    let factoryAddress;
    try {
      const deploymentPath = path.join(__dirname, "../ignition/deployments/chain-8453/deployed_addresses.json");
      if (fs.existsSync(deploymentPath)) {
        const deploymentInfo = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
        factoryAddress = deploymentInfo["MangiaCampaignFactoryModule#MangiaCampaignFactory"];
        console.log(`Factory address: ${factoryAddress}`);
      } else {
        throw new Error("Deployment info not found");
      }
    } catch (error) {
      console.error("Failed to load factory address:", error.message);
      process.exit(1);
    }

    // Connect to the factory contract
    const MangiaCampaignFactory = await ethers.getContractFactory("MangiaCampaignFactory");
    const factory = MangiaCampaignFactory.attach(factoryAddress);

    // Use simplified campaign parameters
    const campaignData = {
      contractURI: "ipfs://QmYourBrandMetadataHash", // Simplified IPFS hash
      initialCampaignURI: "ipfs://QmYourCampaignMetadataHash", // Simplified IPFS hash
      totalBudgetInCredits: 100, // Smaller budget to reduce gas
      minCreditsPerParticipant: 10, // Smaller minimum
      expirationTimestamp: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60) // 7 days from now
    };

    console.log(`Simplified Campaign Parameters:
    - Contract URI: ${campaignData.contractURI}
    - Initial Campaign URI: ${campaignData.initialCampaignURI}
    - Total Budget: ${campaignData.totalBudgetInCredits} credits
    - Min Credits per Participant: ${campaignData.minCreditsPerParticipant} credits
    - Expiration: ${new Date(campaignData.expirationTimestamp * 1000).toLocaleString()}
    `);

    // Try static call first to check if transaction would succeed
    console.log("Testing transaction with static call...");
    try {
      const staticResult = await factory.callStatic.createCampaign(
        campaignData.contractURI,
        campaignData.initialCampaignURI,
        campaignData.totalBudgetInCredits,
        campaignData.minCreditsPerParticipant,
        campaignData.expirationTimestamp
      );
      console.log(`✅ Static call successful. Campaign would be deployed at: ${staticResult}`);
    } catch (staticError) {
      console.error("❌ Static call failed. Transaction would revert:");
      console.error(staticError.message);
      
      // Check for specific error patterns
      if (staticError.message.includes("Contract URI cannot be empty")) {
        console.log("Issue: Contract URI validation failed");
      } else if (staticError.message.includes("Campaign URI cannot be empty")) {
        console.log("Issue: Campaign URI validation failed");
      } else if (staticError.message.includes("Budget must be greater than 0")) {
        console.log("Issue: Budget validation failed");
      } else if (staticError.message.includes("Expiration must be in future")) {
        console.log("Issue: Expiration timestamp validation failed");
      } else {
        console.log("Issue: Unknown contract validation error");
      }
      
      process.exit(1);
    }

    // If static call succeeded, try gas estimation
    console.log("Estimating gas...");
    let gasEstimate;
    try {
      gasEstimate = await factory.estimateGas.createCampaign(
        campaignData.contractURI,
        campaignData.initialCampaignURI,
        campaignData.totalBudgetInCredits,
        campaignData.minCreditsPerParticipant,
        campaignData.expirationTimestamp
      );
      console.log(`✅ Gas estimation successful: ${gasEstimate.toString()}`);
    } catch (gasError) {
      console.error("❌ Gas estimation failed:", gasError.message);
      console.log("This might indicate an issue with contract size or complexity");
      
      // Try with a higher gas limit manually
      gasEstimate = ethers.BigNumber.from("5000000"); // 5M gas limit
      console.log(`Using manual gas limit: ${gasEstimate.toString()}`);
    }

    // Check if we have enough ETH for the transaction
    const gasPrice = await ethers.provider.getGasPrice();
    const estimatedCost = gasEstimate.mul(gasPrice);
    console.log(`Estimated transaction cost: ${ethers.utils.formatEther(estimatedCost)} ETH`);
    
    if (balance.lt(estimatedCost)) {
      console.error("❌ Insufficient ETH balance for transaction");
      console.log(`Need: ${ethers.utils.formatEther(estimatedCost)} ETH`);
      console.log(`Have: ${ethers.utils.formatEther(balance)} ETH`);
      console.log("Please add more ETH to your account and try again");
      process.exit(1);
    }

    // Execute the transaction
    console.log("Creating campaign...");
    const tx = await factory.createCampaign(
      campaignData.contractURI,
      campaignData.initialCampaignURI,
      campaignData.totalBudgetInCredits,
      campaignData.minCreditsPerParticipant,
      campaignData.expirationTimestamp,
      {
        gasLimit: gasEstimate.mul(120).div(100), // Add 20% buffer
        gasPrice: gasPrice
      }
    );

    console.log(`✅ Transaction sent: ${tx.hash}`);
    console.log("Waiting for confirmation...");
    
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
    
    // Parse events
    const campaignCreatedEvent = receipt.events?.find(e => e.event === "CampaignCreated");
    
    if (campaignCreatedEvent) {
      const campaignAddress = campaignCreatedEvent.args.campaignAddress;
      const brandOwner = campaignCreatedEvent.args.brandOwner;
      
      console.log("\n🎉 Campaign Creation Successful!");
      console.log(`Campaign address: ${campaignAddress}`);
      console.log(`Brand owner: ${brandOwner}`);
      console.log(`Transaction hash: ${tx.hash}`);
      console.log(`Block number: ${receipt.blockNumber}`);
      console.log(`Gas used: ${receipt.gasUsed.toString()}`);
      
    } else {
      console.log("⚠️  Campaign created but event parsing failed");
      console.log("Check the transaction hash on a block explorer");
    }
    
  } catch (error) {
    console.error("❌ Error during campaign creation:", error.message);
    
    // Provide helpful debugging information
    if (error.message.includes("insufficient funds")) {
      console.log("\n💡 Solution: Add more ETH to your account");
    } else if (error.message.includes("nonce too low")) {
      console.log("\n💡 Solution: Wait a moment and try again (nonce issue)");
    } else if (error.message.includes("replacement transaction underpriced")) {
      console.log("\n💡 Solution: Increase gas price or wait for previous transaction");
    } else if (error.message.includes("execution reverted")) {
      console.log("\n💡 Possible solutions:");
      console.log("1. Check that all parameters are valid");
      console.log("2. Ensure contract dependencies are properly deployed");
      console.log("3. Try running the debug script: npx hardhat run scripts/debugCampaign.js --network base");
    }
    
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 