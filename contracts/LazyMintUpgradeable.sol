// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

/// @title LazyMintUpgradeable Contract
/// @notice This contract allows lazy minting of ERC1155 tokens, affiliate registration, 
///         and coupon redemption with a fee mechanism. It's designed to be used with proxies.
contract LazyMintUpgradeable is Initializable, ERC1155Upgradeable, OwnableUpgradeable {
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

    /// @notice Event emitted when a new affiliate is registered
    event AffiliateRegistered(address indexed user, uint256 affiliateId, address contractAddress, uint256 timestamp, uint256 tokenId);

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
        uint256 quantity,
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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializer function, replaces constructor for upgradeable contracts
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
    ) public initializer {
        if (_maxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }
        if (_claimStart >= _claimEnd) {
            revert ClaimStartMustBeBeforeClaimEnd();
        }
        if (_claimEnd >= _redeemExpiration) {
            revert ClaimEndMustBeBeforeRedeemExpiration();
        }
        
        __ERC1155_init(_uri);
        __Ownable_init(_owner);
        
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
    }

    /// @notice Allows users to register as an affiliate
    /// @dev Emits `AffiliateRegistered` on successful registration
    function registerAffiliate() public {
        if (affiliateIDs[msg.sender] != 0) {
            revert AlreadyRegisteredAsAffiliate();
        }

        uint256 availableTokens = maxSupply - redeemedTokenCount[tokenId];
        uint256 requiredBudget = availableTokens * fee;
        if (lockedBudget < requiredBudget) {
            revert InsufficientBudget();
        }

        uint256 affiliateId = nextAffiliateId++;
        affiliateOwners[affiliateId] = msg.sender;
        affiliateIDs[msg.sender] = affiliateId;

        emit AffiliateRegistered(msg.sender, affiliateId, address(this), block.timestamp, tokenId);
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
    /// @param _quantity Number of tokens to mint
    /// @param affiliateId The affiliate ID associated with the claim (optional)
    /// @dev Emits `TokenClaimed` on successful claim
    function customClaim(uint256 _quantity, uint256 affiliateId) public payable {
        if (_quantity <= 0) revert QuantityMustBeGreaterThanZero();
        if (totalSupply + _quantity > maxSupply) {
            revert ExceedsMaxSupply();
        }

        verifyClaim(msg.sender);

        address affiliateAddress = address(0);
        if (affiliateId != 0) {
            affiliateAddress = affiliateOwners[affiliateId];
            if (affiliateAddress == address(0)) revert InvalidAffiliateID();
        }

        _mint(msg.sender, tokenId, _quantity, "");
        totalSupply += _quantity;

        emit TokenClaimed(msg.sender, msg.sender, tokenId, _quantity, affiliateAddress, address(this), block.timestamp);
    }

    /// @notice Allows the contract owner to redeem coupons for token holders
    /// @param owner Address of the token holder
    /// @param quantity Number of tokens being redeemed
    /// @dev Emits `CouponRedeemed` on successful redemption
    function redeemCoupon(address owner, uint256 quantity) public onlyOwner {
        if (balanceOf(owner, tokenId) <= 0) revert OwnerDoesNotOwnToken();
        if (block.timestamp > redeemExpiration) {
            revert RedeemExpired();
        }

        uint256 redeemedQuantity = redeemedQuantities[tokenId][owner];
        uint256 balance = balanceOf(owner, tokenId);
        uint256 total = redeemedQuantity + quantity;

        if (total > balance) revert TokenQuantityAlreadyRedeemed();

        uint256 affiliateId = tokenOwnerAffiliates[tokenId][owner];

        if (affiliateId != 0) {
            address affiliateAddress = affiliateOwners[affiliateId];
            if (affiliateAddress == address(0)) revert InvalidAffiliateAddress();
            if (lockedBudget < fee) revert InsufficientBudget();
            lockedBudget -= fee;
            CurrencyTransferLib.transferCurrency(currencyAddress, address(this), affiliateAddress, fee);
        }

        redeemedQuantities[tokenId][owner] += quantity;
        redeemedTokenCount[tokenId] += quantity;

        emit CouponRedeemed(owner, tokenId, affiliateId != 0 ? affiliateOwners[affiliateId] : address(0), fee, address(this), block.timestamp, currencyAddress);
    }

    /// @notice Internal function to transfer the redemption fee to the affiliate
    /// @param affiliateAddress Address of the affiliate
    /// @param _fee Fee amount to transfer
    /// @param currency Address of the currency used
    function _transferFeeToAffiliate(address affiliateAddress, uint256 _fee, address currency) internal {
        if (_fee <= 0) revert FeeMustBeGreaterThanZero();

        if (currency == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != _fee) revert MustSendTotalFee();
        }

        CurrencyTransferLib.transferCurrency(currency, msg.sender, affiliateAddress, _fee);
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

    /// @notice Allows owner to withdraw excess budget
    /// @param amount Amount to withdraw
    function withdrawBudget(uint256 amount) public onlyOwner {
        uint256 availableTokens = maxSupply - redeemedTokenCount[tokenId];
        uint256 requiredBudget = availableTokens * fee;
        
        if (amount > lockedBudget) {
            revert InvalidWithdrawalAmount();
        }
        
        if (lockedBudget - amount < requiredBudget) {
            revert InsufficientBudget();
        }
        
        lockedBudget -= amount;
        CurrencyTransferLib.transferCurrency(currencyAddress, address(this), owner(), amount);
        
        emit BudgetWithdrawn(owner(), amount, address(this));
    }

    /// @notice Allows adding to the locked budget
    /// @dev Locks additional funds for affiliate payments
    function lockBudget(uint256 amount) public payable {
        if (currencyAddress == CurrencyTransferLib.NATIVE_TOKEN) {
            if (msg.value != amount) revert MustSendTotalFee();
        } else {
            CurrencyTransferLib.transferCurrency(currencyAddress, msg.sender, address(this), amount);
        }
        
        lockedBudget += amount;
        emit BudgetLocked(msg.sender, amount, address(this));
    }
} 