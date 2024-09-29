// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./WebContractToken.sol";

// 0x1e4dd10761E42324819Ea3Dab9C09914b1c97172
// 0x46B4952D06e10386972De50d65d5B5D0C4A6940F
// 0xd02a5aE5eCcf942eE1060EcDc7E080248273Bd96
// 0x61ba60374e0CF9a51aD846853b08B09FC163896a
// 0x9C29F0eE3D59dFea70D616f4776F7649dA364342

// Interface for Backpack contracts
interface IBackpack {
    function majorVersion() external view returns (uint256);
}

contract Backpack is WebContractToken {
    constructor(
        address _owner,
        address _backpackFactory
    ) WebContractToken(_owner) {
        backpackFactory = BackpackFactory(_backpackFactory);
        soulBoundNFT = backpackFactory.backpackNFT();
    }

    BackpackFactory public backpackFactory;
    BackpackNFT public soulBoundNFT;
    uint256 public tokenId;

    modifier onlySoulBoundNFT() {
        require(
            msg.sender == address(soulBoundNFT),
            "Backpack#OnlySoulBoundNFT may set the token ID"
        );
        _;
    }

    function setTokenId(uint256 _tokenId) external onlySoulBoundNFT {
        tokenId = _tokenId;
    }

    function onERC721Received(
        address,
        address to,
        uint256,
        bytes memory
    ) public view override returns (bytes4) {
        try IBackpack(to).majorVersion() returns (uint256 version) {
            if (version == MAJOR_VERSION) {
                revert(
                    "Backpack#Backpacks cannot be transferred to other Backpacks"
                );
            }
        } catch {}
        return this.onERC721Received.selector;
    }

    function owner() public view override returns (address) {
        require(tokenId != 0, "Backpack#BackpackNFT failed to set TokenId");
        return soulBoundNFT.ownerOf(tokenId);
    }
}

contract BackpackFactory is TokenManager {
    BackpackNFT public backpackNFT;
    uint256 public backpackCount;
    uint256 immutable maxBackpacks = 10000;
    uint256[] private backpackCosts;

    constructor(
        uint256[] memory _backpackCosts
    ) TokenManager(msg.sender) {
        require(_backpackCosts.length == 10, "Must provide 10 cost tiers");
        backpackNFT = new BackpackNFT(address(this), "TW3 Backpack", "BKPK");
        backpackCosts = _backpackCosts;
    }

    function getBackpackCost() public view returns (uint256) {
        uint256 tier = backpackCount / 1000;
        if (tier >= 10) {
            return backpackCosts[9];
        }
        return backpackCosts[tier];
    }

    function deployBackpack()
        external
        payable
        returns (address, uint256)
    {
        require(
            msg.value == getBackpackCost() || backpackCount < 3,
            "Incorrect funds sent"
        );
        require(backpackCount < maxBackpacks, "Max backpacks reached");
        Backpack newWCT = new Backpack(msg.sender, address(this));
        address wctAddress = address(newWCT);
        uint256 tokenId = backpackNFT.mint(msg.sender, wctAddress);
        backpackCount++;
        return (wctAddress, tokenId);
    }
}

contract BackpackNFT is ERC721, TokenManager {
    mapping(uint256 => Backpack) public backpacks;
    uint256 public backpackCount;
    BackpackFactory public backpackFactory;

    modifier onlyBackpackFactory() {
        require(
            msg.sender == address(backpackFactory),
            "Only the backpack factory can call this function"
        );
        _;
    }

    constructor(
        address _backpackFactory,
        string memory _name,
        string memory _symbol
    )
        ERC721(_name, _symbol)
        TokenManager(BackpackFactory(_backpackFactory).owner())
    {
        backpackFactory = BackpackFactory(_backpackFactory);
    }

    function mint(
        address to,
        address backpack
    ) external onlyBackpackFactory returns (uint256) {
        backpackCount++;
        backpacks[backpackCount] = Backpack(backpack);
        Backpack(backpack).setTokenId(backpackCount);
        _mint(to, backpackCount);
        return (backpackCount);
    }

    function backpackOf(uint256 tokenId) public view returns (address) {
        return address(backpacks[tokenId]);
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
                ownerOf(tokenId) == msg.sender ||
                backpacks[tokenId].isAdmin(msg.sender)) &&
                (!backpacks[tokenId].isLocked() &&
                    !backpacks[tokenId].isImmutable()),
            "Not authorized to update uri"
        );
        _tokenURI[tokenId] = uri;
        emit URIUpdated(tokenId, uri);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return _tokenURI[tokenId];
    }

    // Event emitted when uri is updated
    event URIUpdated(uint256 indexed tokenId, string uri);

    /**
     * @dev Receive function to prevent accidental Ether transfers to this contract
     */
    receive() external payable {
        revert("Please send value to your Backpack contract address instead");
    }

    /**
     * @dev Fallback function to prevent accidental Ether transfers to this contract
     */
    fallback() external payable {
        revert("Please send value to your Backpack contract address instead");
    }
}
