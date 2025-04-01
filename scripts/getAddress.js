const { ethers } = require("hardhat");

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("Address:", signer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 