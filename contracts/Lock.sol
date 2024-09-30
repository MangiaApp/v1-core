// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "hardhat/console.sol";

contract Lock {
    uint256 public unlockTime;
    address payable public owner;

    event Withdrawal(uint256 amount, uint256 when);

    error UnlockTimeInFuture();
    error CannotWithdrawYet();
    error NotOwner();

    constructor(uint256 _unlockTime) payable {
        if (block.timestamp >= _unlockTime) {
            revert UnlockTimeInFuture();
        }

        unlockTime = _unlockTime;
        owner = payable(msg.sender);
    }

    function withdraw() public {
        console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);

        if (block.timestamp < unlockTime) {
            revert CannotWithdrawYet();
        }
        if (msg.sender != owner) {
            revert NotOwner();
        }

        emit Withdrawal(address(this).balance, block.timestamp);

        owner.transfer(address(this).balance);
    }
}
