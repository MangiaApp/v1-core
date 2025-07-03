const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting campaign creation...");

  try {
    // Get network and signers
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Creating campaign with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Get factory address from deployed_addresses.json
    let factoryAddress;
    try {
      // Try to load from ignition deployments
      const deploymentPath = path.join(__dirname, "../ignition/deployments/chain-8453/deployed_addresses.json");
      if (fs.existsSync(deploymentPath)) {
        const deploymentInfo = JSON.parse(fs.readFileSync(deploymentPath, 'utf8'));
        factoryAddress = deploymentInfo["MangiaCampaignFactoryModule#MangiaCampaignFactory"];
        console.log(`Loaded factory address from ignition deployments: ${factoryAddress}`);
      } else {
        throw new Error("Ignition deployment info not found");
      }
    } catch (error) {
      // Fallback to environment variable
      console.log(`Error loading from ignition deployments: ${error.message}`);
      factoryAddress = process.env.CAMPAIGN_FACTORY_ADDRESS;
      
      if (!factoryAddress) {
        console.error("Failed to get factory address from deployments and no CAMPAIGN_FACTORY_ADDRESS environment variable set");
        process.exit(1);
      }
      
      console.log(`Using factory address from environment: ${factoryAddress}`);
    }

    // Connect to the factory contract
    const MangiaCampaignFactory = await ethers.getContractFactory("MangiaCampaignFactory");
    const factory = MangiaCampaignFactory.attach(factoryAddress);

    // Campaign parameters - customize these as needed
    const campaignData = {
      contractURI: "ipfs://bafkreicn6nroaqszai7jwbpdnt75gvnjrcrd4mbraxz6wseutcmsk6fodi", // Brand metadata
      initialCampaignURI: "ipfs://bafybeid4djduj36xsco6ic4pit3lvk2m73cuz3cd3rxgzr6jsepvsot7yu", // Campaign metadata
      totalBudgetInCredits: 10000, // Total budget in credits
      minCreditsPerParticipant: 100, // Minimum credits per participant
      expirationTimestamp: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60) // 30 days from now
    };

    console.log(`Campaign Parameters:
    - Contract URI: ${campaignData.contractURI}
    - Initial Campaign URI: ${campaignData.initialCampaignURI}
    - Total Budget: ${campaignData.totalBudgetInCredits} credits
    - Min Credits per Participant: ${campaignData.minCreditsPerParticipant} credits
    - Expiration: ${new Date(campaignData.expirationTimestamp * 1000).toLocaleString()}
    `);

    // Estimate gas before transaction
    const gasEstimate = await factory.estimateGas.createCampaign(
      campaignData.contractURI,
      campaignData.initialCampaignURI,
      campaignData.totalBudgetInCredits,
      campaignData.minCreditsPerParticipant,
      campaignData.expirationTimestamp
    );
    
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the campaign
    console.log("Creating new campaign...");
    const tx = await factory.createCampaign(
      campaignData.contractURI,
      campaignData.initialCampaignURI,
      campaignData.totalBudgetInCredits,
      campaignData.minCreditsPerParticipant,
      campaignData.expirationTimestamp,
      {
        gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
      }
    );

    console.log(`Transaction sent: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    // Parse the event to get the campaign address
    const campaignCreatedEvent = receipt.events.find(e => e.event === "CampaignCreated");
    
    if (campaignCreatedEvent) {
      const campaignAddress = campaignCreatedEvent.args.campaignAddress;
      const brandOwner = campaignCreatedEvent.args.brandOwner;
      const timestamp = campaignCreatedEvent.args.timestamp;
      
      console.log("\n===== Campaign Creation Complete =====");
      console.log(`Campaign address: ${campaignAddress}`);
      console.log(`Brand owner: ${brandOwner}`);
      console.log(`Created at: ${new Date(timestamp.toNumber() * 1000).toLocaleString()}`);
      console.log(`Expiration: ${new Date(campaignData.expirationTimestamp * 1000).toLocaleString()}`);
      
      // Save campaign info to file
      saveCampaignInfo(network.name, {
        address: campaignAddress,
        brandOwner: brandOwner,
        creator: deployer.address,
        timestamp: new Date().toISOString(),
        contractURI: campaignData.contractURI,
        initialCampaignURI: campaignData.initialCampaignURI,
        totalBudgetInCredits: campaignData.totalBudgetInCredits,
        minCreditsPerParticipant: campaignData.minCreditsPerParticipant,
        expirationTimestamp: campaignData.expirationTimestamp,
        txHash: tx.hash,
        blockNumber: receipt.blockNumber
      });

      // Get additional info from the factory
      const campaignsByBrand = await factory.getCampaignsByBrand(brandOwner);
      const brandInfo = await factory.getBrandInfo(brandOwner);
      
      console.log(`\nBrand Statistics:`);
      console.log(`- Total campaigns: ${campaignsByBrand.length}`);
      console.log(`- Brand registered at: ${new Date(brandInfo.createdAt.toNumber() * 1000).toLocaleString()}`);
      
    } else {
      console.error("Could not find CampaignCreated event in transaction receipt");
      console.log("Available events:", receipt.events.map(e => e.event));
    }
    
  } catch (error) {
    console.error("Error during campaign creation:", error);
    
    if (error.message.includes("Contract URI cannot be empty")) {
      console.log("Make sure to provide a valid contractURI");
    } else if (error.message.includes("Campaign URI cannot be empty")) {
      console.log("Make sure to provide a valid initialCampaignURI");
    } else if (error.message.includes("Budget must be greater than 0")) {
      console.log("Make sure totalBudgetInCredits is greater than 0");
    } else if (error.message.includes("Min credits must be greater than 0")) {
      console.log("Make sure minCreditsPerParticipant is greater than 0");
    } else if (error.message.includes("Expiration must be in future")) {
      console.log("Make sure expirationTimestamp is in the future");
    }
    
    process.exit(1);
  }
}

function saveCampaignInfo(network, info) {
  // Create directory if doesn't exist
  const campaignsDir = path.join(__dirname, "../campaigns");
  if (!fs.existsSync(campaignsDir)) {
    fs.mkdirSync(campaignsDir);
  }
  
  // Create network directory if doesn't exist
  const networkDir = path.join(campaignsDir, network);
  if (!fs.existsSync(networkDir)) {
    fs.mkdirSync(networkDir);
  }
  
  // Write to file
  const fileName = `campaign_${info.address.toLowerCase()}.json`;
  const filePath = path.join(networkDir, fileName);
  
  fs.writeFileSync(filePath, JSON.stringify(info, null, 2));
  console.log(`Campaign info saved to: ${filePath}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
