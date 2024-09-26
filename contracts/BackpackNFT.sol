// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WebContractToken.sol";

// Interface for Backpack contracts
interface IBackpack {
    function majorVersion() external view returns (uint256);
}

contract Backpack is WebContractToken {
    constructor(address owner, address _soulBoundNFT) WebContractToken(owner) {
        soulBoundNFT = BackpackNFT(_soulBoundNFT);
    }

    BackpackNFT public soulBoundNFT;

    function onERC721Received(address, address to, uint256, bytes memory) public view override returns (bytes4) {
        try IBackpack(to).majorVersion() returns (uint256 version) {
            if (version == MAJOR_VERSION) {
                revert("Backpacks cannot be transferred to other Backpacks");
            }
        } catch {}
        return this.onERC721Received.selector;
    }

    function _checkOwner() internal view override {
        if (owner() != msg.sender && address(soulBoundNFT) != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
    }
}

contract BackpackFactory is Ownable {
    BackpackNFT public backpackNFT;
    uint256 public backpackCost;

    constructor() Ownable(msg.sender) {
        backpackNFT = new BackpackNFT(address(this), "TW3 Backpack", "BKPK");
    }

    function setBackpackCost(uint256 _cost) external onlyOwner {
        backpackCost = _cost;
    }

    function deployWebContractToken() external /*payable*/ returns(address) {
        // require(msg.value == backpackCost, "Incorrect funds sent");
        Backpack newWCT = new Backpack(msg.sender, address(backpackNFT));
        address wctAddress = address(newWCT);
        backpackNFT.mint(wctAddress);
        return wctAddress;
    }
}

contract BackpackNFT is ERC721 {
    mapping (uint256 => Backpack) public backpacks;
    uint256 public backpackCount;
    BackpackFactory public backpackFactory;

    modifier onlyBackpackFactory() {
        require(
            msg.sender == address(backpackFactory),
            "Only the backpack factory can call this function"
        );
        _;
    }

    constructor(address _backpackFactory, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        backpackFactory = BackpackFactory(_backpackFactory);
    }

    //     // returns owner of backpack instead of the backpack address.
    // function _ownerOf(uint256 tokenId) internal view override returns (address) {
    //     if(backpackCount > tokenId) {
    //         return backpacks[tokenId].owner();
    //     } 
        
    //     else return address(0);
    // }

    function _isAuthorized(address owner, address spender, uint tokenId) internal view override returns (bool) {
        return
            spender != address(0) &&
            (
                owner == spender || 
                isApprovedForAll(owner, spender) || 
                _getApproved(tokenId) == spender ||
                backpackOwner(tokenId) == spender
            );
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);

        if (from != address(0)) {
            if (to == address(0)) {
                backpacks[tokenId].renounceOwnership();
            }
            else backpacks[tokenId].transferOwnership(to);
            return from;
        }

        return super._update(to, tokenId, auth);
    }

    function mint(address to) external onlyBackpackFactory returns (uint256) {
        backpacks[backpackCount] = Backpack(to);
        _mint(to, backpackCount);
        backpackCount++;
        return (backpackCount - 1);
    }

    function backpackOwner(uint256 tokenId) public view returns (address) {
        return backpacks[tokenId].owner();
    }

    // Mapping to store uri for each token
    mapping(uint256 => string) private _tokenURI;

    /**
     * @dev Allows the owner of a token to update its uri
     * @param tokenId The ID of the token to update
     * @param uri The new uri JSON string
     */
    function updateURI(uint256 tokenId, string memory uri) public {
        require(
            (backpackFactory.owner() == msg.sender ||
            backpackOwner(tokenId) == msg.sender ||
            backpacks[tokenId].isAdmin(msg.sender)) &&
            (!backpacks[tokenId].isLocked() &&
            !backpacks[tokenId].isImmutable()),
            "Not authorized to update uri"
        );
        _tokenURI[tokenId] = uri;
        emit URIUpdated(tokenId, uri);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _tokenURI[tokenId];
     }

    // Event emitted when uri is updated
    event URIUpdated(uint256 indexed tokenId, string uri);
}
