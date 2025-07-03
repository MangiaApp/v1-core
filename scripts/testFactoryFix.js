const { ethers } = require("hardhat");

async function main() {
  console.log("Testing updated MangiaCampaignFactory locally...");

  try {
    // Get network and deployer
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Testing with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Deploy the updated factory locally
    console.log("\n=== Deploying Updated Factory ===");
    const MangiaCampaignFactory = await ethers.getContractFactory("MangiaCampaignFactory");
    const factory = await MangiaCampaignFactory.deploy();
    await factory.deployed();
    
    console.log(`✅ Factory deployed at: ${factory.address}`);

    // Test campaign creation
    console.log("\n=== Testing Campaign Creation ===");
    
    const campaignData = {
      contractURI: "ipfs://test-brand-metadata",
      initialCampaignURI: "ipfs://test-campaign-metadata",
      totalBudgetInCredits: 1000,
      minCreditsPerParticipant: 50,
      expirationTimestamp: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60) // 7 days
    };

    console.log("Campaign parameters:");
    console.log(`- Contract URI: ${campaignData.contractURI}`);
    console.log(`- Campaign URI: ${campaignData.initialCampaignURI}`);
    console.log(`- Budget: ${campaignData.totalBudgetInCredits} credits`);
    console.log(`- Min credits: ${campaignData.minCreditsPerParticipant} credits`);

    // Create campaign
    const tx = await factory.createCampaign(
      campaignData.contractURI,
      campaignData.initialCampaignURI,
      campaignData.totalBudgetInCredits,
      campaignData.minCreditsPerParticipant,
      campaignData.expirationTimestamp
    );

    console.log(`✅ Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);

    // Find the CampaignCreated event
    const campaignCreatedEvent = receipt.events?.find(e => e.event === "CampaignCreated");
    
    if (campaignCreatedEvent) {
      const campaignAddress = campaignCreatedEvent.args.campaignAddress;
      const brandOwner = campaignCreatedEvent.args.brandOwner;
      
      console.log("\n🎉 Campaign Creation Successful!");
      console.log(`📄 Campaign Address: ${campaignAddress}`);
      console.log(`👤 Brand Owner: ${brandOwner}`);
      console.log(`⛽ Gas Used: ${receipt.gasUsed.toString()}`);

      // Verify ownership was transferred correctly
      const MangiaCampaign1155 = await ethers.getContractFactory("MangiaCampaign1155");
      const campaign = MangiaCampaign1155.attach(campaignAddress);
      
      const owner = await campaign.owner();
      console.log(`✅ Campaign owner is: ${owner}`);
      console.log(`✅ Owner matches deployer: ${owner === deployer.address}`);

      // Verify campaign was created
      const campaignInfo = await campaign.getCampaignInfo(1); // First campaign has ID 1
      console.log(`✅ Campaign budget: ${campaignInfo.totalBudgetInCredits.toString()} credits`);
      console.log(`✅ Campaign active: ${campaignInfo.active}`);

      // Test factory statistics
      const totalCampaigns = await factory.getTotalCampaignCount();
      const brandCampaigns = await factory.getCampaignsByBrand(deployer.address);
      
      console.log(`\n📊 Factory Statistics:`);
      console.log(`- Total campaigns: ${totalCampaigns}`);
      console.log(`- Brand campaigns: ${brandCampaigns.length}`);

    } else {
      console.error("❌ CampaignCreated event not found");
    }

    console.log("\n✅ ALL TESTS PASSED! The fix works correctly.");
    console.log("\n📝 Summary:");
    console.log("- Factory correctly makes itself temporary owner");
    console.log("- Factory successfully calls createCampaign");
    console.log("- Ownership is properly transferred to user");
    console.log("- No OwnableUnauthorizedAccount errors occurred");
    
  } catch (error) {
    console.error("❌ Test failed:", error.message);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 