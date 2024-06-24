// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@thirdweb-dev/contracts/base/ERC1155LazyMint.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

contract PushColaLazyMint is ERC1155LazyMint {
    uint256 public nextAffiliateId = 1;
    uint256 public constant FEE = 0.001 ether;
    mapping(uint256 => address) public affiliateOwners; // Associates an affiliate ID with an address
    mapping(address => uint256) public affiliateIDs;
    mapping(uint256 => mapping(address => uint256)) public tokenOwnerAffiliates; // Maps token ID and owner to an affiliate ID
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    mapping(uint256 => mapping(address => uint256)) public redeemedQuantities;

    event CouponRedeemed(address indexed owner, uint256 indexed tokenId, uint256 affiliateId, uint256 fee);

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps
    ) ERC1155LazyMint(_defaultAdmin, _name, _symbol, _royaltyRecipient, _royaltyBps) {}

    function setTokenOwnerAffiliate(uint256 tokenId, address owner, uint256 affiliateId) public {
        tokenOwnerAffiliates[tokenId][owner] = affiliateId;
    }

    function registerAffiliate() public {
        require(affiliateIDs[msg.sender] == 0, "Sender is already registered as affiliate");
        uint256 newAffiliateId = nextAffiliateId++;

        affiliateOwners[newAffiliateId] = msg.sender;
        affiliateIDs[msg.sender] = newAffiliateId;
    }

    function getAffiliateIdByAddress(address _user) public view returns (uint256) {
        return affiliateIDs[_user];
    }

    function getAffiliateIdByTokenAndOwner(uint256 tokenId, address owner) public view returns (uint256) {
        return tokenOwnerAffiliates[tokenId][owner];
    }

    function getAffiliateAddressByTokenId(uint256 tokenId) public view returns (address) {
        uint256 affiliateId = tokenOwnerAffiliates[tokenId][msg.sender]; // Retrieve the affiliate ID associated with the token ID and owner
        require(affiliateId != 0, "Token ID and owner have no affiliate"); // Ensure that the token and owner have an affiliate associated with it

        address affiliateAddress = affiliateOwners[affiliateId]; // Retrieve the affiliate address using the affiliate ID
        require(affiliateAddress != address(0), "Affiliate ID does not have an associated address"); // Ensure the affiliate ID is valid

        return affiliateAddress;
    }

    function verifyClaim(address _claimer, uint256 _tokenId, uint256 _quantity) public view virtual override {
        require(this.balanceOf(_claimer, _tokenId) < 1, "Token already claimed by this wallet");
    }

    function _transferTokensOnClaim(
        address _receiver,
        uint256 _tokenId,
        uint256 _quantity
    ) internal virtual override {
        _mint(_receiver, _tokenId, _quantity, "");
    }

    function customClaim(
        address _receiver,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 affiliateId
    ) public payable nonReentrant {
        require(_tokenId < nextTokenIdToMint(), "invalid id");
        verifyClaim(msg.sender, _tokenId, _quantity); // Add your claim verification logic by overriding this function.
        address affiliateAddress = affiliateOwners[affiliateId]; // Retrieve the affiliate address using the affiliate ID
        require(affiliateAddress != address(0), "Affiliate ID does not have an associated address");
        tokenOwnerAffiliates[_tokenId][_receiver] = affiliateId;

        _transferTokensOnClaim(_receiver, _tokenId, _quantity); // Mints tokens. Apply any state updates by overriding this function.
        emit TokensClaimed(msg.sender, _receiver, _tokenId, _quantity);
    }

    function claim(
        address _receiver,
        uint256 _tokenId,
        uint256 _quantity,
        uint256 affiliateId
    ) public payable nonReentrant {
        require(_tokenId < nextTokenIdToMint(), "invalid id");
        verifyClaim(msg.sender, _tokenId, _quantity); // Add your claim verification logic by overriding this function.
        address affiliateAddress = affiliateOwners[affiliateId]; // Retrieve the affiliate address using the affiliate ID
        require(affiliateAddress != address(0), "Affiliate ID does not have an associated address");
        tokenOwnerAffiliates[_tokenId][_receiver] = affiliateId;

        _transferTokensOnClaim(_receiver, _tokenId, _quantity); // Mints tokens. Apply any state updates by overriding this function.


        emit TokensClaimed(msg.sender, _receiver, _tokenId, _quantity);
    }


    function redeemCoupon(
        uint256 tokenId,
        address owner,
        address currency,
        uint256 quantity
    ) public payable nonReentrant {
        require(this.balanceOf(owner, tokenId) > 0, "Owner does not own this token");

        require(redeemedQuantities[tokenId][owner] + quantity <= this.balanceOf(owner, tokenId), "Token quantity already redeemed");


        uint256 affiliateId = tokenOwnerAffiliates[tokenId][owner];
        require(affiliateId != 0, "No affiliate associated with this token and owner");

        address affiliateAddress = affiliateOwners[affiliateId];
        require(affiliateAddress != address(0), "Invalid affiliate address");
        redeemedQuantities[tokenId][owner] += quantity;

        _transferFeeToAffiliate(affiliateAddress, FEE, currency);

        emit CouponRedeemed(owner, tokenId, affiliateId, FEE);
    }

    function _transferFeeToAffiliate(
        address affiliateAddress,
        uint256 fee,
        address currency
    ) internal {
        require(fee > 0, "Fee must be greater than zero");

        if (currency == CurrencyTransferLib.NATIVE_TOKEN) {
            require(msg.value == fee, "Must send total fee");
        }

        CurrencyTransferLib.transferCurrency(
            currency,
            msg.sender,
            affiliateAddress,
            fee
        );
    }
}
