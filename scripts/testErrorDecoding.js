const { ethers } = require("hardhat");

async function main() {
  console.log("Testing error code 0x118cdaa7...");

  // The error data from the debug output
  const errorData = "0x118cdaa70000000000000000000000001686bec98221f77c58f13e5af430a512cf15f1dc";
  
  // Split into signature and data
  const errorSignature = errorData.substring(0, 10); // 0x118cdaa7
  const encodedAddress = errorData.substring(10); // The rest
  
  console.log(`Error signature: ${errorSignature}`);
  console.log(`Encoded data: ${encodedAddress}`);
  
  // Decode the address parameter
  try {
    const decodedAddress = ethers.utils.defaultAbiCoder.decode(["address"], "0x" + encodedAddress);
    console.log(`Decoded address: ${decodedAddress[0]}`);
    
    // Check if this is the factory address
    const factoryAddress = "0x1686BEC98221F77C58F13e5AF430A512cF15f1dC";
    console.log(`Factory address: ${factoryAddress}`);
    console.log(`Addresses match: ${decodedAddress[0].toLowerCase() === factoryAddress.toLowerCase()}`);
    
  } catch (error) {
    console.error("Failed to decode address:", error.message);
  }
  
  // Let's check common OpenZeppelin v5 error signatures
  const commonErrors = {
    "OwnableUnauthorizedAccount(address)": ethers.utils.id("OwnableUnauthorizedAccount(address)").substring(0, 10),
    "OwnableInvalidOwner(address)": ethers.utils.id("OwnableInvalidOwner(address)").substring(0, 10),
    "AddressEmptyCode(address)": ethers.utils.id("AddressEmptyCode(address)").substring(0, 10),
    "FailedInnerCall()": ethers.utils.id("FailedInnerCall()").substring(0, 10),
  };
  
  console.log("\nCommon OpenZeppelin v5 error signatures:");
  for (const [errorName, signature] of Object.entries(commonErrors)) {
    console.log(`${errorName}: ${signature}`);
    if (signature === errorSignature) {
      console.log(`🎯 MATCH! The error is: ${errorName}`);
    }
  }
  
  // Let's also check what happens if we calculate custom error signatures
  console.log("\nCalculating custom error signature for 0x118cdaa7...");
  
  // If it's OwnableUnauthorizedAccount, let's see what it means
  if (errorSignature === ethers.utils.id("OwnableUnauthorizedAccount(address)").substring(0, 10)) {
    console.log("✅ This is an OwnableUnauthorizedAccount error!");
    console.log("This means someone tried to call an onlyOwner function but they're not the owner.");
    console.log(`The address that tried to call: ${decodedAddress[0]}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 