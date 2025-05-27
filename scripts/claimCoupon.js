const { ethers } = require("hardhat");

async function main() {
  console.log("Iniciando proceso de reclamación de cupón...");

  try {
    // Obtener la red
    const network = await ethers.provider.getNetwork();
    console.log(`Red: ${network.name} (chainId: ${network.chainId})`);
    
    // Generar una billetera aleatoria
    const randomWallet = ethers.Wallet.createRandom();
    const signer = randomWallet.connect(ethers.provider);
    
    console.log(`Wallet aleatoria generada: ${signer.address}`);
    
    // Obtener signer con fondos para transferir ETH a la wallet aleatoria
    const [fundingSigner] = await ethers.getSigners();
    console.log(`Cuenta con fondos: ${fundingSigner.address}`);
    
    // Verificar balance de la cuenta con fondos
    const fundingBalance = await ethers.provider.getBalance(fundingSigner.address);
    console.log(`Balance de la cuenta con fondos: ${ethers.utils.formatEther(fundingBalance)} ETH`);

    // Dirección del contrato de cupón
    const couponAddress = "0x2226182958e9D3D15f7eB10652f820eBE3B14df2";
    console.log(`Dirección del contrato de cupón: ${couponAddress}`);

    // Conectar al contrato de cupón
    const Coupon = await ethers.getContractFactory("Coupon");
    const coupon = Coupon.attach(couponAddress);

    // Calcular el gas necesario para la operación de claim
    // Primero, obtenemos el precio de gas actual
    const gasPrice = await ethers.provider.getGasPrice();
    // Usamos un precio de gas ligeramente menor para ahorrar
    const lowerGasPrice = gasPrice.mul(90).div(100); // 90% del precio de gas actual
    
    // Estimamos cuánto gas necesitará la operación customClaim
    // Para esto, creamos una estimación simulada desde la cuenta con fondos
    const estimatedGas = await coupon.connect(fundingSigner).estimateGas.customClaim(
      ethers.constants.AddressZero, 
      { from: fundingSigner.address }
    ).catch(() => ethers.BigNumber.from(300000)); // valor seguro si falla la estimación
    
    console.log(`Gas estimado para claim: ${estimatedGas.toString()}`);
    
    // Añadimos un 15% de margen de seguridad
    const safeGasLimit = estimatedGas.mul(115).div(100);
    
    // Calculamos exactamente cuánto ETH necesitamos para el gas
    const gasCost = safeGasLimit.mul(lowerGasPrice);
    
    // Añadimos un pequeño margen para cubrir la transferencia misma
    const transferGasEstimate = await ethers.provider.estimateGas({
      to: signer.address,
      value: gasCost
    }).catch(() => ethers.BigNumber.from(21000)); // gas mínimo para una transferencia
    
    const transferCost = transferGasEstimate.mul(lowerGasPrice);
    
    // Total a transferir: coste de gas para claim + pequeño margen
    const totalAmountToSend = gasCost.add(transferCost);
    
    console.log(`Coste de gas para claim: ${ethers.utils.formatEther(gasCost)} ETH`);
    console.log(`Coste de gas para transferencia: ${ethers.utils.formatEther(transferCost)} ETH`);
    console.log(`Total a transferir: ${ethers.utils.formatEther(totalAmountToSend)} ETH`);
    
    // Verificamos que tengamos suficientes fondos
    if (fundingBalance.lt(totalAmountToSend.add(transferCost))) {
      console.error("Fondos insuficientes para la transferencia y el claim");
      process.exit(1);
    }
    
    // Transferir exactamente lo necesario a la wallet aleatoria
    console.log(`Transfiriendo ${ethers.utils.formatEther(totalAmountToSend)} ETH a la wallet aleatoria...`);
    
    const fundTx = await fundingSigner.sendTransaction({
      to: signer.address,
      value: totalAmountToSend,
      gasLimit: transferGasEstimate.mul(110).div(100), // 10% de margen
      gasPrice: lowerGasPrice
    });
    
    await fundTx.wait();
    
    // Verificar balance de la wallet aleatoria
    const balance = await ethers.provider.getBalance(signer.address);
    console.log(`Balance de la wallet aleatoria: ${ethers.utils.formatEther(balance)} ETH`);

    // Conectar al contrato de cupón con la wallet aleatoria
    const couponWithSigner = coupon.connect(signer);

    // Obtener información sobre el cupón
    const tokenId = await couponWithSigner.tokenId();
    const maxSupply = await couponWithSigner.maxSupply();
    const totalSupply = await couponWithSigner.totalSupply();
    const claimStart = await couponWithSigner.claimStart();
    const claimEnd = await couponWithSigner.claimEnd();
    const redeemExpiration = await couponWithSigner.redeemExpiration();
    const metadata = await couponWithSigner.uri(tokenId);

    console.log(`\nInformación del Cupón:`);
    console.log(`- Token ID: ${tokenId}`);
    console.log(`- Oferta Total: ${totalSupply.toString()} / ${maxSupply.toString()}`);
    console.log(`- Inicio de Reclamación: ${new Date(claimStart.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Fin de Reclamación: ${new Date(claimEnd.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Expiración de Redención: ${new Date(redeemExpiration.toNumber() * 1000).toLocaleString()}`);
    console.log(`- Metadata URI: ${metadata}`);

    // Verificar si la wallet aleatoria ya ha reclamado este cupón
    const userBalance = await couponWithSigner.balanceOf(signer.address, tokenId);
    
    if (userBalance.gt(0)) {
      console.log(`\n¡Esta wallet ya ha reclamado este cupón! Balance actual: ${userBalance.toString()}`);
      process.exit(0);
    }

    // Opcionalmente, usar un afiliado para la reclamación
    // Deja esta dirección en cero para reclamar sin afiliado
    const affiliateAddress = ethers.constants.AddressZero; // Puedes cambiarlo a una dirección de afiliado válida
    
    console.log(`\nReclamando cupón...`);
    console.log(`- Dirección de afiliado: ${affiliateAddress === ethers.constants.AddressZero ? "Ninguna" : affiliateAddress}`);

    // Realizar la reclamación con los parámetros de gas calculados previamente
    const tx = await couponWithSigner.customClaim(affiliateAddress, {
      gasLimit: safeGasLimit,
      gasPrice: lowerGasPrice
    });

    console.log(`Transacción enviada: ${tx.hash}`);
    console.log("Esperando confirmación de la transacción...");
    
    const receipt = await tx.wait();
    console.log(`Transacción confirmada en el bloque ${receipt.blockNumber}`);

    // Verificar el nuevo balance de la wallet aleatoria
    const newUserBalance = await couponWithSigner.balanceOf(signer.address, tokenId);
    
    console.log(`\n¡Cupón reclamado exitosamente!`);
    console.log(`Nuevo balance de cupones: ${newUserBalance.toString()}`);
    console.log(`Wallet utilizada: ${signer.address}`);
    console.log(`Clave privada (guardar de forma segura): ${randomWallet.privateKey}`);
    
  } catch (error) {
    console.error("Error durante la reclamación del cupón:", error);
    process.exit(1);
  }
}

// Ejecutar la función principal
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 