// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/WebContract.sol";

// Interface for WebContracts
interface IWebToken {
    function majorVersion() external view returns (uint256);
}

contract WebToken is WebContract {
    constructor(address _owner, address _webFactory) WebContract(_owner) {
        webFactory = Web4Factory(_webFactory);
        webNFT = webFactory.webNFT();
    }

    Web4Factory public webFactory;
    WebERC721 public webNFT;
    uint256 public tokenId;

    modifier onlyWebNFT {
        require(msg.sender == address(webNFT), "WT#OnlyWebNFT may set the token ID");
        _;
    }

    function setTokenId(uint256 _tokenId) external onlyWebNFT {
        tokenId = _tokenId;
    }

    function onERC721Received(address, address to, uint256, bytes memory) public view override returns (bytes4) {
        try IWebToken(to).majorVersion() returns (uint256 version) {
            if (version == MAJOR_VERSION) {
                revert("WT#WTs cannot be transferred to other WTs");
            }
        } catch {}
        return this.onERC721Received.selector;
    }

    function owner() public view override returns (address) {
        require (tokenId != 0, "WT#WTNFT failed to set TokenId");
        return webNFT.ownerOf(tokenId);
    }
}

contract Web4Factory is Ownable {
    WebERC721 public webNFT;
    uint256 public webTokenCost;

    constructor() Ownable(msg.sender) {
        webNFT = new WebERC721(address(this), "TW3 WebToken", "TW3WT");
    }

    function setWebTokenCost(uint256 _cost) external onlyOwner {
        webTokenCost = _cost;
    }

    function deployWebToken() external /*payable*/ returns(address, uint256) {
        // require(msg.value == webTokenCost, "Incorrect funds sent");
        WebToken newWT = new WebToken(msg.sender, address(this));
        address wtAddress = address(newWT);
        uint256 tokenId = webNFT.mint(msg.sender, wtAddress);
        return (wtAddress, tokenId);
    }
}

contract WebERC721 is ERC721URIStorage {
    mapping (uint256 => WebToken) public webTokens;
    uint256 public webTokenCount;
    Web4Factory public webFactory;

    modifier onlyWebFactory() {
        require(
            msg.sender == address(webFactory),
            "Only the web factory can call this function"
        );
        _;
    }

    constructor(address _webFactory, string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        webFactory = Web4Factory(_webFactory);
    }

    function mint(address to, address webToken) external onlyWebFactory returns (uint256) {
        webTokenCount++;
        webTokens[webTokenCount] = WebToken(webToken);
        WebToken(webToken).setTokenId(webTokenCount);
        _mint(to, webTokenCount);
        return (webTokenCount);
    }

    function tokenOf(uint256 tokenId) public view returns (address) {
        return address(webTokens[tokenId]);
    }

    // Replace the updateURI function with setTokenURI
    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        require(
            (webFactory.owner() == msg.sender ||
            ownerOf(tokenId) == msg.sender ||
            webTokens[tokenId].isAdmin(msg.sender)) &&
            (!webTokens[tokenId].isLocked() &&
            !webTokens[tokenId].isImmutable()),
            "Not authorized to update uri"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    // Keep the URIUpdated event if you want to maintain compatibility
    event URIUpdated(uint256 indexed tokenId, string uri);
}
