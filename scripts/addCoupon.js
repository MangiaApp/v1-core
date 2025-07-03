const { ethers } = require("hardhat");
const IPFSHelper = require("./ipfsHelper");

async function main() {
  console.log("🎫 Adding a new coupon with real metadata uploaded to IPFS...");

  try {
    // Initialize IPFS helper
    const ipfsHelper = new IPFSHelper();
    
    // Get the network
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log(`Using account: ${signer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(signer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Project contract address - Update this to your project address
    const projectAddress = process.env.PROJECT_ADDRESS || "0x9ED89735e67Ef546Eb22f5B69767edD6a65ACbDB";
    console.log(`\n🏢 Project contract address: ${projectAddress}`);
    
    if (!projectAddress || projectAddress === "YOUR_PROJECT_ADDRESS_HERE") {
      console.error("❌ Please set PROJECT_ADDRESS environment variable or update the script with your project address");
      console.log("💡 Example: PROJECT_ADDRESS=0x123... npx hardhat run scripts/addCoupon.js --network base");
      process.exit(1);
    }

    // Connect to the project contract
    const Coupon = await ethers.getContractFactory("Coupon");
    const project = Coupon.attach(projectAddress);

    // Get current project information
    console.log("\n📊 Fetching project information...");
    try {
      const projectMetadataURI = await project.projectMetadataURI();
      const totalCoupons = await project.getTotalCoupons();
      const owner = await project.owner();

      console.log(`\n📋 Current Project Information:`);
      console.log(`- Owner: ${owner}`);
      console.log(`- Metadata URI: ${projectMetadataURI}`);
      console.log(`- Total coupons: ${totalCoupons.toString()}`);
      console.log(`- NOTE: Fetch project details from: ${projectMetadataURI}`);

      // Check if signer is the owner
      if (signer.address.toLowerCase() !== owner.toLowerCase()) {
        console.error(`❌ Only the project owner can add coupons!`);
        console.log(`   Owner: ${owner}`);
        console.log(`   Signer: ${signer.address}`);
        process.exit(1);
      }

      console.log("✅ Authorization confirmed - you are the project owner");
      
    } catch (contractError) {
      console.error("❌ Error accessing project contract:", contractError.message);
      console.log("💡 Please verify:");
      console.log("- The contract address is correct");
      console.log("- The contract is deployed on this network");
      console.log("- You have network connectivity");
      process.exit(1);
    }

    // Generate new coupon metadata following the schema
    console.log("\n🎫 Generating new coupon metadata...");
    const newCouponMetadata = ipfsHelper.generateCouponMetadata();
    console.log(`Generated coupon: ${newCouponMetadata.name}`);
    console.log(`Description: ${newCouponMetadata.description}`);
    console.log(`Visibility: ${newCouponMetadata.visibility}`);
    console.log(`Attributes: ${newCouponMetadata.attributes.map(attr => attr.value).join(', ')}`);

    // Upload coupon metadata to IPFS
    const couponUri = await ipfsHelper.uploadJSON(
      newCouponMetadata,
      `coupon-${newCouponMetadata.name.replace(/\s+/g, '-').toLowerCase()}.json`
    );

    // Coupon parameters with realistic values
    const now = Math.floor(Date.now() / 1000);
    const maxSupply = Math.floor(Math.random() * 800) + 200; // Random between 200-1000
    const claimStart = now; // Can claim immediately
    const claimEnd = now + (45 * 24 * 60 * 60); // 45 days from now
    const redeemExpiration = now + (120 * 24 * 60 * 60); // 120 days from now
    const fee = 0; // No fee
    const lockedBudget = ethers.utils.parseEther("0"); // No budget locked

    console.log(`\n📋 New Coupon Parameters:`);
    console.log(`- Name: ${newCouponMetadata.name}`);
    console.log(`- Description: ${newCouponMetadata.description}`);
    console.log(`- Max Supply: ${maxSupply}`);
    console.log(`- Claim Start: ${new Date(claimStart * 1000).toLocaleString()}`);
    console.log(`- Claim End: ${new Date(claimEnd * 1000).toLocaleString()}`);
    console.log(`- Redemption Expiration: ${new Date(redeemExpiration * 1000).toLocaleString()}`);
    console.log(`- Fee: ${ethers.utils.formatEther(fee)} ETH`);
    console.log(`- Locked Budget: ${ethers.utils.formatEther(lockedBudget)} ETH`);
    console.log(`- Metadata URI: ${couponUri}`);

    // Estimate gas
    try {
      console.log("\n⛽ Estimating gas...");
      const gasEstimate = await project.estimateGas.createCoupon(
        couponUri,
        maxSupply,
        claimStart,
        claimEnd,
        redeemExpiration,
        fee,
        lockedBudget
      );
      
      console.log(`Estimated gas: ${gasEstimate.toString()}`);

      // Create the new coupon
      console.log("\n🔄 Creating new coupon...");
      const tx = await project.createCoupon(
        couponUri,
        maxSupply,
        claimStart,
        claimEnd,
        redeemExpiration,
        fee,
        lockedBudget,
        {
          gasLimit: gasEstimate.mul(120).div(100), // Add 20% buffer
          value: lockedBudget // Send any required budget
        }
      );

      console.log(`📤 Transaction sent: ${tx.hash}`);
      console.log("⏳ Waiting for transaction confirmation...");
      
      const receipt = await tx.wait();
      console.log(`✅ Transaction confirmed in block ${receipt.blockNumber}`);

      // Get the new total coupons count
      const newTotalCoupons = await project.getTotalCoupons();
      const newTokenId = newTotalCoupons.toNumber() - 1; // Last created token ID

      console.log(`\n🎉 ===== NEW COUPON ADDED SUCCESSFULLY =====`);
      console.log(`🎫 Coupon: ${newCouponMetadata.name}`);
      console.log(`🆔 Token ID: ${newTokenId}`);
      console.log(`📊 Max Supply: ${maxSupply}`);
      console.log(`🔢 Total coupons in project: ${newTotalCoupons.toString()}`);
      console.log(`🔗 Metadata URI: ${couponUri}`);
      
      // Get detailed data for the new coupon
      try {
        const tokenData = await project.getTokenData(newTokenId);
        console.log(`\n📋 New Coupon Details:`);
        console.log(`- Max Supply: ${tokenData.maxSupply.toString()}`);
        console.log(`- Current Supply: ${tokenData.totalSupply.toString()}`);
        console.log(`- Remaining Supply: ${tokenData.maxSupply.sub(tokenData.totalSupply).toString()}`);
        console.log(`- Claim Start: ${new Date(tokenData.claimStart.toNumber() * 1000).toLocaleString()}`);
        console.log(`- Claim End: ${new Date(tokenData.claimEnd.toNumber() * 1000).toLocaleString()}`);
        console.log(`- Redemption Expiration: ${new Date(tokenData.redeemExpiration.toNumber() * 1000).toLocaleString()}`);
        
        console.log(`\n💡 NEXT STEPS:`);
        console.log(`1. 🎫 Test claiming this new coupon (tokenId ${newTokenId})`);
        console.log(`2. 📊 Check subgraph for updated project data`);
        console.log(`3. ➕ Add more coupons if needed`);
        console.log(`4. 🔄 Update frontend to show new coupon`);
        
      } catch (dataError) {
        console.warn("⚠️  Could not fetch detailed token data:", dataError.message);
      }
      
    } catch (gasError) {
      console.error("❌ Error estimating gas or creating coupon:", gasError);
      console.log("\n💡 Common solutions:");
      console.log("- Check you have enough ETH for gas fees");
      console.log("- Verify the project contract is working correctly");
      console.log("- Ensure claim dates are in correct chronological order");
      console.log("- Check if locked budget amount is correct");
    }
    
  } catch (error) {
    console.error("❌ Error adding new coupon:", error);
    console.log("\n🔧 Troubleshooting tips:");
    console.log("- Ensure you have sufficient ETH balance");
    console.log("- Check network connectivity");
    console.log("- Verify you are the project owner");
    console.log("- Set up Pinata credentials for IPFS uploads (optional)");
    console.log("- Update PROJECT_ADDRESS environment variable");
    process.exit(1);
  }
}

// Execute the main function
main().catch((error) => {
  console.error("💥 Unhandled error:", error);
  process.exitCode = 1;
}); 