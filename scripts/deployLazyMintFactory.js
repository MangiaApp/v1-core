const { ethers, run, network } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting Coupon and TokenFactory deployment...");

  try {
    console.log(`Deploying to network: ${network.name} (chainId: ${network.config.chainId})`);
    
    // Get signers
    const [deployer] = await ethers.getSigners();
    console.log(`Deploying with account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Deploy the implementation contract that will be used as the blueprint for cloning
    console.log("1. Deploying Coupon implementation contract...");
    const Coupon = await ethers.getContractFactory("Coupon");
    
    // For upgradeable contracts, we deploy a basic implementation without initializing it
    const couponImpl = await Coupon.deploy();
    
    await couponImpl.deployed();
    
    console.log(`Coupon implementation deployed at: ${couponImpl.address}`);
    
    // Now deploy the TokenFactory with the implementation address
    console.log("2. Deploying TokenFactory contract...");
    const TokenFactory = await ethers.getContractFactory("TokenFactory");
    const factory = await TokenFactory.deploy(couponImpl.address);

    // Wait for deployment to complete
    await factory.deployed();

    console.log(`TokenFactory deployed at: ${factory.address}`);
    
    // Save deployment info to file
    saveDeploymentInfo(network.name, {
      CouponImplementation: couponImpl.address,
      TokenFactory: factory.address,
      deployer: deployer.address,
      timestamp: new Date().toISOString(),
      chainId: network.config.chainId?.toString() || "unknown"
    });

    // Verify contracts (skip for local network)
    if (network.name !== "hardhat" && network.name !== "localhost") {
      console.log("Waiting for block confirmations before verification...");
      // Wait for 6 blocks to ensure deployment is confirmed
      await factory.deployTransaction.wait(6);
      
      console.log("Verifying Coupon implementation on blockchain explorer...");
      try {
        await run("verify:verify", {
          address: couponImpl.address,
          constructorArguments: [],
        });
        console.log("Coupon implementation verified successfully");
      } catch (error) {
        console.error("Error verifying Coupon implementation:", error);
      }
      
      console.log("Verifying TokenFactory on blockchain explorer...");
      try {
        await run("verify:verify", {
          address: factory.address,
          constructorArguments: [couponImpl.address],
        });
        console.log("TokenFactory verified successfully");
      } catch (error) {
        console.error("Error verifying TokenFactory:", error);
      }
    }

    // Display usage information
    console.log("\n===== TokenFactory Deployment Complete =====");
    console.log("You can now use the factory to create projects and coupons.");
    console.log("\nExample usage:");
    console.log("1. Create a new project:");
    console.log(`   await factory.createProject("My Awesome Project")`);
    console.log("\n2. Create a new coupon with a new project:");
    console.log(`   await factory.createLazyMint(`);
    console.log(`     factory.NO_PROJECT_ID(), // Use constant for no project ID`);
    console.log(`     "My New Project",`);
    console.log(`     "ipfs://your-metadata-cid",`);
    console.log(`     1000, // maxSupply`);
    console.log(`     Math.floor(Date.now()/1000), // claimStart (now)`);
    console.log(`     Math.floor(Date.now()/1000) + 2592000, // claimEnd (30 days)`);
    console.log(`     Math.floor(Date.now()/1000) + 5184000, // redeemExpiration (60 days)`);
    console.log(`     ethers.utils.parseEther("0.1"), // lockedBudget`);
    console.log(`     "0x0000000000000000000000000000000000000000" // currencyAddress`);
    console.log(`   )`);
    console.log("\n3. Create a coupon under existing project:");
    console.log(`   const projectId = await factory.createProject("My Project");`);
    console.log(`   await factory.createLazyMint(`);
    console.log(`     projectId,`);
    console.log(`     "", // Ignored when using existing project`);
    console.log(`     "ipfs://your-metadata-cid",`);
    console.log(`     1000, // Rest of parameters same as above`);
    console.log(`     ...`);
    console.log(`   )`);
  } catch (error) {
    console.error("Error during deployment:", error);
    process.exit(1);
  }
}

function saveDeploymentInfo(network, info) {
  // Create directory if doesn't exist
  const deploymentDir = path.join(__dirname, "../deployments");
  if (!fs.existsSync(deploymentDir)) {
    fs.mkdirSync(deploymentDir);
  }
  
  // Create network directory if doesn't exist
  const networkDir = path.join(deploymentDir, network);
  if (!fs.existsSync(networkDir)) {
    fs.mkdirSync(networkDir);
  }
  
  // Write to file
  const filePath = path.join(networkDir, "TokenFactory.json");
  fs.writeFileSync(filePath, JSON.stringify(info, null, 2));
  console.log(`Deployment info saved to ${filePath}`);
}

// Handle errors
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 