const { ethers, network } = require("hardhat");
const pinataSDK = require("@pinata/sdk");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

async function main() {
  try {
    // Initialize Pinata SDK for IPFS storage
    const pinata = new pinataSDK({
      pinataJWTKey: process.env.PINATA_JWT,
    });

    // Test authentication
    try {
      const authTest = await pinata.testAuthentication();
      console.log("Pinata authentication successful:", authTest);
    } catch (error) {
      console.error("Pinata authentication failed:", error);
      process.exit(1);
    }

    console.log(`Network: ${network.name}, ChainId: ${network.config.chainId}`);

    // Load deployment info
    const deploymentPath = path.join(__dirname, "../deployments", network.name, "LazyMintFactory.json");
    let factoryAddress;
    
    try {
      if (fs.existsSync(deploymentPath)) {
        const deploymentInfo = JSON.parse(fs.readFileSync(deploymentPath));
        factoryAddress = deploymentInfo.LazyMintFactoryOptimized;
        console.log(`Found LazyMintFactoryOptimized at ${factoryAddress}`);
      } else {
        // Fallback address or prompt for input
        factoryAddress = process.env.FACTORY_ADDRESS || "0x11E7d1659f54DE21D0826105180ff3d574AE30AD";
        console.log(`No deployment info found. Using address from environment: ${factoryAddress}`);
      }
    } catch (error) {
      console.error("Error loading deployment info:", error);
      process.exit(1);
    }

    // Connect to the LazyMintFactoryOptimized contract
    const LazyMintFactory = await ethers.getContractFactory("LazyMintFactoryOptimized");
    const factory = LazyMintFactory.attach(factoryAddress);

    // Project Information
    const projectName = process.env.PROJECT_NAME || "Demo Project";
    console.log(`Creating project: ${projectName}`);

    // Create a project
    const createProjectTx = await factory.createProject(projectName);
    const createProjectReceipt = await createProjectTx.wait();
    
    // Extract project ID from event
    const projectCreatedEvent = createProjectReceipt.events.find(
      (event) => event.event === "ProjectCreated"
    );
    const projectId = projectCreatedEvent.args.projectId;
    console.log(`Project created with ID: ${projectId}`);

    // Calculate dates for metadata
    const currentDate = Math.floor(Date.now() / 1000);
    const claimStartDate = currentDate;
    const claimExpiration = currentDate + 30 * 24 * 60 * 60; // 30 days from now
    const redeemExpiration = currentDate + 60 * 24 * 60 * 60; // 60 days from now

    // Create metadata for the coupon
    const couponName = process.env.COUPON_NAME || "Demo Coupon";
    const couponDescription = process.env.COUPON_DESCRIPTION || "This is a sample coupon for the demo project";
    
    const couponMetadata = {
      name: couponName,
      description: couponDescription,
      image: process.env.COUPON_IMAGE || "https://example.com/coupon-image.png",
      backgroundColor: "#FFFFFF",
      textColor: "#000000",
      visibility: "public",
      category: "Discount",
      location: {
        address1: "Example Address",
        address2: "",
        formattedAddress: "Example Street, Example City",
        city: "Example City",
        region: "",
        postalCode: "",
        country: "Example Country",
        lat: 0,
        lng: 0
      },
      claimStartDate: claimStartDate,
      claimExpirationDate: claimExpiration,
      couponExpirationDate: redeemExpiration,
      attributes: [
        {
          trait_type: "Coupon Type",
          value: "Demo"
        },
        {
          trait_type: "Claim Start",
          value: new Date(claimStartDate * 1000).toLocaleString()
        },
        {
          trait_type: "Claim Expiration",
          value: new Date(claimExpiration * 1000).toLocaleString()
        },
        {
          trait_type: "Coupon Expiration",
          value: new Date(redeemExpiration * 1000).toLocaleString()
        }
      ]
    };

    // Upload metadata to IPFS
    console.log("Uploading coupon metadata to IPFS...");
    const upload = await pinata.pinJSONToIPFS(couponMetadata);
    console.log("Metadata uploaded to Pinata:", upload);
    
    // Get the CID from the upload response
    const cid = upload.IpfsHash;
    
    // Format the IPFS URI using the CID
    const uri = `ipfs://${cid}`;
    console.log("IPFS URI:", uri);

    // Parameters for creating a coupon
    const maxSupply = process.env.MAX_SUPPLY || 1000;
    const lockedBudget = process.env.LOCKED_BUDGET || 0;
    const currencyAddress = process.env.CURRENCY_ADDRESS || "0x0000000000000000000000000000000000000000"; // Using ETH as currency

    // Create the coupon using the LazyMint contract
    console.log(`Creating coupon under project ${projectId}...`);
    const createCouponTx = await factory.createLazyMint(
      projectId,
      "", // Project name not needed since using existing project ID
      uri,
      maxSupply,
      claimStartDate,
      claimExpiration,
      redeemExpiration,
      lockedBudget,
      currencyAddress
    );
    
    // Wait for the transaction to be mined
    const createCouponReceipt = await createCouponTx.wait();
    
    // Get the LazyMint contract address from the event
    const lazyMintDeployedEvent = createCouponReceipt.events.find(
      (event) => event.event === "LazyMintDeployed"
    );
    const lazyMintAddress = lazyMintDeployedEvent.args.lazyMintAddress;

    console.log("===== Process Complete =====");
    console.log("Project Details:");
    console.log(`- ID: ${projectId}`);
    console.log(`- Name: ${projectName}`);
    console.log("\nCoupon Details:");
    console.log(`- Address: ${lazyMintAddress}`);
    console.log(`- Name: ${couponName}`);
    console.log(`- URI: ${uri}`);
    console.log(`- CID: ${cid}`);
    console.log(`- Max Supply: ${maxSupply}`);
    console.log(`- Claim Expiration: ${new Date(claimExpiration * 1000).toLocaleString()}`);
    console.log(`- Redeem Expiration: ${new Date(redeemExpiration * 1000).toLocaleString()}`);
    
    // Save created project/coupon info
    const outputInfo = {
      projectId: projectId.toString(),
      projectName,
      couponAddress: lazyMintAddress,
      couponName,
      uri,
      cid,
      maxSupply: maxSupply.toString(),
      claimExpiration: claimExpiration.toString(),
      redeemExpiration: redeemExpiration.toString(),
      createdAt: new Date().toISOString(),
      network: network.name,
      chainId: network.config.chainId?.toString() || "unknown"
    };
    
    // Create output directory
    const outputDir = path.join(__dirname, "../created");
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir);
    }
    
    // Save output
    const outputPath = path.join(outputDir, `project_${projectId}_${Date.now()}.json`);
    fs.writeFileSync(outputPath, JSON.stringify(outputInfo, null, 2));
    console.log(`\nProject and coupon information saved to ${outputPath}`);
    
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 