const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  try {
    // Get the LazyMintFactory contract factory
    const LazyMintFactory = await ethers.getContractFactory("LazyMintFactory");
    
    // Use existing factory
    console.log("Using existing LazyMintFactory...");
    const factory = LazyMintFactory.attach("0x4ED099ab3fd90CE6607C4412afa7F6f1645A63fD");
    console.log("LazyMintFactory address:", factory.address);

    // Get total number of projects
    const projectCount = await factory.projectCount();
    console.log(`\nTotal projects: ${projectCount}\n`);

    // Get optional argument for detailed output
    const args = process.argv.slice(2);
    const showCoupons = args.length > 0 && args[0].toLowerCase() === 'detailed';

    // List all projects
    if (projectCount == 0) {
      console.log("No projects found.");
      return;
    }

    for (let i = 0; i < projectCount; i++) {
      const project = await factory.projects(i);
      
      console.log(`Project #${i}`);
      console.log(`- Name: ${project.name}`);
      console.log(`- Owner: ${project.owner}`);
      console.log(`- Created At: ${new Date(project.createdAt.toNumber() * 1000).toLocaleString()}`);
      
      if (showCoupons) {
        // Get coupons for this project
        const coupons = await factory.getProjectCoupons(i);
        console.log(`- Coupons (${coupons.length}):`);
        
        if (coupons.length === 0) {
          console.log("  No coupons in this project");
        } else {
          for (let j = 0; j < coupons.length; j++) {
            const couponAddress = coupons[j];
            const LazyMint = await ethers.getContractFactory("LazyMint");
            const coupon = LazyMint.attach(couponAddress);
            
            try {
              // Get basic info from the coupon
              const uri = await coupon.uri(0);
              const maxSupply = await coupon.maxSupply();
              const claimed = await coupon.totalClaimed();
              const claimExpiration = await coupon.claimExpiration();
              const redeemExpiration = await coupon.redeemExpiration();
              
              console.log(`  Coupon #${j}:`);
              console.log(`  - Address: ${couponAddress}`);
              console.log(`  - URI: ${uri}`);
              console.log(`  - Max Supply: ${maxSupply}`);
              console.log(`  - Claimed: ${claimed} / ${maxSupply}`);
              console.log(`  - Claim Expiration: ${new Date(claimExpiration.toNumber() * 1000).toLocaleString()}`);
              console.log(`  - Redeem Expiration: ${new Date(redeemExpiration.toNumber() * 1000).toLocaleString()}`);
            } catch (error) {
              console.log(`  Coupon #${j}: ${couponAddress} (Error retrieving details)`);
            }
          }
        }
      } else {
        const coupons = await factory.getProjectCoupons(i);
        console.log(`- Coupons: ${coupons.length}`);
      }
      
      console.log();
    }

    console.log("Usage:");
    console.log("- To see project details with coupons: npx hardhat run scripts/listProjects.js --network <network> detailed");
    console.log("- To create a new project: npx hardhat run scripts/createProject.js --network <network> \"Project Name\"");
    console.log("- To create a coupon in a project: npx hardhat run scripts/createCouponInProject.js --network <network> <projectId>");
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 