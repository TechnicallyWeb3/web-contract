// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./WebContract.sol";

contract WebsiteContract is WebContract {

    constructor() WebContract(msg.sender) {}

    mapping(address => bool) private _approvals;

    /// @notice Approves or disapproves an address to manage the contract
    /// @param to Address to approve or disapprove
    /// @param approved True to approve, false to disapprove
    /// @dev Can only be called by the owner
    function approve(address to, bool approved) public virtual onlyOwner {
        _approvals[to] = approved;
        emit Approval(owner(), to, approved);
    }

    /// @notice Checks if an address is approved to manage the contract
    /// @param operator Address to check
    /// @return bool indicating whether the address is approved
    function isApproved(address operator) public view virtual returns (bool) {
        return _approvals[operator];
    }

    /// @notice Transfers ownership of the contract
    /// @param from Current owner's address
    /// @param to New owner's address
    /// @dev Can be called by the owner or an approved address
    function transferFrom(address from, address to) public virtual {
        require(
            from == owner(),
            "WebContractV5: transfer from incorrect owner"
        );
        require(
            to != address(0),
            "WebContractV5: transfer to the zero address"
        );
        require(
            msg.sender == owner() || _approvals[msg.sender],
            "WebContractV5: transfer caller is not owner nor approved"
        );

        _transferOwnership(to);
    }

    /// @dev Emitted when an address is approved or disapproved
    event Approval(
        address indexed owner,
        address indexed operator,
        bool approved
    );
}