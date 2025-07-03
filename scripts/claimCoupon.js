const { ethers } = require("hardhat");

async function main() {
  console.log("Starting coupon claim process...");

  try {
    // Get the network
    const network = await ethers.provider.getNetwork();
    console.log(`Network: ${network.name} (chainId: ${network.chainId})`);
    
    // Generate a random wallet
    const randomWallet = ethers.Wallet.createRandom();
    const signer = randomWallet.connect(ethers.provider);
    
    console.log(`Random wallet generated: ${signer.address}`);
    
    // Get signer with funds to transfer ETH to the random wallet
    const [fundingSigner] = await ethers.getSigners();
    console.log(`Funding account: ${fundingSigner.address}`);
    
    // Check balance of the funding account
    const fundingBalance = await ethers.provider.getBalance(fundingSigner.address);
    console.log(`Funding account balance: ${ethers.utils.formatEther(fundingBalance)} ETH`);

    // Project contract address (use the newly created project)
    const projectAddress = "0x9ED89735e67Ef546Eb22f5B69767edD6a65ACbDB";
    const tokenId = 0; // Claiming tokenId 0 (first coupon in the project)
    console.log(`Project contract address: ${projectAddress}`);
    console.log(`Token ID to claim: ${tokenId}`);

    // Connect to the project contract
    const Coupon = await ethers.getContractFactory("Coupon");
    const project = Coupon.attach(projectAddress);

    // Get project information
    const projectMetadataURI = await project.projectMetadataURI();
    const totalCoupons = await project.getTotalCoupons();

    console.log(`\nProject Information:`);
    console.log(`- Metadata URI: ${projectMetadataURI}`);
    console.log(`- Total coupons: ${totalCoupons.toString()}`);
    console.log(`- NOTE: To get the actual project metadata (name, description, etc.), fetch the JSON from: ${projectMetadataURI}`);

    // Get specific token data
    const tokenData = await project.getTokenData(tokenId);
    const tokenUri = await project.uri(tokenId);

    console.log(`\nCoupon Information (Token ID ${tokenId}):`);
    console.log(`- Total Supply: ${tokenData.totalSupply.toString()} / ${tokenData.maxSupply.toString()}`);
    console.log(`- Claim Start: ${new Date(tokenData.claimStart.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Claim End: ${new Date(tokenData.claimEnd.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Redemption Expiration: ${new Date(tokenData.redeemExpiration.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Metadata URI: ${tokenUri}`);
    console.log(`- Fee: ${ethers.utils.formatEther(tokenData.fee)} ETH`);
    console.log(`- Locked Budget: ${ethers.utils.formatEther(tokenData.lockedBudget)} ETH`);

    // Check if the random wallet already has claimed this token
    const userBalance = await project.balanceOf(signer.address, tokenId);
    
    if (userBalance.gt(0)) {
      console.log(`\nThis wallet already claimed this coupon! Current balance: ${userBalance.toString()}`);
      process.exit(0);
    }

    // Calculate gas needed for the claim operation
    const gasPrice = await ethers.provider.getGasPrice();
    const lowerGasPrice = gasPrice.mul(90).div(100); // 90% of current gas price
    
    // Estimate gas for customClaim operation
    const estimatedGas = await project.connect(fundingSigner).estimateGas.customClaim(
      tokenId,
      ethers.constants.AddressZero, // No affiliate
      { from: fundingSigner.address }
    ).catch(() => ethers.BigNumber.from(300000)); // Safe value if estimation fails
    
    console.log(`Estimated gas for claim: ${estimatedGas.toString()}`);
    
    // Add 15% safety margin
    const safeGasLimit = estimatedGas.mul(115).div(100);
    
    // Calculate ETH needed for gas
    const gasCost = safeGasLimit.mul(lowerGasPrice);
    
    // Add gas cost for the transfer itself
    const transferGasEstimate = await ethers.provider.estimateGas({
      to: signer.address,
      value: gasCost
    }).catch(() => ethers.BigNumber.from(21000));
    
    const transferCost = transferGasEstimate.mul(lowerGasPrice);
    
    // Total amount to send: gas cost for claim + transfer cost
    const totalAmountToSend = gasCost.add(transferCost);
    
    console.log(`Gas cost for claim: ${ethers.utils.formatEther(gasCost)} ETH`);
    console.log(`Gas cost for transfer: ${ethers.utils.formatEther(transferCost)} ETH`);
    console.log(`Total to transfer: ${ethers.utils.formatEther(totalAmountToSend)} ETH`);
    
    // Check if we have enough funds
    if (fundingBalance.lt(totalAmountToSend.add(transferCost))) {
      console.error("Insufficient funds for transfer and claim");
      process.exit(1);
    }
    
    // Transfer exact amount needed to the random wallet
    console.log(`Transferring ${ethers.utils.formatEther(totalAmountToSend)} ETH to random wallet...`);
    
    const fundTx = await fundingSigner.sendTransaction({
      to: signer.address,
      value: totalAmountToSend,
      gasLimit: transferGasEstimate.mul(110).div(100), // 10% margin
      gasPrice: lowerGasPrice
    });
    
    await fundTx.wait();
    
    // Check balance of the random wallet
    const balance = await ethers.provider.getBalance(signer.address);
    console.log(`Random wallet balance: ${ethers.utils.formatEther(balance)} ETH`);

    // Connect to the project contract with the random wallet
    const projectWithSigner = project.connect(signer);

    // Optionally use an affiliate for the claim
    const affiliateAddress = ethers.constants.AddressZero; // No affiliate for this example
    
    console.log(`\nClaiming coupon...`);
    console.log(`- Token ID: ${tokenId}`);
    console.log(`- Affiliate address: ${affiliateAddress === ethers.constants.AddressZero ? "None" : affiliateAddress}`);

    // Perform the claim with calculated gas parameters
    const tx = await projectWithSigner.customClaim(tokenId, affiliateAddress, {
      gasLimit: safeGasLimit,
      gasPrice: lowerGasPrice
    });

    console.log(`Transaction sent: ${tx.hash}`);
    console.log("Waiting for transaction confirmation...");
    
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);

    // Check the new balance of the random wallet
    const newUserBalance = await projectWithSigner.balanceOf(signer.address, tokenId);
    
    console.log(`\nCoupon claimed successfully!`);
    console.log(`New coupon balance: ${newUserBalance.toString()}`);
    console.log(`Wallet used: ${signer.address}`);
    console.log(`Private key (save securely): ${randomWallet.privateKey}`);
    
  } catch (error) {
    console.error("Error during coupon claim:", error);
    process.exit(1);
  }
}

// Execute the main function
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 