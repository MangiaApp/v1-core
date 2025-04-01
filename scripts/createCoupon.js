const { ethers } = require("hardhat");
const pinataSDK = require("@pinata/sdk");
require("dotenv").config();

async function main() {
  // Initialize Pinata SDK
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

  // Calculate dates for metadata
  const currentDate = Math.floor(Date.now() / 1000);
  const claimStartDate = currentDate;
  const claimExpiration = currentDate + 30 * 24 * 60 * 60; // 30 days from now
  const redeemExpiration = currentDate + 60 * 24 * 60 * 60; // 60 days from now

  // Upload coupon metadata to Pinata
  console.log("Uploading coupon metadata to Pinata...");
  
  const couponMetadata = {
    name: "Sample Coupon 1",
    description: "This is a sample coupon for demonstration purposes only",
    image: "https://example.com/coupon-image.png",
    backgroundColor: "#FFFFFF",
    textColor: "#000000",
    visibility: "public", // public or private
    category: "Discount",
    location: {
      address1: "Sainz De Baranda",
      address2: "",
      formattedAddress: "Sainz De Baranda, Retiro, Madrid, Spain",
      city: "Madrid",
      region: "",
      postalCode: "",
      country: "Spain",
      lat: 40.4148563,
      lng: -3.6697064
    },
    claimStartDate: claimStartDate,
    claimExpirationDate: claimExpiration,
    couponExpirationDate: redeemExpiration,
    attributes: [
      {
        trait_type: "Discount",
        value: "20%"
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
      },
      {
        trait_type: "Visibility",
        value: "public"
      },
      {
        trait_type: "Category",
        value: "Discount"
      },
      {
        trait_type: "Location",
        value: "Madrid, Spain"
      }
    ]
  };

  try {
    const upload = await pinata.pinJSONToIPFS(couponMetadata);
    console.log("Metadata uploaded to Pinata:", upload);
    
    // Get the CID from the upload response
    const cid = upload.IpfsHash;
    
    // Format the IPFS URI using the CID
    const uri = `ipfs://${cid}`;
    console.log("IPFS URI:", uri);

    // Get the LazyMintFactory contract factory
    const LazyMintFactory = await ethers.getContractFactory("LazyMintFactory");
    
    // Use existing factory instead of deploying
    console.log("Using existing LazyMintFactory...");
    const factory = LazyMintFactory.attach("0x4ED099ab3fd90CE6607C4412afa7F6f1645A63fD");
    console.log("LazyMintFactory address:", factory.address);

    // Parameters for creating a new coupon
    const maxSupply = 1000; // Maximum number of coupons that can be minted
    const currencyAddress = "0x0000000000000000000000000000000000000000"; // Using ETH as currency
    
    // Project parameters
    // Use the NO_PROJECT_ID constant to create a new project
    const NO_PROJECT_ID = await factory.NO_PROJECT_ID();
    const projectId = NO_PROJECT_ID; // This will create a new project
    const projectName = "Sample Project"; // Only used if creating a new project

    // Create a new LazyMint contract through the factory
    console.log("Creating new LazyMint contract...");
    const tx = await factory.createLazyMint(
      projectId,        // Project ID (or NO_PROJECT_ID to create a new one)
      projectName,      // Project name (only used if creating a new project)
      uri,              // IPFS URI for metadata
      maxSupply,        // Maximum number of coupons
      claimStartDate,   // When users can start claiming the coupon
      claimExpiration,  // When claiming expires
      redeemExpiration, // When redeeming expires
      0,                // No initial locked budget
      currencyAddress   // Currency address (ETH = zero address)
    );

    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    
    // Get the LazyMint contract address from the event
    const event = receipt.events.find(e => e.event === 'LazyMintDeployed');
    const lazyMintAddress = event.args.lazyMintAddress;
    const actualProjectId = event.args.projectId;

    console.log("LazyMint contract created at:", lazyMintAddress);
    console.log("\nCoupon Details:");
    console.log("- Project ID:", actualProjectId.toString());
    console.log("- Project Name:", projectName);
    console.log("- URI:", uri);
    console.log("- CID:", cid);
    console.log("- Max Supply:", maxSupply);
    console.log("- Claim Start Date:", new Date(claimStartDate * 1000).toLocaleString());
    console.log("- Claim Expiration:", new Date(claimExpiration * 1000).toLocaleString());
    console.log("- Redeem Expiration:", new Date(redeemExpiration * 1000).toLocaleString());
    console.log("- Location:", couponMetadata.location.formattedAddress);
    console.log("- Fee per coupon:", "0.001 ETH"); // Fee is set to 1000 wei in the factory
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
