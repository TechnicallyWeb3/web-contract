// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/IERC721.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IETHRegistrarController} from "@ensdomains/ens-contracts/contracts/registry/IETHRegistrarController.sol";

abstract contract WebContractV5 is Ownable {
    struct Version {
        uint256 majorVersion;
        uint256 minorVersion;
        uint256 patchVersion;
    }

    uint256 public immutable MAJOR_VERSION = 0;
    uint256 public immutable MINOR_VERSION = 5;
    uint256 public immutable PATCH_VERSION = 0;

    function webContractVersion() public pure returns (Version memory) {
        return Version(MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION);
    }

    mapping(address => bool) private admins;

    modifier onlyAdmin() {
        require(msg.sender == owner() || admins[msg.sender], "Not an admin");
        _;
    }

    function addAdmin(address _admin) public virtual onlyOwner {
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) public virtual onlyOwner {
        admins[_admin] = false;
    }

    function isAdmin(address _admin) public view virtual returns (bool) {
        // Default behavior: return true if _admin is the owner or in the admins mapping
        return _admin == owner() || admins[_admin];

        // To hide admin status, override this function and use the following:
        // return false;

        // To check against msg.sender instead of _admin, use:
        // return msg.sender == owner() || admins[msg.sender];
    }

    constructor(address _owner) Ownable(_owner) {}

    struct ResourceFile {
        string[] content;
        string contentType;
    }

    mapping(string => ResourceFile) private resourceChunks;

    function setResourceChunk(
        string calldata _path,
        string calldata _content,
        string calldata _contentType,
        uint256 _chunkIndex
    ) public virtual onlyAdmin {
        ResourceFile storage file = resourceChunks[_path];
        string[] storage chunks = resourceChunks[_path].content;
        string storage contentType = resourceChunks[_path].contentType;

        require(bytes(contentType).length > 0, "Content type is required");

        if (bytes(contentType).length == 0 && bytes(_contentType).length > 0) {
            // If the contentType is not set, set it
            file.contentType = _contentType;
        }

        require(keccak256(bytes(file.contentType)) == keccak256(bytes(_contentType)), "Content type mismatch");

        // Ensure the chunks are not written out of order
        if (_chunkIndex >= chunks.length) {
            require(_chunkIndex == chunks.length, "Chunk index out of bounds");
        } else {
            // Only update if content is different
            require(
                keccak256(abi.encodePacked(_content)) !=
                    keccak256(abi.encodePacked(chunks[_chunkIndex])),
                "New content must be different from existing"
            );
        }

        if (_chunkIndex == chunks.length) {
            chunks.push(_content);
        } else {
            chunks[_chunkIndex] = _content;
        }
    }

    function getResourceChunk(
        string memory path,
        uint256 index
    ) public view virtual returns (string memory, string memory) {
        ResourceFile memory file = resourceChunks[path];
        require(index < file.content.length, "Chunk index out of bounds");
        return (file.content[index], file.contentType);
    }

    function getTotalChunks(string memory path) public view virtual returns (uint256) {
        return resourceChunks[path].content.length;
    }

    function removeResource(string memory path) public virtual onlyAdmin {
        delete resourceChunks[path];
    }

    function withdrawEther(address payable _to, uint256 _amount) public virtual onlyOwner {
        require(_amount <= address(this).balance, "Insufficient balance");
        _to.transfer(_amount);
    }

    function withdrawERC20(address _tokenContract, address _to, uint256 _amount) public virtual onlyOwner {
        IERC20 token = IERC20(_tokenContract);
        require(_amount <= token.balanceOf(address(this)), "Insufficient token balance");
        require(token.transfer(_to, _amount), "Token transfer failed");
    }

    function withdrawERC721(address _tokenContract, address _to, uint256 _tokenId) public virtual onlyOwner {
        IERC721 token = IERC721(_tokenContract);
        require(token.ownerOf(_tokenId) == address(this), "Token not owned by contract");
        require(token.transferFrom(address(this), _to, _tokenId), "Token transfer failed");
    }

    function renewENSDomain(string memory _name, uint256 _duration) public virtual onlyOwner {
        bytes32 labelHash = keccak256(bytes(_name));
        uint256 tokenId = uint256(labelHash);
        
        // Get the ENS registry address
        ENS ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
        
        // Get the .eth registrar controller
        address ethRegistrarControllerAddress = ens.owner(bytes32(uint256(labelHash)));
        IETHRegistrarController controller = IETHRegistrarController(ethRegistrarControllerAddress);
        
        // Calculate the renewal cost
        (uint256 price,) = controller.rentPrice(_name, _duration);
        
        // Ensure the contract has enough balance
        require(address(this).balance >= price, "Insufficient balance for renewal");
        
        // Renew the domain
        controller.renew{value: price}(_name, _duration);
        
        emit ENSDomainRenewed(_name, _duration, price);
    }
    
    event ENSDomainRenewed(string name, uint256 duration, uint256 cost);
}
