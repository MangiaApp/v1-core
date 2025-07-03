// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./MangiaCampaign1155.sol";

/**
 * @title MangiaFactory
 * @dev Factory contract for deploying Mangia marketing campaign contracts
 * Allows brands to create and manage their own campaign contracts
 */
contract MangiaCampaignFactory {
    
    // Brand metadata structure
    struct BrandInfo {
        uint256 createdAt;
    }
    
    // Mappings
    mapping(address => address[]) public campaignsByBrand;
    mapping(address => BrandInfo) public brandInfo;
    mapping(address => bool) public isMangiaContract;
    
    // Arrays for enumeration
    address[] public allCampaigns;
    address[] public allBrands;
    
    // Events
    event CampaignCreated(
        address indexed campaignAddress,
        address indexed brandOwner,
        uint256 timestamp
    );
    
    event ParticipationClaimed(
        address indexed campaign,
        address indexed creator,
        uint256 indexed campaignId
    );
    
    event BrandRegistered(
        address indexed brandOwner,
        uint256 timestamp
    );

    /**
     * @dev Creates a new campaign contract for a brand
     * @param contractURI Brand-level metadata URI
     * @param initialCampaignURI Initial campaign metadata URI
     * @param totalBudgetInCredits Total budget in platform credits
     * @param minCreditsPerParticipant Minimum credits per participant
     * @param expirationTimestamp Unix timestamp when campaign expires
     */
    function createCampaign(
        string calldata contractURI,
        string calldata initialCampaignURI,
        uint256 totalBudgetInCredits,
        uint256 minCreditsPerParticipant,
        uint256 expirationTimestamp
    ) external returns (address) {
        // Input validation
        require(bytes(contractURI).length > 0, "Contract URI cannot be empty");
        require(bytes(initialCampaignURI).length > 0, "Campaign URI cannot be empty");
        require(totalBudgetInCredits > 0, "Budget must be greater than 0");
        require(minCreditsPerParticipant > 0, "Min credits must be greater than 0");
        require(expirationTimestamp > block.timestamp, "Expiration must be in future");
        
        // Deploy new campaign contract with factory as temporary owner
        MangiaCampaign1155 newCampaign = new MangiaCampaign1155(
            contractURI,
            address(this)  // Factory is temporary owner
        );
        
        address campaignAddress = address(newCampaign);
        
        // Store brand info if first campaign
        if (campaignsByBrand[msg.sender].length == 0) {
            brandInfo[msg.sender] = BrandInfo({
                createdAt: block.timestamp
            });
            allBrands.push(msg.sender);
            emit BrandRegistered(msg.sender, block.timestamp);
        }
        
        // Track the campaign
        campaignsByBrand[msg.sender].push(campaignAddress);
        allCampaigns.push(campaignAddress);
        isMangiaContract[campaignAddress] = true;
        
        // Create the initial campaign in the new contract
        newCampaign.createCampaign(
            initialCampaignURI,
            totalBudgetInCredits,
            minCreditsPerParticipant,
            expirationTimestamp
        );
        
        // Transfer ownership to the actual brand owner
        newCampaign.transferOwnership(msg.sender);
        
        emit CampaignCreated(campaignAddress, msg.sender, block.timestamp);
        
        return campaignAddress;
    }
    
    /**
     * @dev Gets all campaigns deployed by a specific brand
     * @param brand Address of the brand owner
     */
    function getCampaignsByBrand(address brand) external view returns (address[] memory) {
        return campaignsByBrand[brand];
    }
    
    /**
     * @dev Gets the total number of campaigns deployed by a brand
     * @param brand Address of the brand owner
     */
    function getBrandCampaignCount(address brand) external view returns (uint256) {
        return campaignsByBrand[brand].length;
    }
    
    /**
     * @dev Gets brand information
     * @param brand Address of the brand owner
     */
    function getBrandInfo(address brand) external view returns (
        uint256 createdAt,
        uint256 campaignCount
    ) {
        BrandInfo memory info = brandInfo[brand];
        return (
            info.createdAt,
            campaignsByBrand[brand].length
        );
    }
    
    /**
     * @dev Gets all deployed campaigns
     */
    function getAllCampaigns() external view returns (address[] memory) {
        return allCampaigns;
    }
    
    /**
     * @dev Gets all registered brands
     */
    function getAllBrands() external view returns (address[] memory) {
        return allBrands;
    }
    
    /**
     * @dev Gets the total number of campaigns deployed
     */
    function getTotalCampaignCount() external view returns (uint256) {
        return allCampaigns.length;
    }
    
    /**
     * @dev Gets the total number of registered brands
     */
    function getTotalBrandCount() external view returns (uint256) {
        return allBrands.length;
    }
    
    /**
     * @dev Updates brand registration timestamp (only brand owner)
     * Note: Brand metadata should be updated via contractURI
     */
    function updateBrandRegistration() external {
        require(campaignsByBrand[msg.sender].length > 0, "Brand not registered");
        // Brand metadata is stored in contractURI, only update timestamp if needed
        brandInfo[msg.sender].createdAt = block.timestamp;
    }
    
    /**
     * @dev Verifies if an address is a Mangia campaign contract
     * @param contractAddress Address to verify
     */
    function isMangiaContract_(address contractAddress) external view returns (bool) {
        return isMangiaContract[contractAddress];
    }
    
    /**
     * @dev Gets campaign statistics
     * @param campaignAddress Address of the campaign contract
     * @param campaignId ID of the campaign within the contract
     */
    function getCampaignStats(address campaignAddress, uint256 campaignId) 
        external 
        view 
        returns (
            uint256 totalBudget,
            uint256 minCredits,
            uint256 totalParticipants,
            uint256 maxParticipants,
            uint256 expiration,
            bool active,
            bool isActive
        ) 
    {
        require(isMangiaContract[campaignAddress], "Not a Mangia contract");
        
        MangiaCampaign1155 campaign = MangiaCampaign1155(campaignAddress);
        
        (
            totalBudget,
            minCredits,
            totalParticipants,
            expiration,
            active,
            maxParticipants
        ) = campaign.getCampaignInfo(campaignId);
        
        isActive = campaign.isCampaignActive(campaignId);
        
        return (
            totalBudget,
            minCredits,
            totalParticipants,
            maxParticipants,
            expiration,
            active,
            isActive
        );
    }
    
    /**
     * @dev Emergency function to emit participation events (for indexing)
     * This would typically be called by the campaign contracts
     * @param campaign Address of the campaign contract
     * @param creator Address of the creator
     * @param campaignId ID of the campaign
     */
    function emitParticipationClaimed(
        address campaign,
        address creator,
        uint256 campaignId
    ) external {
        require(isMangiaContract[msg.sender], "Only Mangia contracts can call this");
        emit ParticipationClaimed(campaign, creator, campaignId);
    }
}
