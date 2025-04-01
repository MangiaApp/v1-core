// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./LazyMint.sol";

/// @title LazyMintFactory
/// @notice This contract serves as a factory to deploy new instances of the LazyMint contract.
/// @dev Allows users to create LazyMint contracts with a specified URI and max supply.
contract LazyMintFactory {

    uint256 public constant TOKEN_ID = 0;
    uint256 constant public FEE = 1000;

    // A reserved value to indicate that no project ID was provided
    uint256 public constant NO_PROJECT_ID = type(uint256).max;

    /// @notice Project struct to manage multiple coupons
    /// @param name Name of the project
    /// @param owner Address of the project owner
    /// @param coupons Array of coupon addresses belonging to this project
    /// @param createdAt Timestamp when the project was created
    struct Project {
        string name;
        address owner;
        address[] coupons;
        uint256 createdAt;
    }

    mapping(uint256 => Project) public projects;
    mapping(address => uint256) public couponToProject;
    uint256 public projectCount;

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed owner,
        string name
    );

    event ProjectUpdated(
        uint256 indexed projectId,
        address indexed owner,
        string name
    );

    event LazyMintDeployed(
        address indexed creator,
        address lazyMintAddress,
        string uri,
        uint256 maxSupply,
        uint256 claimStart,
        uint256 claimEnd,
        uint256 redeemExpiration,
        uint256 lockedBudget,
        address currencyAddress,
        uint256 tokenId,
        uint256 fee,
        uint256 indexed projectId
    );

    error MaxSupplyMustBeGreaterThanZero();
    error ProjectDoesNotExist();
    error NotProjectOwner();

    /// @notice Creates a new project
    /// @param _name Name of the project
    /// @return The ID of the newly created project
    function createProject(string memory _name) external returns (uint256) {
        uint256 projectId = projectCount;
        Project storage project = projects[projectId];
        project.name = _name;
        project.owner = msg.sender;
        project.createdAt = block.timestamp;
        projectCount++;
        emit ProjectCreated(projectId, msg.sender, _name);
        return projectId;
    }

    /// @notice Updates an existing project's name
    /// @param _projectId ID of the project to update
    /// @param _name New name for the project
    function updateProject(uint256 _projectId, string memory _name) external {
        if (_projectId >= projectCount) {
            revert ProjectDoesNotExist();
        }
        if (projects[_projectId].owner != msg.sender) {
            revert NotProjectOwner();
        }
        Project storage project = projects[_projectId];
        project.name = _name;
        emit ProjectUpdated(_projectId, msg.sender, _name);
    }

    /// @notice Internal function to create a project and return its ID
    /// @param _name Name of the project
    /// @return The ID of the newly created project
    function _createProject(string memory _name) internal returns (uint256) {
        uint256 projectId = projectCount;
        Project storage project = projects[projectId];
        project.name = _name;
        project.owner = msg.sender;
        project.createdAt = block.timestamp;
        projectCount++;
        emit ProjectCreated(projectId, msg.sender, _name);
        return projectId;
    }

    /// @notice Deploys a new LazyMint contract with the specified parameters.
    /// @param _projectId The ID of the project this coupon belongs to (pass NO_PROJECT_ID if no ID is provided)
    /// @param _projectName If _projectId equals NO_PROJECT_ID, this will be used as the name for a new project
    /// @param _uri The metadata URI for the LazyMint contract.
    /// @param _maxSupply The maximum supply of tokens allowed in the LazyMint contract.
    /// @return The address of the newly deployed LazyMint contract.
    function createLazyMint(
        uint256 _projectId,
        string memory _projectName,
        string memory _uri, 
        uint256 _maxSupply,  
        uint256 _claimStart,
        uint256 _claimEnd,
        uint256 _redeemExpiration,
        uint256 _lockedBudget,
        address _currencyAddress
    ) external returns (address) {
        uint256 projectId;

        // Use NO_PROJECT_ID as the sentinel for auto-creation.
        if (_projectId == NO_PROJECT_ID) {
            projectId = _createProject(_projectName);
        } else {
            // Validate that the project exists
            if (_projectId >= projectCount) {
                revert ProjectDoesNotExist();
            }
            // Validate caller is the project owner
            if (projects[_projectId].owner != msg.sender) {
                revert NotProjectOwner();
            }
            projectId = _projectId;
        }
        
        if (_maxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }

        // Deploy the LazyMint contract
        LazyMint newLazyMint = new LazyMint(
            _uri, 
            _maxSupply, 
            _claimStart,
            _claimEnd,
            _redeemExpiration, 
            _lockedBudget, 
            _currencyAddress, 
            TOKEN_ID, 
            FEE
        );
        newLazyMint.transferOwnership(msg.sender);
        
        address lazyMintAddress = address(newLazyMint);
        projects[projectId].coupons.push(lazyMintAddress);
        couponToProject[lazyMintAddress] = projectId;
        
        emit LazyMintDeployed(
            msg.sender, 
            lazyMintAddress, 
            _uri, 
            _maxSupply, 
            _claimStart,
            _claimEnd,
            _redeemExpiration, 
            _lockedBudget, 
            _currencyAddress, 
            TOKEN_ID, 
            FEE,
            projectId
        );

        return lazyMintAddress;
    }
    
    /// @notice Gets all coupons for a project
    /// @param _projectId The ID of the project
    /// @return Array of coupon addresses belonging to the project
    function getProjectCoupons(uint256 _projectId) external view returns (address[] memory) {
        if (_projectId >= projectCount) {
            revert ProjectDoesNotExist();
        }
        return projects[_projectId].coupons;
    }
    
    /// @notice Gets the project ID for a coupon
    /// @param _couponAddress Address of the coupon
    /// @return Project ID the coupon belongs to
    function getCouponProject(address _couponAddress) external view returns (uint256) {
        return couponToProject[_couponAddress];
    }
}