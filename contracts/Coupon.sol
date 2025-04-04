// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

/// @title Coupon Contract
/// @notice This contract allows lazy minting of ERC1155 tokens, affiliate registration, 
///         and coupon redemption with a fee mechanism. It's designed to be immutable.
contract Coupon is Initializable, ERC1155Upgradeable, OwnableUpgradeable {
    /// @dev Fixed token ID for the single token in this collection
    uint256 public tokenId;

    /// @dev Tracks the total supply of the token
    uint256 public totalSupply;

    /// @dev Maximum number of tokens that can be minted
    uint256 public maxSupply;

    /// @dev Fee amount for coupon redemption, denominated in native or specified currency
    uint256 public fee;

    /// @dev Base URI for metadata
    string private _tokenURI;

    /// @dev Counter for generating unique affiliate IDs
    uint256 public nextAffiliateId;

    /// @dev Mapping from affiliate ID to affiliate owner address
    mapping(uint256 => address) public affiliateOwners;

    /// @dev Mapping from affiliate owner address to affiliate ID
    mapping(address => uint256) public affiliateIDs;

    /// @dev Mapping to track token affiliates for owners
    mapping(uint256 => mapping(address => uint256)) public tokenOwnerAffiliates;

    /// @dev Mapping to track redeemed token quantities
    mapping(uint256 => mapping(address => uint256)) public redeemedQuantities;

    /// @dev Mapping to track the count of redeemed token quantities
    mapping(uint256 => uint256) public redeemedTokenCount;

    /// @dev Expiration timestamp for claiming tokens
    uint256 public claimStart;
    uint256 public claimEnd;
    uint256 public redeemExpiration;

    /// @dev Budget locked for paying affiliates
    uint256 public lockedBudget;

    /// @dev Address of the currency used for fee payments
    address public currencyAddress;

    /// @dev Add a new state variable to track tokens claimed with affiliates
    uint256 public tokensWithAffiliates;

    /// @dev Mapping to track if a wallet is an affiliate
    mapping(address => bool) public isAffiliate;

    /// @dev Mapping to track affiliate referrals
    mapping(address => uint256) public affiliateReferrals;

    /// @notice Event emitted when a new affiliate is registered
    event AffiliateRegistered(
        address indexed affiliateAddress,
        address contractAddress,
        uint256 timestamp
    );

    /// @notice Event emitted when a coupon is redeemed
    event CouponRedeemed(
        address indexed owner,
        uint256 indexed tokenId,
        address affiliateAddress,
        uint256 fee,
        address contractAddress,
        uint256 timestamp,
        address currency
    );

    /// @notice Event emitted when tokens are claimed
    event TokenClaimed(
        address indexed claimer,
        address indexed receiver,
        uint256 indexed tokenId,
        address affiliateAddress,
        address contractAddress,
        uint256 timestamp
    );

    /// @notice Event emitted when budget is locked
    event BudgetLocked(address indexed locker, uint256 amount, address contractAddress);

    /// @notice Event emitted when budget is withdrawn
    event BudgetWithdrawn(address indexed withdrawer, uint256 amount, address contractAddress);

    /// @notice Errors for various invalid states
    error MaxSupplyMustBeGreaterThanZero();
    error AlreadyRegisteredAsAffiliate();
    error TokenAlreadyClaimed();
    error QuantityMustBeGreaterThanZero();
    error ExceedsMaxSupply();
    error InvalidAffiliateID();
    error OwnerDoesNotOwnToken();
    error TokenQuantityAlreadyRedeemed();
    error NoAffiliateAssociated();
    error InvalidAffiliateAddress();
    error FeeMustBeGreaterThanZero();
    error MustSendTotalFee();
    error ClaimExpired();
    error RedeemExpired();
    error InsufficientBudget();
    error InvalidWithdrawalAmount();
    error ExcessiveBudget();
    error ClaimStartMustBeBeforeClaimEnd();
    error ClaimEndMustBeBeforeRedeemExpiration();
    error ClaimNotStarted();
    error AlreadyInitialized();
    error InvalidCurrencyAmount();

    /// @dev Constructor is disabled in favor of initialize
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev initialize replaces the constructor for upgradeable contracts
    /// @param _uri The base URI for the token metadata
    /// @param _maxSupply The maximum number of tokens that can be minted
    /// @param _claimStart Expiration timestamp for claiming tokens
    /// @param _claimEnd Expiration timestamp for claiming tokens
    /// @param _redeemExpiration Expiration timestamp for redeeming coupons
    /// @param _lockedBudget The budget locked for paying affiliates (optional)
    function initialize(
        string memory _uri,
        uint256 _maxSupply,
        uint256 _claimStart,
        uint256 _claimEnd,
        uint256 _redeemExpiration,
        uint256 _lockedBudget,
        address _currencyAddress,
        uint256 _tokenId,
        uint256 _fee,
        address _owner
    ) public payable initializer {
        __ERC1155_init(_uri);
        __Ownable_init(_owner);
        
        if (_maxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }
        if (_claimStart >= _claimEnd) {
            revert ClaimStartMustBeBeforeClaimEnd();
        }
        if (_claimEnd >= _redeemExpiration) {
            revert ClaimEndMustBeBeforeRedeemExpiration();
        }
        if (_fee > 0 && _lockedBudget < _fee * _maxSupply) {
            revert InsufficientBudget();
        }
        
        // Validar y transferir la moneda apropiada para el presupuesto inicial
        if (_lockedBudget > 0) {
            if (_currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
                // Para ETH, verificar que el valor enviado coincide con el presupuesto
                if (msg.value != _lockedBudget) {
                    revert MustSendTotalFee();
                }
            } else {
                // Para tokens ERC20, no debe enviarse ETH
                if (msg.value > 0) {
                    revert MustSendTotalFee();
                }
                // Transferir tokens ERC20 del inicializador al contrato
                CurrencyTransferLib.transferCurrency(_currencyAddress, msg.sender, address(this), _lockedBudget);
            }
        } else {
            // Si no hay presupuesto, no debe enviarse ETH
            if (msg.value > 0) {
                revert MustSendTotalFee();
            }
        }
        
        fee = _fee;
        _tokenURI = _uri;
        maxSupply = _maxSupply;
        claimStart = _claimStart;
        claimEnd = _claimEnd;
        redeemExpiration = _redeemExpiration;
        lockedBudget = _lockedBudget;
        currencyAddress = _currencyAddress;
        tokenId = _tokenId;
        nextAffiliateId = 1;
        totalSupply = 0;
        tokensWithAffiliates = 0;
    }

    /// @dev Calculates the required budget based on tokens with affiliates and claim patterns
    /// @return The amount of budget required to cover potential affiliate payments
    function calculateRequiredBudget() public view returns (uint256) {
        // Presupuesto necesario para tokens ya reclamados con afiliados (y aún no redimidos)
        uint256 currentLockedBudgetNeeded = tokensWithAffiliates * fee;
        
        // Ya no reservamos presupuesto adicional para futuros afiliados
        // Los nuevos afiliados solo podrán registrarse si hay suficiente presupuesto disponible
        
        return currentLockedBudgetNeeded;
    }

    /// @notice Allows users to register as an affiliate
    /// @dev Emits `AffiliateRegistered` on successful registration
    function registerAffiliate() public {
        if (isAffiliate[msg.sender]) {
            revert AlreadyRegisteredAsAffiliate();
        }

        // Verificar presupuesto disponible
        if (lockedBudget < fee) {
            revert InsufficientBudget();
        }

        isAffiliate[msg.sender] = true;

        emit AffiliateRegistered(
            msg.sender,
            address(this),
            block.timestamp
        );
    }

    /// @notice Verifies if a user is eligible to claim tokens
    /// @param _claimer Address of the user attempting to claim tokens
    function verifyClaim(address _claimer) public view {
        if (balanceOf(_claimer, tokenId) > 0) {
            revert TokenAlreadyClaimed();
        }
        if (block.timestamp < claimStart) {
            revert ClaimNotStarted();
        }
        if (block.timestamp > claimEnd) {
            revert ClaimExpired();
        }
    }

    /// @notice Allows users to claim tokens
    /// @param affiliateAddress The affiliate address associated with the claim (optional)
    /// @dev Emits `TokenClaimed` on successful claim
    function customClaim(address affiliateAddress) public payable {
        if (totalSupply + 1 > maxSupply) {
            revert ExceedsMaxSupply();
        }

        verifyClaim(msg.sender);

        if (affiliateAddress != address(0)) {
            if (!isAffiliate[affiliateAddress]) revert InvalidAffiliateAddress();
            if (affiliateAddress == msg.sender) revert InvalidAffiliateAddress();
            
            if (lockedBudget < fee) revert InsufficientBudget();
            
            // Incrementar referencias del afiliado
            affiliateReferrals[affiliateAddress] += 1;
            tokensWithAffiliates += 1;
        }

        _mint(msg.sender, tokenId, 1, "");
        totalSupply += 1;

        emit TokenClaimed(
            msg.sender, 
            msg.sender, 
            tokenId, 
            affiliateAddress, 
            address(this), 
            block.timestamp
        );
    }

    /// @notice Allows the contract owner to redeem coupons for token holders
    /// @param tokenOwner Address of the token holder
    /// @dev Emits `CouponRedeemed` on successful redemption
    function redeemCoupon(address tokenOwner) public onlyOwner {
        if (balanceOf(tokenOwner, tokenId) <= 0) revert OwnerDoesNotOwnToken();
        if (block.timestamp > redeemExpiration) {
            revert RedeemExpired();
        }

        uint256 redeemedQuantity = redeemedQuantities[tokenId][tokenOwner];
        
        if (redeemedQuantity > 0) revert TokenQuantityAlreadyRedeemed();

        uint256 affiliateId = tokenOwnerAffiliates[tokenId][tokenOwner];
        address affiliateAddress = address(0);

        if (affiliateId != 0) {
            affiliateAddress = affiliateOwners[affiliateId];
            if (affiliateAddress == address(0)) revert InvalidAffiliateAddress();
            if (lockedBudget < fee) revert InsufficientBudget();
            
            // Decrementar tokens con afiliados cuando se redimen
            tokensWithAffiliates -= 1;
            
            // Reducir el presupuesto bloqueado antes de la transferencia
            lockedBudget -= fee;
            
            // Transferir el fee al afiliado usando CurrencyTransferLib
            if (currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
                (bool success, ) = affiliateAddress.call{value: fee}("");
                require(success, "Transfer failed");
            } else {
                CurrencyTransferLib.transferCurrency(currencyAddress, address(this), affiliateAddress, fee);
            }
        }

        redeemedQuantities[tokenId][tokenOwner] = 1;
        redeemedTokenCount[tokenId] += 1;

        emit CouponRedeemed(tokenOwner, tokenId, affiliateAddress, fee, address(this), block.timestamp, currencyAddress);
    }

    /// @notice Returns the URI for token metadata
    /// @return URI string
    function uri(uint256) public view override returns (string memory) {
        return _tokenURI;
    }

    /// @notice Updates the token URI
    /// @param newURI New URI to set
    function setURI(string memory newURI) public onlyOwner {
        _tokenURI = newURI;
    }

    /// @notice Allows users to lock additional budget for affiliate payments
    /// @param amount Amount of budget to lock
    function lockBudget(uint256 amount) public payable {
        if (currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != amount) revert MustSendTotalFee();
        } else {
            if (msg.value > 0) revert MustSendTotalFee();
            CurrencyTransferLib.transferCurrency(currencyAddress, msg.sender, address(this), amount);
        }
        
        lockedBudget += amount;
        emit BudgetLocked(msg.sender, amount, address(this));
    }

    /// @notice Allows the owner to withdraw locked budget
    /// @param amount Amount of budget to withdraw
    function withdrawBudget(uint256 amount) public onlyOwner {
        if (amount > lockedBudget) revert InvalidWithdrawalAmount();
        
        // Si el tiempo de redención ha expirado, permitir retirar cualquier cantidad
        if (block.timestamp > redeemExpiration) {
            lockedBudget -= amount;
            
            if (currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
                (bool success, ) = msg.sender.call{value: amount}("");
                require(success, "Transfer failed");
            } else {
                CurrencyTransferLib.transferCurrency(currencyAddress, address(this), msg.sender, amount);
            }
            
            emit BudgetWithdrawn(msg.sender, amount, address(this));
            return;
        }
        
        // Calcular el presupuesto requerido utilizando la función compartida
        uint256 requiredBudget = calculateRequiredBudget();
        
        // Asegurar que queda suficiente presupuesto después del retiro
        if (lockedBudget - amount < requiredBudget) {
            revert InsufficientBudget();
        }
        
        lockedBudget -= amount;
        
        if (currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Transfer failed");
        } else {
            CurrencyTransferLib.transferCurrency(currencyAddress, address(this), msg.sender, amount);
        }
        
        emit BudgetWithdrawn(msg.sender, amount, address(this));
    }
    
    /// @notice Returns the available budget that can be withdrawn
    /// @return Amount of budget available for withdrawal
    function getAvailableBudget() public view returns (uint256) {
        uint256 requiredBudget = calculateRequiredBudget();
        
        if (requiredBudget >= lockedBudget) {
            return 0;
        }
        
        return lockedBudget - requiredBudget;
    }

    /// @notice Only for testing - allows setting the locked budget directly
    function setLockedBudgetForTesting(uint256 _newBudget) public onlyOwner {
        lockedBudget = _newBudget;
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}