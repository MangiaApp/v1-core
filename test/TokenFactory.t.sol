// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/LazyMintFactory.sol";
import "../contracts/Coupon.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

contract TokenFactoryTest is Test {
    LazyMintFactory public factory;
    Coupon public implementation;
    address public owner;
    address public user;
    
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant LOCKED_BUDGET = 10 ether;
    uint256 public constant CUSTOM_FEE = 0.05 ether;
    
    function setUp() public {
        owner = address(0x1234);
        user = address(0x5678);
        
        vm.startPrank(owner);
        vm.deal(owner, 100 ether);
        
        // Deploy the implementation contract
        implementation = new Coupon();
        
        // Deploy the factory with the implementation
        factory = new LazyMintFactory(address(implementation));
        
        vm.stopPrank();
    }
    
    function testCreateLazyMintWithFee() public {
        vm.startPrank(owner);
        // Asegurarse de que hay suficiente presupuesto (fee * maxSupply)
        uint256 requiredBudget = MAX_SUPPLY * CUSTOM_FEE;
        vm.deal(owner, requiredBudget + 100 ether); // Asegurarse de que tiene suficiente ETH
        
        uint256 projectId = factory.createProject("Test Project");
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Captura el balance inicial para verificar
        uint256 initialBalance = address(owner).balance;
        
        // Create a coupon with custom fee and budget
        address couponAddress = factory.createLazyMint{value: requiredBudget}(
            projectId,
            "", // Project name not needed since we're using an existing project
            "ipfs://QmTest",
            MAX_SUPPLY,
            currentTime,
            currentTime + 7 days,
            currentTime + 14 days,
            requiredBudget, // El budget Y el valor enviado deben ser iguales
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            CUSTOM_FEE
        );
        
        // Verificar que el balance se ha reducido correctamente
        assertEq(address(owner).balance, initialBalance - requiredBudget, "Owner balance not reduced correctly");
        
        // Check that the coupon was created with the correct fee
        Coupon coupon = Coupon(payable(couponAddress));
        assertEq(coupon.fee(), CUSTOM_FEE, "Fee was not set correctly");
        assertEq(coupon.lockedBudget(), requiredBudget, "Budget was not set correctly");
        
        vm.stopPrank();
    }
    
    function testCreateLazyMintWithoutFee() public {
        vm.startPrank(owner);
        
        uint256 projectId = factory.createProject("Test Project");
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Create a coupon without budget or fee
        address couponAddress = factory.createLazyMint(
            projectId,
            "",
            "ipfs://QmTest",
            MAX_SUPPLY,
            currentTime,
            currentTime + 7 days,
            currentTime + 14 days,
            0, // No budget
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            0 // No fee
        );
        
        // Check that the coupon was created with the correct fee
        Coupon coupon = Coupon(payable(couponAddress));
        assertEq(coupon.fee(), 0, "Fee should be zero");
        assertEq(coupon.lockedBudget(), 0, "Budget should be zero");
        
        vm.stopPrank();
    }
    
    function testRevertWhenBudgetWithoutFee() public {
        vm.startPrank(owner);
        vm.deal(owner, LOCKED_BUDGET);
        
        uint256 projectId = factory.createProject("Test Project");
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Should revert when trying to set budget without fee
        vm.expectRevert(TokenFactory.FeeMustBeSetWithBudget.selector);
        factory.createLazyMint{value: LOCKED_BUDGET}(
            projectId,
            "",
            "ipfs://QmTest",
            MAX_SUPPLY,
            currentTime,
            currentTime + 7 days,
            currentTime + 14 days,
            LOCKED_BUDGET, // Setting budget
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            0 // But no fee! Should revert
        );
        
        vm.stopPrank();
    }
    
    function testRevertInsufficientBudgetForMaxSupply() public {
        vm.startPrank(owner);
        
        uint256 projectId = factory.createProject("Test Project");
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Intentar crear con presupuesto insuficiente para maxSupply
        uint256 insufficientBudget = (MAX_SUPPLY * CUSTOM_FEE) - 1;
        vm.deal(owner, insufficientBudget + 100 ether); // Dar suficiente ETH
        
        // Debería revertir por presupuesto insuficiente
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        factory.createLazyMint{value: insufficientBudget}(
            projectId,
            "",
            "ipfs://QmTest",
            MAX_SUPPLY,
            currentTime,
            currentTime + 7 days,
            currentTime + 14 days,
            insufficientBudget,
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            CUSTOM_FEE
        );
        
        vm.stopPrank();
    }
    
    function testFeeworksWithAffiliates() public {
        vm.startPrank(owner);
        // Asegurarse de tener suficiente presupuesto para maxSupply
        uint256 requiredBudget = MAX_SUPPLY * CUSTOM_FEE;
        vm.deal(owner, requiredBudget + 100 ether); // Dar suficiente ETH
        
        uint256 projectId = factory.createProject("Test Project");
        
        // Current timestamp
        uint256 currentTime = block.timestamp;
        
        // Capturar balance inicial
        uint256 initialBalance = address(owner).balance;
        
        // Create a coupon with custom fee and budget
        address couponAddress = factory.createLazyMint{value: requiredBudget}(
            projectId,
            "",
            "ipfs://QmTest",
            MAX_SUPPLY,
            currentTime,
            currentTime + 7 days,
            currentTime + 14 days,
            requiredBudget, // Asegurarse de que coincide con el valor enviado
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            CUSTOM_FEE
        );
        
        // Verificar que el balance ha disminuido correctamente
        assertEq(address(owner).balance, initialBalance - requiredBudget, "Owner balance not reduced correctly");
        
        vm.stopPrank();
        
        Coupon coupon = Coupon(payable(couponAddress));
        
        // Verificar que el contrato tiene el presupuesto
        assertEq(address(coupon).balance, requiredBudget, "Coupon contract did not receive funds");
        
        // Create a user to be an affiliate
        address affiliate = address(0xABCD);
        vm.deal(affiliate, 1 ether);
        
        // Register as affiliate
        vm.startPrank(affiliate);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(affiliate);
        vm.stopPrank();
        
        // Create a user to claim with the affiliate
        address claimer = address(0xDEF);
        vm.startPrank(claimer);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
        
        // Record initial balance
        uint256 initialAffiliateBalance = affiliate.balance;
        
        // Have owner redeem the coupon
        vm.startPrank(owner);
        coupon.redeemCoupon(claimer);
        vm.stopPrank();
        
        // Verify affiliate got paid with the custom fee amount
        assertEq(affiliate.balance, initialAffiliateBalance + CUSTOM_FEE, "Affiliate was not paid the correct fee");
    }
} 