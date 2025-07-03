// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MangiaCampaign1155
 * @dev ERC1155 contract for Mangia marketing campaigns
 * Each token ID represents a unique marketing campaign created by a brand
 */
contract MangiaCampaign1155 is ERC1155, Ownable {
    using Strings for uint256;

    // Campaign structure
    struct Campaign {
        uint256 totalBudgetInCredits;
        uint256 minCreditsPerParticipant;
        uint256 expirationTimestamp;
        bool active;
    }

    // Contract-level metadata URI (brand info)
    string private _contractURI;
    
    // Campaign counter for generating unique IDs
    uint256 public nextCampaignId;
    
    // Mappings
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => string) private tokenURIs;
    mapping(address => mapping(uint256 => bool)) public hasParticipated;
    mapping(uint256 => uint256) private _totalSupply;
    
    // Events
    event CampaignCreated(uint256 indexed campaignId, uint256 totalBudget, uint256 minCredits, uint256 expiration);
    event ParticipationClaimed(address indexed participant, uint256 indexed campaignId, uint256 timestamp);
    event CampaignDeactivated(uint256 indexed campaignId);

    /**
     * @dev Constructor
     * @param initialContractURI Brand-level metadata URI
     * @param owner Address that will own this contract
     */
    constructor(
        string memory initialContractURI,
        address owner
    ) ERC1155("") Ownable(owner) {
        _contractURI = initialContractURI;
        nextCampaignId = 1; // Start campaign IDs at 1
    }

    /**
     * @dev Returns the contract-level metadata URI (brand info)
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Returns the URI for a specific token ID (campaign)
     * @param id The token ID to query
     */
    function uri(uint256 id) public view override returns (string memory) {
        return tokenURIs[id];
    }

    /**
     * @dev Creates a new campaign
     * @param campaignURI Metadata URI for this campaign
     * @param totalBudgetInCredits Total budget in platform credits
     * @param minCreditsPerParticipant Minimum credits per participant
     * @param expirationTimestamp Unix timestamp when campaign expires
     */
    function createCampaign(
        string calldata campaignURI,
        uint256 totalBudgetInCredits,
        uint256 minCreditsPerParticipant,
        uint256 expirationTimestamp
    ) external onlyOwner returns (uint256) {
        require(totalBudgetInCredits > 0, "Budget must be greater than 0");
        require(minCreditsPerParticipant > 0, "Min credits must be greater than 0");
        require(expirationTimestamp > block.timestamp, "Expiration must be in future");
        require(totalBudgetInCredits >= minCreditsPerParticipant, "Budget too small for min credits");

        uint256 campaignId = nextCampaignId++;
        
        campaigns[campaignId] = Campaign({
            totalBudgetInCredits: totalBudgetInCredits,
            minCreditsPerParticipant: minCreditsPerParticipant,
            expirationTimestamp: expirationTimestamp,
            active: true
        });
        
        tokenURIs[campaignId] = campaignURI;
        
        emit CampaignCreated(campaignId, totalBudgetInCredits, minCreditsPerParticipant, expirationTimestamp);
        
        return campaignId;
    }

    /**
     * @dev Calculates maximum participants for a campaign
     * @param campaignId The campaign ID to query
     */
    function maxParticipants(uint256 campaignId) public view returns (uint256) {
        Campaign memory campaign = campaigns[campaignId];
        if (campaign.minCreditsPerParticipant == 0) return 0;
        return campaign.totalBudgetInCredits / campaign.minCreditsPerParticipant;
    }

    /**
     * @dev Returns the current number of participants for a campaign
     * @param campaignId The campaign ID to query
     */
    function totalParticipants(uint256 campaignId) public view returns (uint256) {
        return _totalSupply[campaignId];
    }

    /**
     * @dev Allows a creator to claim participation in a campaign
     * @param campaignId The campaign ID to participate in
     */
    function claimParticipation(uint256 campaignId) external {
        Campaign storage campaign = campaigns[campaignId];
        
        // Validation checks
        require(campaign.active, "Campaign is not active");
        require(block.timestamp < campaign.expirationTimestamp, "Campaign has expired");
        require(!hasParticipated[msg.sender][campaignId], "Already participated in this campaign");
        require(totalParticipants(campaignId) < maxParticipants(campaignId), "Campaign participation limit reached");
        
        // Record participation
        hasParticipated[msg.sender][campaignId] = true;
        _totalSupply[campaignId]++;
        
        // Mint NFT to participant
        _mint(msg.sender, campaignId, 1, "");
        
        emit ParticipationClaimed(msg.sender, campaignId, block.timestamp);
    }

    /**
     * @dev Sets the URI for a specific campaign (owner only)
     * @param id Campaign ID
     * @param newUri New metadata URI
     */
    function setURI(uint256 id, string calldata newUri) external onlyOwner {
        require(campaigns[id].totalBudgetInCredits > 0, "Campaign does not exist");
        tokenURIs[id] = newUri;
        emit URI(newUri, id);
    }

    /**
     * @dev Sets the contract-level URI (owner only)
     * @param newUri New contract metadata URI
     */
    function setContractURI(string calldata newUri) external onlyOwner {
        _contractURI = newUri;
    }

    /**
     * @dev Deactivates a campaign (owner only)
     * @param id Campaign ID to deactivate
     */
    function deactivateCampaign(uint256 id) external onlyOwner {
        require(campaigns[id].totalBudgetInCredits > 0, "Campaign does not exist");
        campaigns[id].active = false;
        emit CampaignDeactivated(id);
    }

    /**
     * @dev Returns campaign information
     * @param campaignId The campaign ID to query
     */
    function getCampaignInfo(uint256 campaignId) external view returns (
        uint256 totalBudgetInCredits,
        uint256 minCreditsPerParticipant,
        uint256 currentParticipants,
        uint256 expirationTimestamp,
        bool active,
        uint256 maxParticipantsAllowed
    ) {
        Campaign memory campaign = campaigns[campaignId];
        return (
            campaign.totalBudgetInCredits,
            campaign.minCreditsPerParticipant,
            totalParticipants(campaignId),
            campaign.expirationTimestamp,
            campaign.active,
            maxParticipants(campaignId)
        );
    }

    /**
     * @dev Checks if a campaign is still accepting participants
     * @param campaignId The campaign ID to check
     */
    function isCampaignActive(uint256 campaignId) external view returns (bool) {
        Campaign memory campaign = campaigns[campaignId];
        return campaign.active && 
               block.timestamp < campaign.expirationTimestamp &&
               totalParticipants(campaignId) < maxParticipants(campaignId);
    }
}