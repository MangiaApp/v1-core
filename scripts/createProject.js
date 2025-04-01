const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  // Get project name from command line arguments
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error("Please provide a project name as a command line argument");
    console.log("Usage: npx hardhat run scripts/createProject.js --network <network> \"Project Name\"");
    process.exit(1);
  }

  const projectName = args[0]; // First argument is the project name
  
  try {
    // Get the LazyMintFactory contract factory
    const LazyMintFactory = await ethers.getContractFactory("LazyMintFactory");
    
    // Use existing factory instead of deploying
    console.log("Using existing LazyMintFactory...");
    const factory = LazyMintFactory.attach("0x4ED099ab3fd90CE6607C4412afa7F6f1645A63fD");
    console.log("LazyMintFactory address:", factory.address);

    // Create a new project
    console.log(`Creating new project: "${projectName}"...`);
    const tx = await factory.createProject(projectName);

    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    
    // Get the project ID from the event
    const event = receipt.events.find(e => e.event === 'ProjectCreated');
    const projectId = event.args.projectId;

    console.log(`Project "${projectName}" created with ID: ${projectId}`);
    console.log("\nProject Details:");
    console.log("- ID:", projectId.toString());
    console.log("- Name:", projectName);
    console.log("- Owner:", event.args.owner);
    
    console.log("\nTo add coupons to this project, use the createCouponInProject.js script with this ID.");
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 