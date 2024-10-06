// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./TokenManager.sol";

/// @title WebContract
/// @notice This contract provides functionality for managing web resources, admin roles, and various token operations
/// @dev Inherits from Ownable and implements additional features like locking, admin management, and resource handling
abstract contract WebContractToken is TokenManager {
    /// @notice Represents the version of the contract
    /// @dev Used to track major, minor, and patch versions
    struct Version {
        uint256 majorVersion;
        uint256 minorVersion;
        uint256 patchVersion;
    }

    uint256 public immutable MAJOR_VERSION = 1;
    uint256 public immutable MINOR_VERSION = 0;
    uint256 public immutable PATCH_VERSION = 2;

    /// @notice Returns the current version of the web contract
    /// @return Version struct containing major, minor, and patch versions
    function webContractVersion() public pure returns (Version memory) {
        return Version(MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION);
    }

    /// @notice Struct to hold redirect information
    struct RedirectInfo {
        string redirectValue; // The actual redirect value (hash, chain ID, etc.)
        string redirectType; // e.g., "ipfs", 137, "pol", 1, "eth", "ordinal", or "" for no redirect
        uint8 redirectCode; // Similar to 301, 302 etc. None (0), permanent (1) or temporary (2) using uint8 allows for future expansion
    }

    /// @notice The redirect information for the contract
    RedirectInfo private redirectInfo;

    /// @notice Sets the redirect information
    /// @param _type The type of redirect (e.g., "ipfs", [chainId], [chainAlias], "ordinal", or "" for no redirect)
    /// @param _value The redirect value (e.g., IPFS hash, address, ordinal ID)
    /// @dev Can only be called by the contract owner
    function setRedirect(
        string memory _value,
        string memory _type,
        uint8 _code
    ) public virtual onlyAdmin notLocked {
        redirectInfo = RedirectInfo(_value, _type, _code);
        emit RedirectSet(_value, _type, _code);
    }

    /// @notice Gets the current redirect information
    /// @return RedirectInfo struct containing the redirect type and value
    function getRedirect() public view virtual returns (RedirectInfo memory) {
        return
            redirectInfo.redirectCode > 0
                ? RedirectInfo(
                    string.concat("redirect/", redirectInfo.redirectType),
                    redirectInfo.redirectValue,
                    redirectInfo.redirectCode
                )
                : redirectInfo;
    }

    /// @notice Whether the contract is locked or immutable
    bool private writeLocked;
    bool private isImmutable;

    /// @notice Checks if the contract is currently locked
    /// @return bool indicating whether the contract is locked
    function isLocked() public view returns (bool) {
        return writeLocked;
    }

    /// @notice Modifier to ensure function can only be called when contract is not locked or immutable
    modifier notLocked() {
        require(!writeLocked && !isImmutable, "Contract is locked");
        _;
    }

    /// @notice Locks the contract, preventing certain operations
    /// @dev Can only be called by the owner when the contract is not locked
    function lockContract() public virtual notLocked onlyOwner {
        writeLocked = true;
        emit ContractLocked();
    }

    /// @notice Unlocks the contract
    /// @dev Can only be called by the owner
    function unlockContract() public virtual onlyOwner {
        writeLocked = false;
        emit ContractUnlocked();
    }

    /// @notice Makes the contract immutable, permanently locking it
    /// @dev Can only be called by the owner, cannot be undone!
    function makeImmutable() public virtual onlyOwner {
        isImmutable = true;
        emit ContractMadeImmutable();
    }

    mapping(address => bool) private admins;

    /// @notice Modifier to restrict function access to admins or the owner
    modifier onlyAdmin() {
        require(msg.sender == owner() || admins[msg.sender], "Not an admin");
        _;
    }

    /// @notice Adds a new admin
    /// @param _admin Address of the new admin
    /// @dev Can only be called by the owner
    /// @dev SECURITY WARNING: Overriding this function may break access control.
    ///      Ensure any override maintains the intended admin addition logic.
    function addAdmin(address _admin) public virtual onlyOwner {
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    /// @notice Removes an admin
    /// @param _admin Address of the admin to remove
    /// @dev Can only be called by the owner
    /// @dev SECURITY WARNING: Overriding this function may break access control.
    ///      Ensure any override maintains the intended admin removal logic.
    function removeAdmin(address _admin) public virtual onlyOwner {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    /// @notice Checks if an address is an admin
    /// @param _admin Address to check
    /// @return bool indicating whether the address is an admin
    /// @dev SECURITY WARNING: Overriding this function may break access control.
    ///      Ensure any override maintains the intended admin verification logic.
    function isAdmin(address _admin) public view virtual returns (bool) {
        return _admin == owner() || admins[_admin];
    }

    /// @notice Contract constructor
    /// @param _owner Address of the initial owner
    constructor(address _owner) TokenManager(_owner) {}

    /// @notice Represents a resource file with content chunks and content type
    struct ResourceFile {
        bytes[] content;
        string contentType;
        uint8 redirectCode;
    }

    mapping(string => ResourceFile) private resourceChunks;

    /// @notice Sets a chunk of a resource file
    /// @param _path Path of the resource
    /// @param _content Content of the chunk
    /// @param _contentType Content type of the resource
    /// @param _chunkIndex Index of the chunk
    /// @dev Can only be called by an admin when the contract is not locked
    function setResourceChunk(
        string calldata _path,
        bytes calldata _content,
        string calldata _contentType,
        uint256 _chunkIndex,
        uint8 _redirectCode
    ) public virtual onlyAdmin notLocked {
        ResourceFile storage file = resourceChunks[_path];
        bytes[] storage chunks = file.content;

        require(bytes(_contentType).length > 0, "Content type is required");

        if (bytes(file.contentType).length == 0) {
            // If the contentType is not set, this is a new file
            file.contentType = _contentType;
            chunks.push(_content);
            file.redirectCode = _redirectCode;
        } else {
            require(
                keccak256(abi.encodePacked(file.contentType)) == keccak256(abi.encodePacked(_contentType)),
                "Content type mismatch"
            );

            require(_chunkIndex <= chunks.length, "Chunk index out of bounds");

            if (keccak256(_content) != keccak256(chunks[_chunkIndex])) {
                chunks[_chunkIndex] = _content;
            }

            if (_redirectCode != file.redirectCode) {
                file.redirectCode = _redirectCode;
            }
        }

        emit ResourceChunkSet(_path, _chunkIndex);
    }

    /// @notice Retrieves a chunk of a resource file
    /// @param path Path of the resource
    /// @param index Index of the chunk
    /// @return bytes memory, string memory The content chunk and content type
    function getResourceChunk(
        string memory path,
        uint256 index
    ) public view virtual returns (bytes memory, string memory) {
        ResourceFile memory file = resourceChunks[path];
        require(index < file.content.length, "Chunk index out of bounds");
        return (file.content[index], file.contentType);
    }

    /// @notice Gets the total number of chunks for a resource
    /// @param path Path of the resource
    /// @return uint256 Total number of chunks
    function _getTotalChunks(
        string memory path
    ) internal view virtual returns (uint256) {
        return resourceChunks[path].content.length;
    }

    function getResource(
        string memory path
    ) public view virtual returns (uint256, string memory, uint8) {
        return (
            resourceChunks[path].content.length, 
            resourceChunks[path].contentType, 
            resourceChunks[path].redirectCode
        );
    }

    /// @notice Removes a resource
    /// @param path Path of the resource to remove
    /// @dev Can only be called by an admin when the contract is not locked
    function removeResource(
        string memory path
    ) public virtual onlyAdmin notLocked {
        delete resourceChunks[path];
        emit ResourceRemoved(path);
    }

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

    /// @dev Emitted when the redirect information is set
    event RedirectSet(string redirectValue, string redirectType, uint8 redirectCode);

    /// @dev Emitted when the contract is locked
    event ContractLocked();

    /// @dev Emitted when the contract is unlocked
    event ContractUnlocked();

    /// @dev Emitted when the contract is made immutable
    event ContractMadeImmutable();

    /// @dev Emitted when an admin is added
    event AdminAdded(address admin);

    /// @dev Emitted when an admin is removed
    event AdminRemoved(address admin);

    /// @dev Emitted when a resource chunk is set
    event ResourceChunkSet(string path, uint256 chunkIndex);

    /// @dev Emitted when a resource is removed
    event ResourceRemoved(string path);


    /// @dev Emitted when an address is approved or disapproved
    event Approval(
        address indexed owner,
        address indexed operator,
        bool approved
    );
}