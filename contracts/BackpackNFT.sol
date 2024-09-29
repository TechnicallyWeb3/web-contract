// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WebContract.sol";

// Interface for Backpack contracts
interface IWebContractToken {
    function majorVersion() external view returns (uint256);
}

contract WebContractToken is WebContract {
    constructor(address _owner, address _backpackFactory) WebContract(_owner) {
        backpackFactory = Web4Factory(_backpackFactory);
        soulBoundNFT = backpackFactory.backpackNFT();
    }

    Web4Factory public backpackFactory;
    WebContractNFT public soulBoundNFT;
    uint256 public tokenId;

    modifier onlySoulBoundNFT {
        require(msg.sender == address(soulBoundNFT), "Backpack#OnlySoulBoundNFT may set the token ID");
        _;
    }

    function setTokenId(uint256 _tokenId) external onlySoulBoundNFT {
        tokenId = _tokenId;
    }

    function onERC721Received(address, address to, uint256, bytes memory) public view override returns (bytes4) {
        try IWebContractToken(to).majorVersion() returns (uint256 version) {
            if (version == MAJOR_VERSION) {
                revert("Backpack#Backpacks cannot be transferred to other Backpacks");
            }
        } catch {}
        return this.onERC721Received.selector;
    }

    function owner() public view override returns (address) {
        require (tokenId != 0, "Backpack#BackpackNFT failed to set TokenId");
        return soulBoundNFT.ownerOf(tokenId);
    }
}

contract Web4Factory is Ownable {
    WebContractNFT public backpackNFT;
    uint256 public backpackCost;

    constructor() Ownable(msg.sender) {
        backpackNFT = new WebContractNFT(address(this), "TW3 Backpack", "BKPK");
    }

    function setBackpackCost(uint256 _cost) external onlyOwner {
        backpackCost = _cost;
    }

    function deployWebContractToken() external /*payable*/ returns(address, uint256) {
        // require(msg.value == backpackCost, "Incorrect funds sent");
        WebContractToken newWCT = new WebContractToken(msg.sender, address(this));
        address wctAddress = address(newWCT);
        uint256 tokenId = backpackNFT.mint(msg.sender, wctAddress);
        return (wctAddress, tokenId);
    }
}

contract WebContractNFT is ERC721URIStorage {
    mapping (uint256 => WebContractToken) public backpacks;
    uint256 public backpackCount;
    Web4Factory public backpackFactory;

    modifier onlyBackpackFactory() {
        require(
            msg.sender == address(backpackFactory),
            "Only the backpack factory can call this function"
        );
        _;
    }

    constructor(address _backpackFactory, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        backpackFactory = Web4Factory(_backpackFactory);
    }

    function mint(address to, address backpack) external onlyBackpackFactory returns (uint256) {
        backpackCount++;
        backpacks[backpackCount] = WebContractToken(backpack);
        WebContractToken(backpack).setTokenId(backpackCount);
        _mint(to, backpackCount);
        return (backpackCount);
    }

    function backpackOf(uint256 tokenId) public view returns (address) {
        return address(backpacks[tokenId]);
    }

    // Replace the updateURI function with setTokenURI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(
            (backpackFactory.owner() == msg.sender ||
            ownerOf(tokenId) == msg.sender ||
            backpacks[tokenId].isAdmin(msg.sender)) &&
            (!backpacks[tokenId].isLocked() &&
            !backpacks[tokenId].isImmutable()),
            "Not authorized to update uri"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    // Keep the URIUpdated event if you want to maintain compatibility
    event URIUpdated(uint256 indexed tokenId, string uri);
}
