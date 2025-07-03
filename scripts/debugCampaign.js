const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting campaign creation debugging...");

  try {
    // Get network and signers
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Debug account: ${deployer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

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

    // Test 1: Check if the factory contract exists and is accessible
    console.log("\n=== Test 1: Factory Contract Check ===");
    const factoryCode = await ethers.provider.getCode(factoryAddress);
    if (factoryCode === "0x") {
      console.error("❌ Factory contract not found at address");
      process.exit(1);
    }
    console.log("✅ Factory contract exists");

    // Test 2: Connect to factory and check basic functions
    console.log("\n=== Test 2: Factory Connection Test ===");
    const MangiaCampaignFactory = await ethers.getContractFactory("MangiaCampaignFactory");
    const factory = MangiaCampaignFactory.attach(factoryAddress);

    try {
      const totalCampaigns = await factory.getTotalCampaignCount();
      console.log(`✅ Factory is accessible. Total campaigns: ${totalCampaigns}`);
    } catch (error) {
      console.error("❌ Factory connection failed:", error.message);
      process.exit(1);
    }

    // Test 3: Try to deploy MangiaCampaign1155 directly (to test if it's a deployment issue)
    console.log("\n=== Test 3: Direct Campaign Contract Deployment ===");
    try {
      const MangiaCampaign1155 = await ethers.getContractFactory("MangiaCampaign1155");
      
      const contractURI = "ipfs://bafkreidkftqrspl5n5ru26ma5i5tz5pfbxtpi4aoawhnl6kou4f3c3ivym";
      
      // Estimate gas for direct deployment
      const deployTx = MangiaCampaign1155.getDeployTransaction(contractURI, deployer.address);
      const gasEstimate = await ethers.provider.estimateGas(deployTx);
      console.log(`✅ Direct deployment gas estimate: ${gasEstimate.toString()}`);
      
      // Check if we have enough ETH for deployment
      const gasPrice = await ethers.provider.getGasPrice();
      const requiredETH = gasEstimate.mul(gasPrice);
      console.log(`Required ETH for deployment: ${ethers.utils.formatEther(requiredETH)} ETH`);
      
      if (balance.lt(requiredETH)) {
        console.log("⚠️  Insufficient ETH for deployment");
        console.log(`Need: ${ethers.utils.formatEther(requiredETH)} ETH`);
        console.log(`Have: ${ethers.utils.formatEther(balance)} ETH`);
      } else {
        console.log("✅ Sufficient ETH for deployment");
      }
      
    } catch (error) {
      console.error("❌ Direct deployment test failed:", error.message);
      
      // If this is a compilation issue
      if (error.message.includes("not found") || error.message.includes("compile")) {
        console.log("This might be a compilation issue. Try running: npx hardhat compile");
      }
    }

    // Test 4: Test factory createCampaign with minimal parameters
    console.log("\n=== Test 4: Factory createCampaign Test ===");
    
    const campaignData = {
      contractURI: "ipfs://test1",
      initialCampaignURI: "ipfs://test2", 
      totalBudgetInCredits: 100,
      minCreditsPerParticipant: 10,
      expirationTimestamp: Math.floor(Date.now() / 1000) + 3600 // 1 hour from now
    };

    try {
      // Try with minimal gas to see specific error
      console.log("Testing with minimal parameters...");
      
      // First try to call the function statically to see if it would work
      const result = await factory.callStatic.createCampaign(
        campaignData.contractURI,
        campaignData.initialCampaignURI,
        campaignData.totalBudgetInCredits,
        campaignData.minCreditsPerParticipant,
        campaignData.expirationTimestamp
      );
      
      console.log(`✅ Static call successful. Would return address: ${result}`);
      
      // Now try actual gas estimation
      const gasEstimate = await factory.estimateGas.createCampaign(
        campaignData.contractURI,
        campaignData.initialCampaignURI,
        campaignData.totalBudgetInCredits,
        campaignData.minCreditsPerParticipant,
        campaignData.expirationTimestamp
      );
      
      console.log(`✅ Gas estimation successful: ${gasEstimate.toString()}`);
      
    } catch (error) {
      console.error("❌ Factory createCampaign test failed:");
      console.error("Error message:", error.message);
      
      // Try to decode the error
      if (error.data) {
        console.log("Error data:", error.data);
        
        // Common error signatures
        const errorSignatures = {
          "0x08c379a0": "Error(string)", // Standard revert with message
          "0x4e487b71": "Panic(uint256)", // Panic errors
          "0x118cdaa7": "Unknown custom error" // The specific error we're seeing
        };
        
        const errorSig = error.data.substring(0, 10);
        if (errorSignatures[errorSig]) {
          console.log(`Error type: ${errorSignatures[errorSig]}`);
          
          if (errorSig === "0x08c379a0") {
            // Try to decode the error message
            try {
              const decoded = ethers.utils.defaultAbiCoder.decode(["string"], "0x" + error.data.substring(10));
              console.log(`Decoded error message: ${decoded[0]}`);
            } catch (e) {
              console.log("Could not decode error message");
            }
          }
        }
      }
      
      // Check for common issues
      if (error.message.includes("execution reverted")) {
        console.log("\n🔍 Possible causes:");
        console.log("1. Insufficient ETH balance for gas");
        console.log("2. Contract deployment size limit exceeded");
        console.log("3. Missing dependencies or imports");
        console.log("4. Invalid constructor parameters");
        console.log("5. Custom error in contract logic");
      }
    }

    // Test 5: Check OpenZeppelin imports
    console.log("\n=== Test 5: Dependency Check ===");
    try {
      const ERC1155 = await ethers.getContractFactory("@openzeppelin/contracts/token/ERC1155/ERC1155.sol:ERC1155");
      console.log("✅ OpenZeppelin ERC1155 found");
    } catch (error) {
      console.log("⚠️  OpenZeppelin contracts might not be properly installed");
      console.log("Try running: npm install @openzeppelin/contracts");
    }

    console.log("\n=== Debug Summary ===");
    console.log("If the direct deployment test passed but factory test failed,");
    console.log("the issue is likely in the factory contract logic or gas estimation.");
    console.log("If the direct deployment test failed, check compilation and dependencies.");
    
  } catch (error) {
    console.error("Debug script error:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 