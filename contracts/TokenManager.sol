// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenManager is Ownable {

    constructor(address _owner) Ownable(_owner) {}
    /// @notice Withdraws Ether from the contract
    /// @param _to Address to send Ether to
    /// @param _amount Amount of Ether to withdraw
    /// @dev Can only be called by the owner
    function withdrawEther(
        address payable _to,
        uint256 _amount
    ) public virtual onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        _to.transfer(_amount);
        emit EtherWithdrawn(_to, _amount);
    }

    /// @notice Withdraws ERC20 tokens from the contract
    /// @param _tokenContract Address of the ERC20 token contract
    /// @param _to Address to send tokens to
    /// @param _amount Amount of tokens to withdraw
    /// @dev Can only be called by the owner
    function withdrawERC20(
        address _tokenContract,
        address _to,
        uint256 _amount
    ) public virtual onlyOwner {
        IERC20 token = IERC20(_tokenContract);
        require(
            _amount <= token.balanceOf(address(this)),
            "Insufficient token balance"
        );
        require(token.transfer(_to, _amount), "Token transfer failed");
        emit ERC20Withdrawn(_tokenContract, _to, _amount);
    }

    /// @notice Handles the receipt of an ERC721 token
    /// @dev Implements ERC721Receiver interface
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Withdraws an ERC721 token from the contract
    /// @param _tokenContract Address of the ERC721 token contract
    /// @param _to Address to send the token to
    /// @param _tokenId ID of the token to withdraw
    /// @dev Can only be called by the owner
    function withdrawERC721(
        address _tokenContract,
        address _to,
        uint256 _tokenId
    ) public virtual onlyOwner {
        IERC721 token = IERC721(_tokenContract);
        require(
            token.ownerOf(_tokenId) == address(this),
            "Token not owned by contract"
        );
        
        token.transferFrom(address(this), _to, _tokenId);

        emit ERC721Withdrawn(_tokenContract, _to, _tokenId);
    }

    
    /// @dev Emitted when Ether is withdrawn
    event EtherWithdrawn(address to, uint256 amount);

    /// @dev Emitted when ERC20 tokens are withdrawn
    event ERC20Withdrawn(address tokenContract, address to, uint256 amount);

    /// @dev Emitted when an ERC721 token is withdrawn
    event ERC721Withdrawn(address tokenContract, address to, uint256 tokenId);
}