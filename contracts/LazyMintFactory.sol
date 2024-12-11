// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LazyMint.sol";

/// @title LazyMintFactory
/// @notice This contract serves as a factory to deploy new instances of the LazyMint contract.
/// @dev Allows users to create LazyMint contracts with a specified URI and max supply.
contract LazyMintFactory {
    /// @notice Event emitted when a new LazyMint contract is deployed.
    /// @param creator Address of the user who created the LazyMint contract.
    /// @param lazyMintAddress Address of the newly deployed LazyMint contract.
    /// @param uri URI for the metadata of the deployed LazyMint contract.
    /// @param maxSupply Maximum supply of tokens for the deployed LazyMint contract.
    event LazyMintDeployed(
        address indexed creator,
        address lazyMintAddress,
        string uri,
        uint256 maxSupply
    );

    /// @notice Error thrown when the max supply specified is zero or less.
    error MaxSupplyMustBeGreaterThanZero();

    /// @notice Deploys a new LazyMint contract with the specified parameters.
    /// @param _uri The metadata URI for the LazyMint contract.
    /// @param _maxSupply The maximum supply of tokens allowed in the LazyMint contract.
    /// @return The address of the newly deployed LazyMint contract.
    function createLazyMint(string memory _uri, uint256 _maxSupply,     uint256 _claimExpiration,
        uint256 _redeemExpiration,
        uint256 _lockedBudget,
        address _currencyAddress) external returns (address) {
        if (_maxSupply <= 0) {
            revert MaxSupplyMustBeGreaterThanZero();
        }

        // Deploy a new LazyMint contract with the given URI and max supply
        LazyMint newLazyMint = new LazyMint(_uri, _maxSupply, _claimExpiration, _redeemExpiration, _lockedBudget, _currencyAddress);

        // Transfer ownership of the deployed contract to the caller
        newLazyMint.transferOwnership(msg.sender);

        // Emit the event for the new contract deployment
        emit LazyMintDeployed(msg.sender, address(newLazyMint), _uri, _maxSupply);

        // Return the address of the deployed LazyMint contract
        return address(newLazyMint);
    }
}
