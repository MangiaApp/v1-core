// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@thirdweb-dev/contracts/base/ERC1155Drop.sol";
 
contract MyNFT is ERC1155Drop {
    uint256 public nextAffiliateId = 1;
    mapping(uint256 => address) public affiliateOwners; // Asocia un ID de afiliado a una dirección
    mapping(address => uint256) public affiliateIDs;
    mapping(uint256 => uint256) public nftToAffiliate;

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        address _primarySaleRecipient
    )
        ERC1155Drop(
            _defaultAdmin,
            _name,
            _symbol,
            _royaltyRecipient,
            _royaltyBps,
            _primarySaleRecipient
        )
    {}

    function registerAffiliate() public {
        require(affiliateIDs[msg.sender] == 0, "Sender is already registered as affiliate");
        uint256 newAffiliateId = nextAffiliateId++;
        affiliateOwners[newAffiliateId] = msg.sender;
        affiliateIDs[msg.sender] = newAffiliateId;
    }

    function getAffiliateId(address _user) public view returns (uint256) {
        return affiliateIDs[_user];
    }
}
 
