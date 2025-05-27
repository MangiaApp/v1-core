const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting 2 arepa coupon creation...");

  try {
    // Get network and signers
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    const [deployer] = await ethers.getSigners();
    console.log(`Creating coupon with account: ${deployer.address}`);
    
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
        factoryAddress = deploymentInfo["TokenFactoryModule#TokenFactory"];
        console.log(`Loaded factory address from ignition deployments: ${factoryAddress}`);
      } else {
        throw new Error("Ignition deployment info not found");
      }
    } catch (error) {
      // Fallback to environment variable
      console.log(`Error loading from ignition deployments: ${error.message}`);
      factoryAddress = process.env.FACTORY_ADDRESS;
      
      if (!factoryAddress) {
        console.error("Failed to get factory address from deployments and no FACTORY_ADDRESS environment variable set");
        process.exit(1);
      }
      
      console.log(`Using factory address from environment: ${factoryAddress}`);
    }

    // Connect to the factory contract
    const TokenFactory = await ethers.getContractFactory("TokenFactory");
    const factory = TokenFactory.attach(factoryAddress);

    // Generate a random salt
    const salt = ethers.utils.randomBytes(32);

    // Coupon parameters for "2 arepa"
    const couponData = {
      name: "2 arepa",
      description: "",
      image: "ipfs://bafkreidkftqrspl5n5ru26ma5i5tz5pfbxtpi4aoawhnl6kou4f3c3ivym",
      promoVideo: "ipfs://bafybeid4djduj36xsco6ic4pit3lvk2m73cuz3cd3rxgzr6jsepvsot7yu",
      backgroundColor: "#FFD700",
      textColor: "#ffffff",
      visibility: "public",
      category: "Discount",
      location: {
        address1: "Carrer de la Diputació, 340",
        address2: "",
        formattedAddress: "Carrer de la Diputació, 340, L'Eixample, 08009 Barcelona, Spain",
        city: "Barcelona",
        region: "",
        postalCode: "08009",
        country: "Spain",
        lat: 41.396187399999995,
        lng: 2.1750865999999998
      },
      claimStartDate: Math.floor(Date.now() / 1000), // Current timestamp for start claiming
      claimExpirationDate: 1750366287,
      couponExpirationDate: 1752958287,
      attributes: [
        { trait_type: "Coupon Type", value: "Discount" },
        { trait_type: "Claim Start", value: "5/20/2025, 10:51:27 PM" },
        { trait_type: "Claim Expiration", value: "6/19/2025, 10:51:27 PM" },
        { trait_type: "Coupon Expiration", value: "7/19/2025, 10:51:27 PM" }
      ]
    };

    // Use the existing IPFS URI for the image
    const uri = couponData.image;
    console.log(`Using metadata URI: ${uri}`);

    // Create a new project and coupon
    console.log("Creating new coupon with a new project...");
    
    // Get the NO_PROJECT_ID constant from the contract
    const NO_PROJECT_ID = await factory.NO_PROJECT_ID();
    
    const maxSupply = 1000; // Example max supply
    const claimStart = Math.floor(Date.now() / 1000); // Current time for start claiming
    const claimEnd = couponData.claimExpirationDate;
    const redeemExpiration = couponData.couponExpirationDate;
    const lockedBudget = ethers.utils.parseEther("0"); // No budget locked
    const currencyAddress = "0x0000000000000000000000000000000000000000"; // ETH address (zero address)
    const fee = 0; // No fee for redemption

    console.log(`Coupon Parameters:
    - Name: ${couponData.name}
    - Max Supply: ${maxSupply}
    - Claim Start: ${new Date(claimStart * 1000).toLocaleString()}
    - Claim End: ${new Date(claimEnd * 1000).toLocaleString()}
    - Redemption Expiration: ${new Date(redeemExpiration * 1000).toLocaleString()}
    `);

    // Estimate gas before transaction
    const gasEstimate = await factory.estimateGas.createLazyMint(
      NO_PROJECT_ID,
      couponData.name,
      uri,
      maxSupply,
      claimStart,
      claimEnd,
      redeemExpiration,
      lockedBudget,
      currencyAddress,
      fee,
      salt
    );
    
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Create the coupon
    const tx = await factory.createLazyMint(
      NO_PROJECT_ID,
      couponData.name,
      uri,
      maxSupply,
      claimStart,
      claimEnd,
      redeemExpiration,
      lockedBudget,
      currencyAddress,
      fee,
      salt,
      {
        gasLimit: gasEstimate.mul(120).div(100) // Add 20% buffer
      }
    );

    console.log(`Transaction sent: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    
    // Parse the event to get the coupon address
    const lazyMintDeployedEvent = receipt.events.find(e => e.event === "LazyMintDeployed");
    
    if (lazyMintDeployedEvent) {
      const couponAddress = lazyMintDeployedEvent.args.lazyMintAddress;
      const projectId = lazyMintDeployedEvent.args.projectId;
      
      console.log("\n===== Coupon Creation Complete =====");
      console.log(`Coupon address: ${couponAddress}`);
      console.log(`Project ID: ${projectId.toString()}`);
      console.log(`Claim period: ${new Date(claimStart * 1000).toLocaleString()} to ${new Date(claimEnd * 1000).toLocaleString()}`);
      console.log(`Redemption expiration: ${new Date(redeemExpiration * 1000).toLocaleString()}`);
      
      // Save coupon info to file
      saveCouponInfo(network.name, {
        address: couponAddress,
        projectId: projectId.toString(),
        name: couponData.name,
        creator: deployer.address,
        timestamp: new Date().toISOString(),
        maxSupply,
        claimStart,
        claimEnd,
        redeemExpiration,
        metadata: couponData
      });
    } else {
      console.error("Could not find LazyMintDeployed event in transaction receipt");
    }
    
  } catch (error) {
    console.error("Error during coupon creation:", error);
    process.exit(1);
  }
}

function saveCouponInfo(network, info) {
  // Create directory if doesn't exist
  const couponsDir = path.join(__dirname, "../coupons");
  if (!fs.existsSync(couponsDir)) {
    fs.mkdirSync(couponsDir);
  }
  
  // Create network directory if doesn't exist
  const networkDir = path.join(couponsDir, network);
  if (!fs.existsSync(networkDir)) {
    fs.mkdirSync(networkDir);
  }
  
  // Write to file
  const fileName = `coupon_${info.name.replace(/\s+/g, '_')}_${Date.now()}.json`;
  const filePath = path.join(networkDir, fileName);
  fs.writeFileSync(filePath, JSON.stringify(info, null, 2));
  console.log(`Coupon info saved to ${filePath}`);
}

// Execute the main function
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 