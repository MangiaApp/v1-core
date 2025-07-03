const { ethers } = require("hardhat");

async function main() {
  console.log("Updating project metadata...");

  try {
    // Get the network
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log(`Using account: ${signer.address}`);
    
    // Check balance
    const balance = await ethers.provider.getBalance(signer.address);
    console.log(`Account balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Project contract address
    const projectAddress = "0xA0452b00a4875AA760F45398ddcAe43a6b52Dd0b";
    console.log(`Project contract address: ${projectAddress}`);

    // Connect to the project contract
    const Coupon = await ethers.getContractFactory("Coupon");
    const project = Coupon.attach(projectAddress);

    // Get current project information
    const currentMetadataURI = await project.projectMetadataURI();
    const owner = await project.owner();

    console.log(`\nCurrent Project Information:`);
    console.log(`- Owner: ${owner}`);
    console.log(`- Current Metadata URI: ${currentMetadataURI}`);

    // Check if signer is the owner
    if (signer.address.toLowerCase() !== owner.toLowerCase()) {
      console.error(`Error: Only the project owner can update metadata. Owner: ${owner}, Signer: ${signer.address}`);
      process.exit(1);
    }

    // New project metadata structure (this should be uploaded to IPFS)
    const updatedProjectMetadata = {
      "name": "TacoLoco Barcelona",
      "description": "Mexican street food with a modern twist, now serving the best tacos in Barcelona!",
      "logo": "ipfs://QmNewExampleLogoCID/tacoloco-updated-logo.png",
      "websiteUrl": "https://tacoloco.barcelona",
      "instagramUrl": "https://instagram.com/tacolocobarcelona",
      "tiktokUrl": "https://tiktok.com/@tacolocobarcelona",
      "city": "Barcelona",
      "country": "Spain",
      "locationAddress": "Carrer de Blai, 25, 08004 Barcelona (NEW LOCATION!)"
    };

    // TODO: Upload updatedProjectMetadata to IPFS and get the URI
    // For this example, using a placeholder URI
    const newProjectMetadataURI = "ipfs://bafkreiupdatedprojectmetadatacid987654321";
    
    console.log("\nUpdated Project Metadata JSON structure:");
    console.log(JSON.stringify(updatedProjectMetadata, null, 2));
    console.log(`\nNew Project Metadata URI: ${newProjectMetadataURI}`);
    console.log("NOTE: In production, upload the updated metadata JSON to IPFS first");

    // Estimate gas
    const gasEstimate = await project.estimateGas.updateProjectMetadata(
      newProjectMetadataURI
    );
    
    console.log(`Estimated gas: ${gasEstimate.toString()}`);

    // Update the project metadata
    const tx = await project.updateProjectMetadata(
      newProjectMetadataURI,
      {
        gasLimit: gasEstimate.mul(120).div(100), // Add 20% buffer
      }
    );

    console.log(`Transaction sent: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Verify the update
    const updatedMetadataURI = await project.projectMetadataURI();

    console.log(`\n===== Project Metadata Updated Successfully =====`);
    console.log(`Previous URI: ${currentMetadataURI}`);
    console.log(`New URI: ${updatedMetadataURI}`);
    console.log(`\nTo get the updated project details, fetch the JSON from: ${updatedMetadataURI}`);
    
    // Show what the metadata structure should contain
    console.log(`\nThe metadata JSON should contain:`);
    console.log(`- name: Business/Project name`);
    console.log(`- description: Business description`);
    console.log(`- logo: IPFS URI to logo image`);
    console.log(`- websiteUrl: Business website`);
    console.log(`- instagramUrl: Instagram profile`);
    console.log(`- tiktokUrl: TikTok profile`);
    console.log(`- city: Business city`);
    console.log(`- country: Business country`);
    console.log(`- locationAddress: Full business address`);
    
  } catch (error) {
    console.error("Error updating project metadata:", error);
    process.exit(1);
  }
}

// Execute the main function
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 