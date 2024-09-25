// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WebContractToken.sol";

contract BackpackNFT is WebContractToken {
    constructor(address owner) WebContractToken(owner) {}
}

contract SoulBoundNFT is ERC721, Ownable {

    uint256 public wctCount;

    mapping (uint256 index => address wct) public wctIndex;

    constructor() ERC721("BackpackNFTs", "WCT") Ownable(msg.sender) {}

    function deployWCT() external {
        BackpackNFT newWCT = new BackpackNFT(msg.sender);
        address wctAddress = address(newWCT);
        _mint(wctAddress, wctCount);
        wctIndex[wctCount] = wctAddress;
        wctCount++;
    }

    // Override _update function to block transfers unless by owner
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(from == address(0) || msg.sender == owner(), "Tokens are soul-bound and non-transferable.");
        return super._update(to, tokenId, auth);
    }
}

