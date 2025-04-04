// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../contracts/Coupon.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

contract CouponTest is Test {
    Coupon public implementation;
    Coupon public coupon;
    address public owner;
    address public user;
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public constant FEE = 0.01 ether;
    uint256 public constant LOCKED_BUDGET = 10 ether;

    function setUp() public {
        owner = address(0x1234); // Use a normal EOA address
        user = address(0x1);
        vm.deal(user, 100 ether); // Give the user some ETH
        
        // Calcular presupuesto requerido basado en fee * maxSupply
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        vm.deal(owner, requiredBudget + 10 ether); // Dar suficiente ETH al propietario
        
        // Deploy the implementation contract
        implementation = new Coupon();
        
        // Deploy the proxy with initial budget
        bytes memory initData = abi.encodeWithSelector(
            Coupon.initialize.selector,
            "ipfs://QmTest",
            MAX_SUPPLY,
            block.timestamp,
            block.timestamp + 7 days,
            block.timestamp + 14 days,
            requiredBudget, // Usar el presupuesto requerido
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            TOKEN_ID,
            FEE,
            owner
        );
        
        // Deploy proxy and initialize with ETH - enviar valor exacto
        vm.prank(owner); // Importante: ejecutar como owner que tiene ETH
        ERC1967Proxy proxy = new ERC1967Proxy{value: requiredBudget}(
            address(implementation),
            initData
        );
        
        coupon = Coupon(payable(proxy));
    }

    function testInitialization() public view {
        // El presupuesto requerido es fee * maxSupply
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        
        assertEq(coupon.maxSupply(), MAX_SUPPLY);
        assertEq(coupon.tokenId(), TOKEN_ID);
        assertEq(coupon.fee(), FEE);
        // Asegurarse de verificar el presupuesto requirido, no LOCKED_BUDGET
        assertEq(coupon.lockedBudget(), requiredBudget);
        assertEq(coupon.owner(), owner);
        assertEq(coupon.tokensWithAffiliates(), 0);
    }

    function testClaimToken() public {
        vm.startPrank(user);
        
        // Claim 1 token
        coupon.customClaim(0); // Claim without affiliate

        // Verify the claim
        assertEq(coupon.balanceOf(user, TOKEN_ID), 1);
        assertEq(coupon.totalSupply(), 1);
        
        vm.stopPrank();
    }

    function testRevertWhenClaimingTooMany() public {
        vm.startPrank(user);
        
        // First claim MAX_SUPPLY tokens
        for (uint i = 0; i < MAX_SUPPLY; i++) {
            address claimer = address(uint160(i + 100)); // Generate unique addresses
            vm.stopPrank();
            vm.startPrank(claimer);
            coupon.customClaim(0);
        }
        
        // Try to claim one more (exceeds max supply)
        vm.stopPrank();
        vm.startPrank(user);
        vm.expectRevert(Coupon.ExceedsMaxSupply.selector);
        coupon.customClaim(0);
        
        vm.stopPrank();
    }

    function testRegisterAffiliate() public {
        vm.startPrank(user);
        
        // Register as affiliate
        coupon.registerAffiliate();
        
        // Verify registration
        uint256 affiliateId = coupon.affiliateIDs(user);
        assertGt(affiliateId, 0);
        assertEq(coupon.affiliateOwners(affiliateId), user);
        
        vm.stopPrank();
    }

    function testLockBudget() public {
        uint256 additionalBudget = 5 ether;
        
        // Record initial budget
        uint256 initialBudget = coupon.lockedBudget();
        
        vm.startPrank(user);
        vm.deal(user, additionalBudget + 1 ether); // Asegurarse de que tiene suficiente ETH
        
        // Lock budget with ETH value - enviar el valor exacto
        coupon.lockBudget{value: additionalBudget}(additionalBudget);
        
        // Verify budget increased
        assertEq(coupon.lockedBudget(), initialBudget + additionalBudget);
        assertEq(address(coupon).balance, initialBudget + additionalBudget);
        
        vm.stopPrank();
    }

    function testRevertInsufficientBudgetForAffiliate() public {
        // Con la nueva lógica, sólo se necesita fee para registrarse como afiliado
        // Establecer el presupuesto por debajo del fee
        vm.prank(owner);
        coupon.setLockedBudgetForTesting(FEE - 1 wei);
        
        // Verificar que el presupuesto se actualizó correctamente
        assertEq(coupon.lockedBudget(), FEE - 1 wei, "Budget not updated correctly");
        
        // Intentar registrarse como afiliado con presupuesto insuficiente
        vm.startPrank(user);
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        coupon.registerAffiliate();
        vm.stopPrank();
    }

    function testRedeemCouponWithAffiliate() public {
        // Para asegurarse de que el contrato tenga fondos para pagos de afiliados
        vm.deal(address(coupon), MAX_SUPPLY * FEE + 1 ether);
        
        // First register an affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        vm.stopPrank();

        // Create another user to claim tokens
        address tokenHolder = address(0x2);
        vm.deal(tokenHolder, 1 ether);
        
        // Claim tokens with affiliate
        vm.startPrank(tokenHolder);
        uint256 affiliateId = coupon.affiliateIDs(user);
        coupon.customClaim(affiliateId);
        vm.stopPrank();

        // Record initial balances
        uint256 initialAffiliateBalance = user.balance;
        uint256 initialLockedBudget = coupon.lockedBudget();

        // Owner redeems the coupon
        vm.prank(owner);
        coupon.redeemCoupon(tokenHolder);

        // Verify affiliate payment and budget reduction
        assertEq(user.balance, initialAffiliateBalance + FEE);
        assertEq(coupon.lockedBudget(), initialLockedBudget - FEE);
        assertEq(coupon.redeemedQuantities(TOKEN_ID, tokenHolder), 1);
    }

    function testRevertDoubleRedemption() public {
        // Setup token holder with tokens
        address tokenHolder = address(0x2);
        vm.startPrank(tokenHolder);
        coupon.customClaim(0); // Claim without affiliate
        vm.stopPrank();

        // First redemption
        vm.prank(owner);
        coupon.redeemCoupon(tokenHolder);

        // Try to redeem again - should fail
        vm.prank(owner);
        vm.expectRevert(Coupon.TokenQuantityAlreadyRedeemed.selector);
        coupon.redeemCoupon(tokenHolder);
    }

    function testRevertWithdrawExcessiveBudget() public {
        vm.prank(owner);
        
        // Try to withdraw more than available budget
        vm.expectRevert(Coupon.InvalidWithdrawalAmount.selector);
        coupon.withdrawBudget(LOCKED_BUDGET + 1 ether);
    }

    function testRevertRedeemAfterExpiration() public {
        // Setup token holder with tokens
        address tokenHolder = address(0x2);
        vm.startPrank(tokenHolder);
        coupon.customClaim(0);
        vm.stopPrank();

        // Move time past redemption expiration
        vm.warp(block.timestamp + 15 days);

        // Try to redeem after expiration
        vm.prank(owner);
        vm.expectRevert(Coupon.RedeemExpired.selector);
        coupon.redeemCoupon(tokenHolder);
    }

    function testWithdrawBudgetAfterExpiration() public {
        // Configurar contrato con presupuesto correcto
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        
        // Advance time beyond expiration date
        vm.warp(block.timestamp + 15 days);
        
        // Verify we're after expiration
        assertTrue(block.timestamp > coupon.redeemExpiration());
        
        // Asegurarse de que el contrato tiene ETH
        vm.deal(address(coupon), requiredBudget);
        
        // Ensure the owner has an initial balance to track
        vm.deal(owner, 1 ether);
        uint256 initialOwnerBalance = address(owner).balance;
        
        // Try to withdraw as owner - debería poder retirar todo después de expiración
        vm.prank(owner);
        coupon.withdrawBudget(requiredBudget);
        
        // Verify the budget was updated correctly
        assertEq(coupon.lockedBudget(), 0, "Budget should be zero after full withdrawal");
        assertEq(address(owner).balance, initialOwnerBalance + requiredBudget, "Owner balance not updated correctly");
    }
    
    // ADDITIONAL TEST CASES

    // The test for claiming zero quantity should be removed since that's no longer possible
    function testRevertClaimZeroQuantity() public {
        // This test is no longer needed as quantity parameter has been removed
        // The function now always claims exactly one token
    }
    
    // Negative test case: Non-owner cannot redeem coupons
    function testRevertNonOwnerRedeemCoupon() public {
        // Setup token holder with tokens
        address tokenHolder = address(0x2);
        vm.startPrank(tokenHolder);
        coupon.customClaim(0);
        vm.stopPrank();
        
        // Try to redeem as non-owner
        vm.startPrank(user); // user is not the owner
        vm.expectRevert(); // Will revert with Ownable's unauthorized error
        coupon.redeemCoupon(tokenHolder);
        vm.stopPrank();
    }
    
    // Negative test case: Cannot claim tokens after claim period expiration
    function testRevertClaimAfterExpiration() public {
        // Move time past claim expiration
        vm.warp(block.timestamp + 8 days); // Claim ends after 7 days
        
        vm.startPrank(user);
        vm.expectRevert(Coupon.ClaimExpired.selector);
        coupon.customClaim(0);
        vm.stopPrank();
    }
    
    // Negative test case: Cannot claim tokens before claim period starts
    function testRevertClaimBeforeStart() public {
        // Setup claim period in the future
        address futureOwner = address(0x1234);
        
        // Calcular presupuesto requerido para este test
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        vm.deal(futureOwner, requiredBudget + 10 ether);
        
        // Deploy new contract with future claim period
        implementation = new Coupon();
        bytes memory initData = abi.encodeWithSelector(
            Coupon.initialize.selector,
            "ipfs://QmTest",
            MAX_SUPPLY,
            block.timestamp + 1 days, // Start in future
            block.timestamp + 7 days,
            block.timestamp + 14 days,
            requiredBudget, // Usar presupuesto correcto
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            TOKEN_ID,
            FEE,
            futureOwner
        );
        
        // Usar prank para ejecutar como futureOwner
        vm.startPrank(futureOwner);
        ERC1967Proxy proxy = new ERC1967Proxy{value: requiredBudget}(
            address(implementation),
            initData
        );
        vm.stopPrank();
        
        Coupon futureCoupon = Coupon(payable(proxy));
        
        // Try to claim before start
        vm.startPrank(user);
        vm.expectRevert(Coupon.ClaimNotStarted.selector);
        futureCoupon.customClaim(0);
        vm.stopPrank();
    }
    
    // Negative test case: Cannot register as affiliate twice
    function testRevertRegisterAffiliateTwice() public {
        vm.startPrank(user);
        
        // First registration
        coupon.registerAffiliate();
        
        // Second attempt should fail
        vm.expectRevert(Coupon.AlreadyRegisteredAsAffiliate.selector);
        coupon.registerAffiliate();
        
        vm.stopPrank();
    }
    
    // Negative test case: Cannot use self as affiliate
    function testRevertSelfAffiliate() public {
        // First register as affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Try to claim with self as affiliate
        vm.startPrank(user);
        vm.expectRevert(Coupon.InvalidAffiliateID.selector);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
    }
    
    // Positive test case: Redeem coupon without affiliate
    function testRedeemCouponWithoutAffiliate() public {
        // Setup token holder with tokens
        address tokenHolder = address(0x2);
        vm.startPrank(tokenHolder);
        coupon.customClaim(0); // Claim without affiliate
        vm.stopPrank();
        
        // Record initial budget
        uint256 initialLockedBudget = coupon.lockedBudget();
        
        // Owner redeems the coupon
        vm.prank(owner);
        coupon.redeemCoupon(tokenHolder);
        
        // Verify budget unchanged but redemption recorded
        assertEq(coupon.lockedBudget(), initialLockedBudget); // Budget should not change without affiliate
        assertEq(coupon.redeemedQuantities(TOKEN_ID, tokenHolder), 1);
    }
    
    // Update this test to reflect the latest contract updates
    function testRevertWithdrawRequiredBudget() public {
        // Registrar un afiliado
        vm.startPrank(user);
        coupon.registerAffiliate();
        vm.stopPrank();
        
        // Cargar el contrato con fondos suficientes
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        vm.deal(address(coupon), requiredBudget);
        
        // Create a user who claims with affiliate to lock some budget
        address claimer = address(0x123);
        vm.startPrank(claimer);
        uint256 affiliateId = coupon.affiliateIDs(user);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
        
        // Presupuesto requerido ahora es 1 token con afiliado = 1 * FEE
        uint256 currentRequiredBudget = FEE;
        
        // Intentar retirar más del permitido
        vm.startPrank(owner);
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        coupon.withdrawBudget(requiredBudget - currentRequiredBudget + 1 wei);
        vm.stopPrank();
        
        // Ahora retirar una cantidad permitida
        uint256 safeAmount = requiredBudget - currentRequiredBudget - 0.01 ether;
        vm.prank(owner);
        coupon.withdrawBudget(safeAmount);
        
        assertEq(coupon.lockedBudget(), requiredBudget - safeAmount, "Budget not correctly updated");
    }
    
    // Positive test case: Multiple claims with same affiliate
    function testMultipleClaimsWithSameAffiliate() public {
        // Register affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Multiple users claim with the same affiliate
        address tokenHolder1 = address(0x2);
        address tokenHolder2 = address(0x3);
        
        vm.deal(tokenHolder1, 1 ether);
        vm.startPrank(tokenHolder1);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
        
        vm.deal(tokenHolder2, 1 ether);
        vm.startPrank(tokenHolder2);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
        
        // Make sure affiliate has a clean balance to start with
        vm.deal(user, 100 ether);
        uint256 initialAffiliateBalance = user.balance;
        
        // Record initial budget
        uint256 initialLockedBudget = coupon.lockedBudget();
        
        // Fund the contract with enough ETH for redemptions
        vm.deal(address(coupon), LOCKED_BUDGET);
        
        // Owner redeems both coupons
        vm.startPrank(owner);
        coupon.redeemCoupon(tokenHolder1);
        coupon.redeemCoupon(tokenHolder2);
        vm.stopPrank();
        
        // Verify affiliate got paid for both redemptions
        // Each redemption is one fee per user, not per token (based on actual implementation)
        assertEq(user.balance, initialAffiliateBalance + 2 * FEE, "Affiliate balance incorrect");
        assertEq(coupon.lockedBudget(), initialLockedBudget - 2 * FEE, "Budget not reduced correctly");
    }
    
    // Negative test case: Lock budget without sending enough ETH
    function testRevertLockBudgetWithoutETH() public {
        vm.startPrank(user);
        vm.deal(user, 2 ether); // Dar algo de ETH
        
        // Try to lock budget with incorrect ETH amount
        uint256 amount = 1 ether;
        vm.expectRevert(Coupon.MustSendTotalFee.selector);
        coupon.lockBudget{value: amount - 1 wei}(amount); // Enviar menos del monto especificado
        
        vm.stopPrank();
    }
    
    // Actualizar testPartialWithdrawBudget para usar la lógica correcta de presupuesto
    function testPartialWithdrawBudget() public {
        // Configurar un contrato con budget específico para esta prueba
        uint256 requiredBudget = MAX_SUPPLY * FEE;
        
        // Asegurarse de que el contrato tiene ETH para retirar
        vm.deal(address(coupon), requiredBudget + 10 ether);
        
        // Claim and redeem most tokens to reduce required budget
        address[] memory tokenHolders = new address[](MAX_SUPPLY - 10);
        
        // Claim most tokens
        for (uint i = 0; i < MAX_SUPPLY - 10; i++) {
            tokenHolders[i] = address(uint160(i + 100)); // Create unique addresses
            vm.startPrank(tokenHolders[i]);
            coupon.customClaim(0);
            vm.stopPrank();
            
            // Redeem those tokens so they're counted in redeemedTokenCount
            vm.prank(owner);
            coupon.redeemCoupon(tokenHolders[i]);
        }
        
        // Ahora solo quedan 10 tokens por reclamar
        // Calcular presupuesto requerido según nueva lógica
        uint256 currentRequiredBudget = 0; // Sin tokens con afiliados ni afiliados registrados
        
        // Calculate a safe withdrawal amount - dejar un margen de seguridad
        uint256 withdrawAmount = requiredBudget - currentRequiredBudget - 0.1 ether;
        
        // Record initial balances
        uint256 initialOwnerBalance = address(owner).balance;
        
        // Owner withdraws part of the budget
        vm.prank(owner);
        coupon.withdrawBudget(withdrawAmount);
        
        // Verify partial withdrawal
        assertEq(coupon.lockedBudget(), requiredBudget - withdrawAmount, "Budget not correctly updated");
        assertEq(address(owner).balance, initialOwnerBalance + withdrawAmount, "Owner balance not correctly updated");
    }

    function testTrackTokensWithAffiliates() public {
        // Asegurarse de que el contrato tiene ETH para pruebas
        vm.deal(address(coupon), MAX_SUPPLY * FEE);
        
        // Register an affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Initial check
        assertEq(coupon.tokensWithAffiliates(), 0, "Should start with zero tokens with affiliates");
        
        // Create 3 users who claim with affiliate
        address[] memory users = new address[](3);
        for (uint i = 0; i < 3; i++) {
            users[i] = address(uint160(i + 200)); // Create unique addresses
            vm.startPrank(users[i]);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Check tokensWithAffiliates after first claims
        assertEq(coupon.tokensWithAffiliates(), 3, "Should track 3 tokens with affiliates");
        
        // User claims without affiliate
        address user2 = address(0x300);
        vm.startPrank(user2);
        coupon.customClaim(0);
        vm.stopPrank();
        
        // Check tokensWithAffiliates remains the same
        assertEq(coupon.tokensWithAffiliates(), 3, "Should still track only 3 tokens with affiliates");
        
        // More users claim with same affiliate
        for (uint i = 0; i < 4; i++) {
            address newUser = address(uint160(i + 400)); // More unique addresses
            vm.startPrank(newUser);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Check tokensWithAffiliates after third claim
        assertEq(coupon.tokensWithAffiliates(), 7, "Should track total 7 tokens with affiliates");
    }
    
    function testDecrementTokensWithAffiliatesOnRedemption() public {
        // Asegurarse de que el contrato tiene ETH para pagos
        vm.deal(address(coupon), MAX_SUPPLY * FEE);
        
        // Register an affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // 5 Users claim with affiliate
        address[] memory users = new address[](5);
        for (uint i = 0; i < 5; i++) {
            users[i] = address(uint160(i + 500)); // Create unique addresses
            vm.startPrank(users[i]);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Check tokensWithAffiliates after claim
        assertEq(coupon.tokensWithAffiliates(), 5, "Should track 5 tokens with affiliates");
        
        // Owner redeems 2 tokens
        vm.startPrank(owner);
        coupon.redeemCoupon(users[0]);
        coupon.redeemCoupon(users[1]);
        vm.stopPrank();
        
        // Check tokensWithAffiliates after redemption
        assertEq(coupon.tokensWithAffiliates(), 3, "Should track 3 tokens with affiliates after redemption");
        
        // Owner redeems remaining 3 tokens
        vm.startPrank(owner);
        coupon.redeemCoupon(users[2]);
        coupon.redeemCoupon(users[3]);
        coupon.redeemCoupon(users[4]);
        vm.stopPrank();
        
        // Check tokensWithAffiliates after all redeemed
        assertEq(coupon.tokensWithAffiliates(), 0, "Should have zero tokens with affiliates after all redeemed");
    }
    
    function testWithdrawBudgetWithNewCalculation() public {
        // Registrar un afiliado
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Crear 30 usuarios con afiliado
        address[] memory usersWithAffiliate = new address[](30);
        for (uint i = 0; i < 30; i++) {
            usersWithAffiliate[i] = address(uint160(i + 600));
            vm.startPrank(usersWithAffiliate[i]);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Crear 70 usuarios sin afiliado
        address[] memory usersWithoutAffiliate = new address[](70);
        for (uint i = 0; i < 70; i++) {
            usersWithoutAffiliate[i] = address(uint160(i + 700));
            vm.startPrank(usersWithoutAffiliate[i]);
            coupon.customClaim(0);
            vm.stopPrank();
        }
        
        // Asegurar que el contrato tiene ETH
        vm.deal(address(coupon), MAX_SUPPLY * FEE);
        
        // Con la nueva lógica, el presupuesto requerido es:
        // tokensWithAffiliates * fee (sin fee adicional para afiliados registrados)
        uint256 requiredBudget = 30 * FEE;
        
        // Intentar retirar demasiado presupuesto (dejando menos del requerido)
        // Establecer presupuesto inicial conocido
        uint256 totalBudget = MAX_SUPPLY * FEE;
        
        vm.startPrank(owner);
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        coupon.withdrawBudget(totalBudget - requiredBudget + 1 wei);
        vm.stopPrank();
        
        // Ahora retirar una cantidad segura
        uint256 safeWithdrawalAmount = totalBudget - requiredBudget - 0.01 ether;
        uint256 initialOwnerBalance = address(owner).balance;
        
        vm.prank(owner);
        coupon.withdrawBudget(safeWithdrawalAmount);
        
        // Verificar que la retirada fue exitosa
        assertEq(coupon.lockedBudget(), totalBudget - safeWithdrawalAmount, "Budget not correctly updated");
        assertEq(address(owner).balance, initialOwnerBalance + safeWithdrawalAmount, "Owner balance not correctly updated");
    }
    
    function testWithdrawBudgetWithNoAffiliates() public {
        // Claim all tokens without affiliates
        for (uint i = 0; i < MAX_SUPPLY; i++) {
            address claimer = address(uint160(i + 800));
            vm.startPrank(claimer);
            coupon.customClaim(0);
            vm.stopPrank();
        }
        
        // Ensure contract has ETH
        vm.deal(address(coupon), LOCKED_BUDGET);
        
        // Since there are no tokens with affiliates, and no unclaimed tokens,
        // the required budget should be 0
        
        // Try to withdraw almost all budget
        uint256 withdrawAmount = LOCKED_BUDGET - 0.01 ether;
        uint256 initialOwnerBalance = address(owner).balance;
        
        vm.prank(owner);
        coupon.withdrawBudget(withdrawAmount);
        
        // Verify withdrawal was successful
        assertEq(coupon.lockedBudget(), LOCKED_BUDGET - withdrawAmount, "Budget not correctly updated");
        assertEq(address(owner).balance, initialOwnerBalance + withdrawAmount, "Owner balance not correctly updated");
    }
    
    function testWithdrawBudgetWithZeroUnclaimed() public {
        // Register an affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Claim half tokens with affiliate - make sure to use unique addresses that don't overlap
        address[] memory usersWithAffiliate = new address[](MAX_SUPPLY/2);
        for (uint i = 0; i < MAX_SUPPLY/2; i++) {
            usersWithAffiliate[i] = address(uint160(i + 2000)); // Starting from 2000 to ensure unique addresses
            vm.startPrank(usersWithAffiliate[i]);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Claim half tokens without affiliate - use different unique addresses that don't overlap
        address[] memory usersWithoutAffiliate = new address[](MAX_SUPPLY/2);
        for (uint i = 0; i < MAX_SUPPLY/2; i++) {
            usersWithoutAffiliate[i] = address(uint160(i + 3000)); // Starting from 3000 to ensure unique addresses
            vm.startPrank(usersWithoutAffiliate[i]);
            coupon.customClaim(0);
            vm.stopPrank();
        }
        
        // Ensure contract has ETH
        vm.deal(address(coupon), LOCKED_BUDGET);
        
        // Calculate expected required budget:
        // 1. Claimed with affiliates: MAX_SUPPLY/2 tokens
        // 2. Unclaimed: 0 tokens
        // Required budget: (MAX_SUPPLY/2) * FEE
        uint256 requiredBudget = (MAX_SUPPLY/2) * FEE;
        
        // Try to withdraw too much budget
        vm.startPrank(owner);
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        coupon.withdrawBudget(LOCKED_BUDGET - requiredBudget + 1 wei);
        vm.stopPrank();
        
        // Now withdraw a safe amount
        uint256 safeWithdrawalAmount = LOCKED_BUDGET - requiredBudget - 0.01 ether;
        uint256 initialOwnerBalance = address(owner).balance;
        
        vm.prank(owner);
        coupon.withdrawBudget(safeWithdrawalAmount);
        
        // Verify withdrawal was successful
        assertEq(coupon.lockedBudget(), LOCKED_BUDGET - safeWithdrawalAmount, "Budget not correctly updated");
        assertEq(address(owner).balance, initialOwnerBalance + safeWithdrawalAmount, "Owner balance not correctly updated");
    }
    
    // Actualizar testNewRegisterAffiliateMinimumBudget con la nueva lógica
    function testNewRegisterAffiliateMinimumBudget() public {
        // Establecer un presupuesto justo para 1 fee
        vm.prank(owner);
        coupon.setLockedBudgetForTesting(FEE);
        
        // Debería poder registrarse con ese presupuesto
        vm.startPrank(user);
        coupon.registerAffiliate();
        vm.stopPrank();
        
        // Verificar registro
        uint256 affiliateId = coupon.affiliateIDs(user);
        assertGt(affiliateId, 0, "Affiliate should be registered");
        
        // Establecer presupuesto por debajo del mínimo
        vm.prank(owner);
        coupon.setLockedBudgetForTesting(FEE - 1 wei);
        
        // Otro usuario no debería poder registrarse ahora
        address user2 = address(0x5);
        vm.startPrank(user2);
        vm.expectRevert(Coupon.InsufficientBudget.selector);
        coupon.registerAffiliate();
        vm.stopPrank();
    }

    // Nuevo test para crear un contrato sin fee y sin budget
    function testInitializeWithoutFeeAndBudget() public {
        // Deploy a new implementation
        Coupon newImplementation = new Coupon();
        
        // Initialize without fee and budget
        bytes memory initData = abi.encodeWithSelector(
            Coupon.initialize.selector,
            "ipfs://QmTest",
            MAX_SUPPLY,
            block.timestamp,
            block.timestamp + 7 days,
            block.timestamp + 14 days,
            0, // Zero budget
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            TOKEN_ID,
            0, // Zero fee
            owner
        );
        
        // Deploy proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(newImplementation),
            initData
        );
        
        Coupon noBudgetCoupon = Coupon(payable(proxy));
        
        // Check initialization
        assertEq(noBudgetCoupon.fee(), 0, "Fee should be zero");
        assertEq(noBudgetCoupon.lockedBudget(), 0, "Budget should be zero");
        assertEq(noBudgetCoupon.maxSupply(), MAX_SUPPLY, "Max supply should be set");
    }

    // Nuevo test para probar cálculo de budget requerido actualizado
    function testCalculateRequiredBudget() public {
        // Register an affiliate
        vm.startPrank(user);
        coupon.registerAffiliate();
        uint256 affiliateId = coupon.affiliateIDs(user);
        vm.stopPrank();
        
        // Tres usuarios reclaman con afiliado
        address[] memory users = new address[](3);
        for (uint i = 0; i < 3; i++) {
            users[i] = address(uint160(i + 200));
            vm.startPrank(users[i]);
            coupon.customClaim(affiliateId);
            vm.stopPrank();
        }
        
        // Con la lógica actualizada, el presupuesto requerido debería ser:
        // 3 tokens con afiliados * FEE (sin fee adicional para futuros registros)
        uint256 expectedRequiredBudget = 3 * FEE;
        
        uint256 actualRequiredBudget = coupon.calculateRequiredBudget();
        assertEq(actualRequiredBudget, expectedRequiredBudget, "Required budget calculation incorrect");
    }

    // Test del nuevo cálculo de presupuesto sin afiliados registrados
    function testCalculateRequiredBudgetWithNoAffiliates() public view {
        // No hay afiliados registrados ni tokens con afiliados, por lo que el presupuesto es 0
        assertEq(coupon.calculateRequiredBudget(), 0, "Should be zero with no affiliates and no tokens");
    }

    // Test para probar getAvailableBudget
    function testGetAvailableBudget() public {
        // Inicialmente, con un afiliado registrado y sin tokens reclamados,
        // el presupuesto requerido es 0, y el disponible es todo el presupuesto
        vm.startPrank(user);
        coupon.registerAffiliate();
        vm.stopPrank();
        
        uint256 expectedAvailable = LOCKED_BUDGET;
        assertEq(coupon.getAvailableBudget(), expectedAvailable, "Available budget calculation incorrect");
        
        // Después de reclamar tokens con afiliado, el disponible se reduce
        address claimer = address(0x300);
        vm.startPrank(claimer);
        uint256 affiliateId = coupon.affiliateIDs(user);
        coupon.customClaim(affiliateId);
        vm.stopPrank();
        
        expectedAvailable = LOCKED_BUDGET - FEE; // 1 token with affiliate
        assertEq(coupon.getAvailableBudget(), expectedAvailable, "Available budget incorrect after claim");
    }

    // Actualización del test para verificar el comportamiento con fee = 0
    function testCreateWithZeroFeeAndRegisterAffiliate() public {
        // Create a contract with zero fee
        Coupon newImplementation = new Coupon();
        bytes memory initData = abi.encodeWithSelector(
            Coupon.initialize.selector,
            "ipfs://QmTest",
            MAX_SUPPLY,
            block.timestamp,
            block.timestamp + 7 days,
            block.timestamp + 14 days,
            0, // Zero budget
            CurrencyTransferLib.NATIVE_TOKEN, // Usar native token en lugar de address(0)
            TOKEN_ID,
            0, // Zero fee
            owner
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(newImplementation),
            initData
        );
        
        Coupon zeroFeeCoupon = Coupon(payable(proxy));
        
        // User can register as affiliate even with zero fee
        vm.startPrank(user);
        zeroFeeCoupon.registerAffiliate();
        vm.stopPrank();
        
        uint256 affiliateId = zeroFeeCoupon.affiliateIDs(user);
        assertGt(affiliateId, 0, "Should be able to register with zero fee");
        
        // Claim with affiliate should work
        address claimer = address(0x400);
        vm.startPrank(claimer);
        zeroFeeCoupon.customClaim(affiliateId);
        vm.stopPrank();
        
        // Redemption should work but affiliate gets 0 fee
        uint256 initialAffiliateBalance = user.balance;
        
        vm.startPrank(owner);
        zeroFeeCoupon.redeemCoupon(claimer);
        vm.stopPrank();
        
        assertEq(user.balance, initialAffiliateBalance, "With zero fee, affiliate balance should not change");
    }

    // Añadir nuevo test para verificar el comportamiento de getAvailableBudget con el nuevo presupuesto
    function testAvailableBudgetAfterRegistration() public {
        uint256 requiredBudget = MAX_SUPPLY * FEE; // El presupuesto total
        
        // Registrar un afiliado
        vm.startPrank(user);
        coupon.registerAffiliate();
        vm.stopPrank();
        
        // Calcular cuánto debería estar disponible después del registro
        // El actual requiredBudget es 0 (ya que no hay tokens con afiliados)
        uint256 expectedAvailable = requiredBudget;
        
        // Verificar
        assertEq(coupon.getAvailableBudget(), expectedAvailable, "Presupuesto disponible incorrecto");
    }
}