// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./Coupon.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenFactory
/// @notice This contract serves as a factory to deploy new instances of the Coupon contract using clones.
/// @dev Uses minimal proxy pattern to deploy new Coupon contracts to save on gas and reduce bytecode size.
///      Each deployed contract represents a project with multiple coupons.
contract TokenFactory is Ownable {

    // Implementation of Coupon contract to clone
    address public implementation;

    event ImplementationUpdated(
        address indexed oldImplementation, 
        address indexed newImplementation
    );

    event ProjectDeployed(
        address indexed creator,
        address indexed projectAddress,
        string projectMetadataURI,
        string firstCouponUri,
        uint256 firstCouponMaxSupply,
        uint256 firstCouponClaimStart,
        uint256 firstCouponClaimEnd,
        uint256 firstCouponRedeemExpiration,
        uint256 firstCouponFee,
        uint256 firstCouponLockedBudget,
        address currencyAddress,
        uint256 timestamp
    );

    error ImplementationNotSet();
    error MaxSupplyMustBeGreaterThanZero();
    error FeeMustBeSetWithBudget();

    /// @notice Constructor
    /// @param _implementation Address of the Coupon implementation to clone
    constructor(address _implementation) Ownable(msg.sender) {
        implementation = _implementation;
        emit ImplementationUpdated(address(0), _implementation);
    }

    /// @notice Updates the implementation address
    /// @param _newImplementation New implementation address
    function updateImplementation(address _newImplementation) external onlyOwner {
        address oldImplementation = implementation;
        implementation = _newImplementation;
        emit ImplementationUpdated(oldImplementation, _newImplementation);
    }

    /// @notice Predicts the address where a new Coupon contract will be deployed
    /// @param _salt A unique salt for deterministic deployment
    /// @return The predicted address of the Coupon contract
    function predictProjectAddress(
        bytes32 _salt
    ) public view returns (address) {
        return Clones.predictDeterministicAddress(
            implementation,
            _salt,
            address(this)
        );
    }

    /// @notice Deploys a new project (Coupon contract) with specified parameters
    /// @param _projectMetadataURI URI pointing to project metadata on IPFS
    /// @param _currencyAddress Address of the currency used for fee payments
    /// @param _firstCouponUri The metadata URI for the first coupon
    /// @param _firstCouponMaxSupply The maximum supply of the first coupon
    /// @param _firstCouponClaimStart When claiming starts for the first coupon
    /// @param _firstCouponClaimEnd When claiming ends for the first coupon
    /// @param _firstCouponRedeemExpiration When redemption expires for the first coupon
    /// @param _firstCouponFee Fee for the first coupon redemption
    /// @param _firstCouponLockedBudget Budget to lock for the first coupon
    /// @param _salt A unique salt for deterministic deployment
    /// @return The address of the newly deployed project contract
    function createProject(
        string memory _projectMetadataURI,
        address _currencyAddress,
        string memory _firstCouponUri,
        uint256 _firstCouponMaxSupply,
        uint256 _firstCouponClaimStart,
        uint256 _firstCouponClaimEnd,
        uint256 _firstCouponRedeemExpiration,
        uint256 _firstCouponFee,
        uint256 _firstCouponLockedBudget,
        bytes32 _salt
    ) external payable returns (address) {
        if (implementation == address(0)) {
            revert ImplementationNotSet();
        }
        
        if (_firstCouponMaxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }
        
        // Require fee to be set if budget is provided
        if (_firstCouponLockedBudget > 0 && _firstCouponFee == 0) {
            revert FeeMustBeSetWithBudget();
        }

        // Deploy the clone deterministically
        address projectAddress = Clones.cloneDeterministic(implementation, _salt);
        
        // Prepare first coupon data
        Coupon.FirstCouponData memory firstCouponData = Coupon.FirstCouponData({
            uri: _firstCouponUri,
            maxSupply: _firstCouponMaxSupply,
            claimStart: _firstCouponClaimStart,
            claimEnd: _firstCouponClaimEnd,
            redeemExpiration: _firstCouponRedeemExpiration,
            fee: _firstCouponFee,
            lockedBudget: _firstCouponLockedBudget
        });
        
        // Initialize the clone with ETH if needed
        Coupon(payable(projectAddress)).initialize{value: msg.value}(
            _projectMetadataURI,
            _currencyAddress,
            msg.sender, // Owner
            firstCouponData
        );
        
        emit ProjectDeployed(
            msg.sender,
            projectAddress,
            _projectMetadataURI,
            _firstCouponUri,
            _firstCouponMaxSupply,
            _firstCouponClaimStart,
            _firstCouponClaimEnd,
            _firstCouponRedeemExpiration,
            _firstCouponFee,
            _firstCouponLockedBudget,
            _currencyAddress,
            block.timestamp
        );

        return projectAddress;
    }
} 