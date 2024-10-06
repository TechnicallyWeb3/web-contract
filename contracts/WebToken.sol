// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WebContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Interface for WebContracts
interface IWebToken {
    function majorVersion() external view returns (uint256);
}

contract WebToken is WebContract {

    WebERC721 public webNFT;
    uint256 public tokenId;

    constructor(uint256 _tokenId) WebContract(msg.sender) {
        webNFT = WebERC721(msg.sender);
        tokenId = _tokenId;
        require (
            _tokenId > 0 &&
            _tokenId - 1 <= webNFT.webTokenCount(), 
            "WT#TokenIdCannotBe0"
        );
    }

    function onERC721Received(address, address to, uint256, bytes memory) public view override returns (bytes4) {
        try IWebToken(to).majorVersion() returns (uint256 version) {
            if (version == webContractVersion().majorVersion) {
                revert("WT#WTsCannotBeTransferredToOtherWTs");
            }
        } catch {}
        return this.onERC721Received.selector;
    }

    function owner() public view override returns (address) {
        if (tokenId != 0) {
            return webNFT.ownerOf(tokenId);
        }
        return super.owner();
    }
}

contract WebERC721 is ERC721, Ownable {

    uint256 public webTokenCount;
    mapping(uint256 => WebToken) private webTokens;
    uint256 public webTokenCost;

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _owner, 
        uint256 _cost
    ) ERC721(_name, _symbol) Ownable(_owner) {
        webTokenCost = _cost;
    }

    function mint(address to) external payable returns (uint256) {
        require (msg.value == webTokenCost, "WT#NotEnoughValue");
        webTokenCount++; // must be 1 > , 0 is invalid tokenID 
        _mint(to, webTokenCount);
        webTokens[webTokenCount] = new WebToken(webTokenCount);
        return (webTokenCount);
    }

    function tokenOf(uint256 tokenId) public view returns (address) {
        return address(webTokens[tokenId]);
    }

    function setCost(uint256 _cost) external onlyOwner {
        webTokenCost = _cost;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string.concat(addressToString(tokenOf(tokenId)), Strings.toString(tokenId));
    }

    function addressToString(address _address) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(_address)), 20);
    }
}