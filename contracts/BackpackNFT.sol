// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WebContractToken.sol";

contract BackpackNFT is WebContractToken {
    constructor(address owner) WebContractToken(owner) {}
}

contract BackpackFactory {
    mapping(uint => address) public wctIndex;
    SoulBoundNFT public soulBoundNFT;

    constructor(address _soulBoundNFTAddress) {
        soulBoundNFT = SoulBoundNFT(_soulBoundNFTAddress);
    }

    function deployWebContractToken() external {
        BackpackNFT newWCT = new BackpackNFT(msg.sender);
        address wctAddress = address(newWCT);
        uint256 tokenId = soulBoundNFT.mint(wctAddress);
        wctIndex[tokenId] = wctAddress;
    }
}

contract SoulBoundNFT is ERC721, Ownable {
    uint256 public wctCount;
    BackpackFactory public backpackFactory;

    constructor() ERC721("BackpackNFTs", "WCT") Ownable(msg.sender) {
        _mint(msg.sender, wctCount);
        wctCount++;
    }

    modifier onlyBackpackFactory() {
        require(
            msg.sender == address(backpackFactory),
            "Only backpack deployer can call this function"
        );
        _;
    }

    function setBackpackFactory(address _BackpackFactory) external onlyOwner {
        backpackFactory = BackpackFactory(_BackpackFactory);
    }

    function mint(address to) external onlyBackpackFactory returns (uint256) {
        uint256 tokenId = wctCount;
        _mint(to, tokenId);
        wctCount++;
        return tokenId;
    }

    // Override _update function to block transfers unless by owner
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);
        require(
            from == address(0) || msg.sender == owner(),
            "Tokens are soul-bound and non-transferable."
        );
        return super._update(to, tokenId, auth);
    }

    // Override setApprovalForAll function to prevent approvals
    function _setApprovalForAll(
        address /*sender*/,
        address /*operator*/,
        bool /*approved*/
    ) internal virtual override(ERC721) {
        revert("Soul-bound tokens cannot be approved for all.");
    }

    // Add this function to override the internal _approve function
    function approve(
        address /*to*/,
        uint256 /*tokenId*/
    ) public virtual override(ERC721) {
        revert("Soul-bound tokens cannot be approved.");
    }
}
