const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");


async function main() {
  console.log("🚀 Starting project creation with real metadata uploaded to IPFS...");

  try {
    // Initialize IPFS helper
    // const ipfsHelper = new IPFSHelper();
    
    // Get network and signers
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Creating project with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Use the new factory address
    const factoryAddress = "0x1084d6E7bFdbB6f0457F38E638432c38c20f1fFe";
    console.log(`Using factory address: ${factoryAddress}`);

    // Connect to the factory contract
    const TokenFactory = await ethers.getContractFactory("ProjectFactory");
    const factory = TokenFactory.attach(factoryAddress);

    // Generate a random salt
    const salt = ethers.utils.randomBytes(32);

    // Use default metadata URIs
    console.log("\n📊 Using default project metadata...");
    const projectMetadataURI = "ipfs://QmXFxZKQzMj6qjQoxQL1Xg7FuAiJJ9ZgrZCjRDN8a7y1Zx"; // Brand metadata
    
    console.log("\n🎫 Using default coupon metadata...");
    const firstCouponUri = "ipfs://QmX5sMEfciBRxMUbW7yy6EQfiv4tECXTcAFXXLLX45KpkY"; // Campaign metadata
    
    // For display purposes, create mock metadata objects
    const projectMetadata = {
      name: "Default Project",
      description: "Default project using preset metadata",
      city: "Default City",
      country: "Default Country",
      category: "Default Category"
    };
    
    const firstCouponMetadata = {
      name: "Default Coupon",
      description: "Default coupon using preset metadata",
      visibility: "public",
      attributes: []
    };

    // Project parameters with realistic values
    const now = Math.floor(Date.now() / 1000);
    const maxSupply = Math.floor(Math.random() * 900) + 100; // Random between 100-1000
    const claimStart = now; // Can claim immediately
    const claimEnd = now + (30 * 24 * 60 * 60); // 30 days from now
    const redeemExpiration = now + (90 * 24 * 60 * 60); // 90 days from now
    const lockedBudget = ethers.utils.parseEther("0"); // No budget locked for this example
    const currencyAddress = "0x0000000000000000000000000000000000000000"; // ETH address (zero address)
    const fee = 0; // No fee for redemption

    console.log(`\n📋 Project Parameters:`);
    console.log(`- Name: ${projectMetadata.name}`);
    console.log(`- Description: ${projectMetadata.description}`);
    console.log(`- City: ${projectMetadata.city}, ${projectMetadata.country}`);
    console.log(`- Category: ${projectMetadata.category}`);
    console.log(`- Metadata URI: ${projectMetadataURI}`);
    
    console.log(`\n🎫 First Coupon Parameters:`);
    console.log(`- Name: ${firstCouponMetadata.name}`);
    console.log(`- Description: ${firstCouponMetadata.description}`);
    console.log(`- Max Supply: ${maxSupply}`);
    console.log(`- Claim Start: ${new Date(claimStart * 1000).toLocaleString()}`);
    console.log(`- Claim End: ${new Date(claimEnd * 1000).toLocaleString()}`);
    console.log(`- Redemption Expiration: ${new Date(redeemExpiration * 1000).toLocaleString()}`);
    console.log(`- Visibility: ${firstCouponMetadata.visibility}`);
    console.log(`- Attributes: ${firstCouponMetadata.attributes.length} attributes`);
    console.log(`- Metadata URI: ${firstCouponUri}`);

    // Estimate gas before transaction
    try {
      const gasEstimate = await factory.estimateGas.createProject(
        projectMetadataURI,
        currencyAddress,
        firstCouponUri,
        maxSupply,
        claimStart,
        claimEnd,
        redeemExpiration,
        fee,
        lockedBudget,
        salt
      );
      
      console.log(`\n⛽ Estimated gas: ${gasEstimate.toString()}`);

      // Create the project
      console.log("\n🔄 Deploying project contract...");
      const tx = await factory.createProject(
        projectMetadataURI,
        currencyAddress,
        firstCouponUri,
        maxSupply,
        claimStart,
        claimEnd,
        redeemExpiration,
        fee,
        lockedBudget,
        salt,
        {
          gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
        }
      );

      console.log(`📤 Transaction sent: ${tx.hash}`);
      console.log("⏳ Waiting for transaction confirmation...");
      
      const receipt = await tx.wait();
      console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);
      
      // Parse the event to get the project address
      const projectDeployedEvent = receipt.events.find(e => e.event === "ProjectDeployed");
      
      if (projectDeployedEvent) {
        const projectAddress = projectDeployedEvent.args.projectAddress;
        
        console.log("\n🎉 ===== PROJECT CREATION COMPLETE =====");
        console.log(`🏢 Project: ${projectMetadata.name}`);
        console.log(`📍 Location: ${projectMetadata.city}, ${projectMetadata.country}`);
        console.log(`📄 Contract address: ${projectAddress}`);
        console.log(`🔗 Project metadata: ${projectMetadataURI}`);
        console.log(`🎫 First coupon: ${firstCouponMetadata.name} (tokenId 0)`);
        console.log(`📊 Max supply: ${maxSupply}`);
        console.log(`⏰ Claim period: ${new Date(claimStart * 1000).toLocaleDateString()} to ${new Date(claimEnd * 1000).toLocaleDateString()}`);
        console.log(`🔄 Redemption until: ${new Date(redeemExpiration * 1000).toLocaleDateString()}`);
        console.log(`🔗 Coupon metadata: ${firstCouponUri}`);
        
        // Save comprehensive project info to file
        const projectInfo = {
          contractAddress: projectAddress,
          deploymentBlock: receipt.blockNumber,
          deploymentTimestamp: new Date().toISOString(),
          creator: deployer.address,
          transactionHash: tx.hash,
          
          // Project metadata
          projectMetadata: projectMetadata,
          projectMetadataURI: projectMetadataURI,
          
          // First coupon data
          firstCoupon: {
            tokenId: 0,
            metadata: firstCouponMetadata,
            metadataURI: firstCouponUri,
            maxSupply: maxSupply,
            claimStart: claimStart,
            claimEnd: claimEnd,
            redeemExpiration: redeemExpiration,
            fee: fee,
            lockedBudget: lockedBudget.toString()
          },
          
          // Contract parameters
          factory: factoryAddress,
          currencyAddress: currencyAddress,
          salt: ethers.utils.hexlify(salt)
        };
        
        saveProjectInfo(network.name, projectInfo);

        console.log("\n💡 NEXT STEPS:");
        console.log(`1. 🔧 Update scripts to use new project address: ${projectAddress}`);
        console.log("2. 🎫 Test coupon claiming with claimCoupon.js");
        console.log("3. ➕ Add more coupons with addCoupon.js");
        console.log("4. 📊 Deploy subgraph to index the new project");
        
      } else {
        console.error("❌ Could not find ProjectDeployed event in transaction receipt");
      }
      
    } catch (gasError) {
      console.error("❌ Error estimating gas or deploying:", gasError);
      console.log("\n💡 Common solutions:");
      console.log("- Check you have enough ETH for gas fees");
      console.log("- Verify the factory contract address is correct");
      console.log("- Ensure claim dates are in correct chronological order");
    }
    
  } catch (error) {
    console.error("❌ Error during project creation:", error);
    console.log("\n🔧 Troubleshooting tips:");
    console.log("- Ensure you have sufficient ETH balance");
    console.log("- Check network connectivity");
    console.log("- Verify contract addresses are correct");
    console.log("- Set up Pinata credentials for IPFS uploads (optional)");
    process.exit(1);
  }
}

function saveProjectInfo(network, info) {
  try {
    // Create directory if doesn't exist
    const projectsDir = path.join(__dirname, "../projects");
    if (!fs.existsSync(projectsDir)) {
      fs.mkdirSync(projectsDir);
    }
    
    // Create network directory if doesn't exist
    const networkDir = path.join(projectsDir, network);
    if (!fs.existsSync(networkDir)) {
      fs.mkdirSync(networkDir);
    }
    
    // Write to file with timestamp
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `project_${info.projectMetadata.name.replace(/\s+/g, '_')}_${timestamp}.json`;
    const filePath = path.join(networkDir, fileName);
    fs.writeFileSync(filePath, JSON.stringify(info, null, 2));
    console.log(`💾 Project info saved to ${filePath}`);
  } catch (saveError) {
    console.error("⚠️  Could not save project info:", saveError.message);
  }
}

// Execute the main function
main().catch((error) => {
  console.error("💥 Unhandled error:", error);
  process.exitCode = 1;
}); 