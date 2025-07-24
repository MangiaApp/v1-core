// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Campaign Contract - Multi-Coupon ERC1155 Management System
/// @notice This contract manages campaigns with multiple ERC1155 coupons, supporting lazy minting,
///         affiliate registration and tracking, budget management for affiliate payments, and
///         time-gated claiming/redemption mechanisms. Each campaign contract represents a project
///         that can contain multiple coupon types (tokenIds) with individual supply limits,
///         claiming periods, redemption windows, and fee structures.
/// @dev Built on OpenZeppelin's upgradeable contracts (ERC1155, Ownable) with custom affiliate
///      and budget management systems. Supports both native tokens and ERC20 for fee payments.
contract Campaign is Initializable, ERC1155Upgradeable, OwnableUpgradeable {
    // Constants
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    
    // Contract-level metadata URI (Project info stored on IPFS)
    string public projectMetadataURI;
    
    /// @dev Counter for tokenIds - starts at 0 and increments for each new coupon
    uint256 public nextTokenId;

    /// @dev Per-token data for each coupon
    struct TokenData {
        uint256 totalSupply;
        uint256 maxSupply;
        uint256 claimStart;
        uint256 claimEnd;
        uint256 redeemExpiration;
        uint256 fee;
        uint256 lockedBudget;
        uint256 tokensWithAffiliates;
        string uri;
        bool exists;
    }

    /// @dev Mapping from tokenId to its data
    mapping(uint256 => TokenData) public tokenData;

    /// @dev Mapping to track token affiliates for owners: tokenId => owner => affiliate
    mapping(uint256 => mapping(address => address)) public tokenOwnerAffiliates;

    /// @dev Mapping to track redeemed token quantities: tokenId => owner => quantity
    mapping(uint256 => mapping(address => uint256)) public redeemedQuantities;

    /// @dev Mapping to track the count of redeemed tokens: tokenId => count
    mapping(uint256 => uint256) public redeemedTokenCount;

    /// @dev Address of the currency used for fee payments
    address public currencyAddress;

    /// @dev Mapping to track if a wallet is an affiliate
    mapping(address => bool) public isAffiliate;

    /// @dev Mapping to track affiliate referrals per affiliate
    mapping(address => uint256) public affiliateReferrals;

    /// @dev Simple currency transfer function
    function _transferCurrency(address currency, address from, address to, uint256 amount) internal {
        if (currency == NATIVE_TOKEN) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "Native transfer failed");
        } else {
            if (from == address(this)) {
                IERC20(currency).transfer(to, amount);
            } else {
                IERC20(currency).transferFrom(from, to, amount);
            }
        }
    }

    /// @notice Event emitted when a new coupon (tokenId) is created
    event CouponCreated(
        uint256 indexed tokenId,
        string uri,
        uint256 maxSupply,
        uint256 claimStart,
        uint256 claimEnd,
        uint256 redeemExpiration,
        uint256 fee,
        uint256 lockedBudget,
        address contractAddress,
        uint256 timestamp
    );

    /// @notice Event emitted when project metadata is updated
    event ProjectMetadataUpdated(
        string metadataURI,
        address contractAddress,
        uint256 timestamp
    );

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
        uint256 timestamp,
        string _tokenURI
    );

    /// @notice Event emitted when budget is locked
    event BudgetLocked(address indexed locker, uint256 amount, address contractAddress);

    /// @notice Event emitted when budget is withdrawn
    event BudgetWithdrawn(address indexed withdrawer, uint256 amount, address contractAddress);

    /// @notice Errors for various invalid states
    error MaxSupplyMustBeGreaterThanZero();
    error AlreadyRegisteredAsAffiliate();
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
    error TokenDoesNotExist();
    error InvalidTokenId();

    /// @dev Constructor is disabled in favor of initialize
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev initialize replaces the constructor for upgradeable contracts
    /// @param _projectMetadataURI URI pointing to project metadata on IPFS
    /// @param _currencyAddress Address of the currency used for fee payments
    /// @param _owner Owner of the contract
    /// @param _firstCouponData Data for the first coupon to be created automatically
    function initialize(
        string memory _projectMetadataURI,
        address _currencyAddress,
        address _owner,
        FirstCouponData memory _firstCouponData
    ) public payable initializer {
        __ERC1155_init("");
        __Ownable_init(_owner);
        
        projectMetadataURI = _projectMetadataURI;
        currencyAddress = _currencyAddress;
        nextTokenId = 0;
        
        // Create the first coupon automatically
        _createCoupon(_firstCouponData);
        
        emit ProjectMetadataUpdated(
            _projectMetadataURI,
            address(this),
            block.timestamp
        );
    }

    /// @dev Struct for first coupon data to avoid stack too deep
    struct FirstCouponData {
        string uri;
        uint256 maxSupply;
        uint256 claimStart;
        uint256 claimEnd;
        uint256 redeemExpiration;
        uint256 fee;
        uint256 lockedBudget;
    }

    /// @dev Internal function to create a new coupon
    function _createCoupon(FirstCouponData memory _data) internal {
        if (_data.maxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }
        if (_data.claimStart >= _data.claimEnd) {
            revert ClaimStartMustBeBeforeClaimEnd();
        }
        if (_data.claimEnd >= _data.redeemExpiration) {
            revert ClaimEndMustBeBeforeRedeemExpiration();
        }
        if (_data.fee > 0 && _data.lockedBudget < _data.fee * _data.maxSupply) {
            revert InsufficientBudget();
        }
        
        // Handle budget transfer for the first coupon
        if (_data.lockedBudget > 0) {
            if (currencyAddress == NATIVE_TOKEN) {
                if (msg.value != _data.lockedBudget) {
                    revert MustSendTotalFee();
                }
            } else {
                if (msg.value > 0) {
                    revert MustSendTotalFee();
                }
                _transferCurrency(currencyAddress, owner(), address(this), _data.lockedBudget);
            }
        } else {
            if (msg.value > 0) {
                revert MustSendTotalFee();
            }
        }
        
        uint256 tokenId = nextTokenId;
        
        tokenData[tokenId] = TokenData({
            totalSupply: 0,
            maxSupply: _data.maxSupply,
            claimStart: _data.claimStart,
            claimEnd: _data.claimEnd,
            redeemExpiration: _data.redeemExpiration,
            fee: _data.fee,
            lockedBudget: _data.lockedBudget,
            tokensWithAffiliates: 0,
            uri: _data.uri,
            exists: true
        });
        
        nextTokenId++;
        
        emit CouponCreated(
            tokenId,
            _data.uri,
            _data.maxSupply,
            _data.claimStart,
            _data.claimEnd,
            _data.redeemExpiration,
            _data.fee,
            _data.lockedBudget,
            address(this),
            block.timestamp
        );
    }

    /// @notice Creates a new coupon (tokenId) in this project
    /// @param _uri The metadata URI for the coupon
    /// @param _maxSupply The maximum supply of tokens for this coupon
    /// @param _claimStart When claiming starts
    /// @param _claimEnd When claiming ends
    /// @param _redeemExpiration When redemption expires
    /// @param _fee Fee for redemption
    /// @param _lockedBudget Budget to lock for affiliate payments
    function createCoupon(
        string memory _uri,
        uint256 _maxSupply,
        uint256 _claimStart,
        uint256 _claimEnd,
        uint256 _redeemExpiration,
        uint256 _fee,
        uint256 _lockedBudget
    ) public payable onlyOwner returns (uint256) {
        FirstCouponData memory couponData = FirstCouponData({
            uri: _uri,
            maxSupply: _maxSupply,
            claimStart: _claimStart,
            claimEnd: _claimEnd,
            redeemExpiration: _redeemExpiration,
            fee: _fee,
            lockedBudget: _lockedBudget
        });
        
        uint256 currentTokenId = nextTokenId;
        _createCoupon(couponData);
        return currentTokenId;
    }

    /// @notice Updates the project metadata URI
    /// @param _metadataURI New project metadata URI
    function updateProjectMetadata(
        string memory _metadataURI
    ) public onlyOwner {
        projectMetadataURI = _metadataURI;
        
        emit ProjectMetadataUpdated(
            _metadataURI,
            address(this),
            block.timestamp
        );
    }

    /// @notice Returns the URI for a specific token
    /// @param _tokenId The token ID to get URI for
    /// @return URI string for the token
    function uri(uint256 _tokenId) public view override returns (string memory) {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        return tokenData[_tokenId].uri;
    }

    /// @notice Updates the URI for a specific token
    /// @param _tokenId The token ID to update
    /// @param _newURI New URI to set
    function setTokenURI(uint256 _tokenId, string memory _newURI) public onlyOwner {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        tokenData[_tokenId].uri = _newURI;
    }

    /// @dev Calculates the required budget for a specific token based on tokens with affiliates
    /// @param _tokenId The token ID to calculate budget for
    /// @return The amount of budget required to cover potential affiliate payments
    function calculateRequiredBudget(uint256 _tokenId) public view returns (uint256) {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        return tokenData[_tokenId].tokensWithAffiliates * tokenData[_tokenId].fee;
    }

    /// @notice Allows users to register as an affiliate
    /// @dev Emits `AffiliateRegistered` on successful registration
    function registerAffiliate() public {
        if (isAffiliate[msg.sender]) {
            revert AlreadyRegisteredAsAffiliate();
        }

        isAffiliate[msg.sender] = true;

        emit AffiliateRegistered(
            msg.sender,
            address(this),
            block.timestamp
        );
    }

    /// @notice Verifies if a user is eligible to claim tokens for a specific tokenId
    /// @param _tokenId The token ID to claim
    function verifyClaim(uint256 _tokenId) public view {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        if (block.timestamp < tokenData[_tokenId].claimStart) {
            revert ClaimNotStarted();
        }
        if (block.timestamp > tokenData[_tokenId].claimEnd) {
            revert ClaimExpired();
        }
    }

    /// @notice Allows users to claim tokens for a specific tokenId
    /// @param _tokenId The token ID to claim
    /// @param affiliateAddress The affiliate address associated with the claim (optional)
    /// @dev Emits `TokenClaimed` on successful claim
    function customClaim(uint256 _tokenId, address affiliateAddress) public {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        if (tokenData[_tokenId].totalSupply + 1 > tokenData[_tokenId].maxSupply) {
            revert ExceedsMaxSupply();
        }

        verifyClaim(_tokenId);

        if (affiliateAddress != address(0)) {
            if (!isAffiliate[affiliateAddress]) revert InvalidAffiliateAddress();
            if (affiliateAddress == msg.sender) revert InvalidAffiliateAddress();
            
            if (tokenData[_tokenId].lockedBudget < tokenData[_tokenId].fee) revert InsufficientBudget();
            
            // Increment affiliate referrals and tokens with affiliates
            affiliateReferrals[affiliateAddress] += 1;
            tokenData[_tokenId].tokensWithAffiliates += 1;
            
            // Store the affiliate address
            tokenOwnerAffiliates[_tokenId][msg.sender] = affiliateAddress;
        }

        _mint(msg.sender, _tokenId, 1, "");
        tokenData[_tokenId].totalSupply += 1;

        emit TokenClaimed(
            msg.sender, 
            msg.sender, 
            _tokenId, 
            affiliateAddress, 
            address(this), 
            block.timestamp,
            tokenData[_tokenId].uri
        );
    }

    /// @notice Allows the contract owner to redeem coupons for token holders
    /// @param _tokenId The token ID to redeem
    /// @param tokenOwner Address of the token holder
    /// @dev Emits `CouponRedeemed` on successful redemption
    function redeemCoupon(uint256 _tokenId, address tokenOwner) public onlyOwner {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        if (balanceOf(tokenOwner, _tokenId) <= 0) revert OwnerDoesNotOwnToken();
        if (block.timestamp > tokenData[_tokenId].redeemExpiration) {
            revert RedeemExpired();
        }

        uint256 redeemedQuantity = redeemedQuantities[_tokenId][tokenOwner];
        
        if (redeemedQuantity > 0) revert TokenQuantityAlreadyRedeemed();

        address affiliateAddress = tokenOwnerAffiliates[_tokenId][tokenOwner];

        if (affiliateAddress != address(0)) {
            if (!isAffiliate[affiliateAddress]) revert InvalidAffiliateAddress();
            if (tokenData[_tokenId].lockedBudget < tokenData[_tokenId].fee) revert InsufficientBudget();
            
            // Decrement tokens with affiliates and locked budget
            tokenData[_tokenId].tokensWithAffiliates -= 1;
            tokenData[_tokenId].lockedBudget -= tokenData[_tokenId].fee;
            
            // Transfer fee to affiliate
            _transferCurrency(currencyAddress, address(this), affiliateAddress, tokenData[_tokenId].fee);
        }

        redeemedQuantities[_tokenId][tokenOwner] = 1;
        redeemedTokenCount[_tokenId] += 1;

        emit CouponRedeemed(tokenOwner, _tokenId, affiliateAddress, tokenData[_tokenId].fee, address(this), block.timestamp, currencyAddress);
    }

    /// @notice Allows users to lock additional budget for affiliate payments for a specific token
    /// @param _tokenId The token ID to lock budget for
    /// @param amount Amount of budget to lock
    function lockBudget(uint256 _tokenId, uint256 amount) public payable {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        
        if (currencyAddress == NATIVE_TOKEN) {
            if (msg.value != amount) revert MustSendTotalFee();
        } else {
            if (msg.value > 0) revert MustSendTotalFee();
            _transferCurrency(currencyAddress, msg.sender, address(this), amount);
        }
        
        tokenData[_tokenId].lockedBudget += amount;
        emit BudgetLocked(msg.sender, amount, address(this));
    }

    /// @notice Allows the owner to withdraw locked budget for a specific token
    /// @param _tokenId The token ID to withdraw budget from
    /// @param amount Amount of budget to withdraw
    function withdrawBudget(uint256 _tokenId, uint256 amount) public onlyOwner {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        if (amount > tokenData[_tokenId].lockedBudget) revert InvalidWithdrawalAmount();
        
        // If redemption has expired, allow withdrawing any amount
        if (block.timestamp > tokenData[_tokenId].redeemExpiration) {
            tokenData[_tokenId].lockedBudget -= amount;
            
            if (currencyAddress == NATIVE_TOKEN) {
                _transferCurrency(currencyAddress, address(this), msg.sender, amount);
            } else {
                // Implement currency transfer logic here
            }
            
            emit BudgetWithdrawn(msg.sender, amount, address(this));
            return;
        }
        
        // Calculate required budget
        uint256 requiredBudget = calculateRequiredBudget(_tokenId);
        
        // Ensure sufficient budget remains after withdrawal
        if (tokenData[_tokenId].lockedBudget - amount < requiredBudget) {
            revert InsufficientBudget();
        }
        
        tokenData[_tokenId].lockedBudget -= amount;
        
        if (currencyAddress == NATIVE_TOKEN) {
            _transferCurrency(currencyAddress, address(this), msg.sender, amount);
        } else {
            // Implement currency transfer logic here
        }
        
        emit BudgetWithdrawn(msg.sender, amount, address(this));
    }
    
    /// @notice Returns the available budget that can be withdrawn for a specific token
    /// @param _tokenId The token ID to check available budget for
    /// @return Amount of budget available for withdrawal
    function getAvailableBudget(uint256 _tokenId) public view returns (uint256) {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        
        uint256 requiredBudget = calculateRequiredBudget(_tokenId);
        
        if (requiredBudget >= tokenData[_tokenId].lockedBudget) {
            return 0;
        }
        
        return tokenData[_tokenId].lockedBudget - requiredBudget;
    }

    /// @notice Gets the total number of coupons (tokenIds) in this project
    /// @return The number of coupons created
    function getTotalCoupons() public view returns (uint256) {
        return nextTokenId;
    }

    /// @notice Gets comprehensive data for a specific token
    /// @param _tokenId The token ID to get data for
    /// @return tokenData The complete token data struct
    function getTokenData(uint256 _tokenId) public view returns (TokenData memory) {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        return tokenData[_tokenId];
    }

    /// @notice Only for testing - allows setting the locked budget directly
    function setLockedBudgetForTesting(uint256 _tokenId, uint256 _newBudget) public onlyOwner {
        if (!tokenData[_tokenId].exists) {
            revert TokenDoesNotExist();
        }
        tokenData[_tokenId].lockedBudget = _newBudget;
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}
}