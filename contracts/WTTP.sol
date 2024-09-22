// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Web3TransferProtocol
/// @notice A contract implementing a file system-like structure on the blockchain
/// @dev Inherits from OpenZeppelin's Ownable contract for access control
contract Web3TransferProtocol is Ownable {
    /// @notice Initializes the contract and sets up default permission levels and root directory
    /// @dev Calls Ownable constructor with msg.sender as the initial owner
    constructor() Ownable(msg.sender) {
        // set default permission levels for groups
        // public/read-only
        permissionLevels[0] = Permission({
            read: true,
            write: false,
            execute: false
        });
        // operator/read-write
        permissionLevels[1] = Permission({
            read: true,
            write: true,
            execute: false
        });
        // admin/read-write-execute
        permissionLevels[2] = Permission({
            read: true,
            write: true,
            execute: true
        });

        // create root directory
        string[] memory rootPath = new string[](1);
        rootPath[0] = "/";
        directories[encodeStringArray(rootPath)] = Directory({
            files: new string[](0),
            directories: new string[](0),
            created: block.timestamp,
            customPermissions: false
        });
    }

    /// @notice Represents the version of the protocol
    /// @dev Used for tracking protocol updates
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }

    /// @notice The major version of the protocol
    uint256 immutable majorVersion = 0;
    /// @notice The minor version of the protocol
    uint256 immutable minorVersion = 1;
    /// @notice The patch version of the protocol
    uint256 immutable patchVersion = 4;

    /// @notice Retrieves the current version of the protocol
    /// @return Version struct containing major, minor, and patch versions
    function getVersion() public pure returns (Version memory) {
        return Version(majorVersion, minorVersion, patchVersion);
    }

    /// @notice Indicates whether the file system is locked
    bool public isLocked;

    /// @notice Locks the file system, preventing further modifications
    /// @dev Can only be called by the contract owner
    function lockFS() external onlyOwner {
        isLocked = true;
    }

    /// @notice The chain ID for the browserto redirect to, if set
    uint256 public redirectChainId;

    /// @notice Sets the redirect chain ID
    /// @param _chainId The chain ID to redirect to
    /// @dev Can only be called by the contract owner
    function setRedirectChainId(uint256 _chainId) external onlyOwner {
        redirectChainId = _chainId;
    }

    /// @notice The IPFS hash for the browser to redirect to, if set
    string public redirectIPFSHash;

    /// @notice Sets the redirect IPFS hash
    /// @param _hash The IPFS hash to redirect to
    /// @dev Can only be called by the contract owner
    function setRedirectIPFSHash(string memory _hash) external onlyOwner {
        redirectIPFSHash = _hash;
    }

    /// @notice Represents the permission structure for groups, files and directories
    struct Permission {
        bool read;
        bool write;
        bool execute;
    }

    /// @notice Mapping of permission levels to their corresponding permissions
    mapping(uint8 => Permission) private permissionLevels;
    /// @notice Mapping of user addresses to their permission levels
    mapping(address => uint8) private userPermissions;

    /// @notice Sets the default permission level for a group
    /// @param _groupId The ID of the group
    /// @param group The permission structure for the group
    /// @dev Can only be called by the contract owner
    function setDefaultPermissionLevel(
        uint8 _groupId,
        Permission calldata group
    ) public onlyOwner {
        permissionLevels[_groupId] = group;
    }

    /// @notice Sets the permission level for a specific user
    /// @param _user The address of the user
    /// @param _permissionLevel The permission level to set for the user
    /// @dev Can only be called by the contract owner
    function setUserPermissionLevel(
        address _user,
        uint8 _permissionLevel
    ) public onlyOwner {
        userPermissions[_user] = _permissionLevel;
    }

    /// @notice Modifier to check write permissions for a file or directory
    /// @param _path The path to the file or directory
    /// @param _fileName The name of the file (empty string for directories)
    modifier writePermissions(string[] memory _path, string memory _fileName) {
        require(!isLocked, "File system is locked");
        bytes memory path = encodeStringArray(_path);
        uint8 _userPermissionLevel = userPermissions[msg.sender];
        Permission memory _userPermissions;
        if (bytes(_fileName).length == 0) {
            // If fileName is empty, we're checking permissions for the directory itself
            _userPermissions = directories[path].customPermissions
                ? dirPermissions[path][_userPermissionLevel]
                : permissionLevels[_userPermissionLevel];
        } else {
            // Check permissions for the file
            _userPermissions = files[path][_fileName].customPermissions
                ? filePermissions[path][_fileName][_userPermissionLevel]
                : permissionLevels[_userPermissionLevel];
        }
        require(
            msg.sender == owner() || _userPermissions.write,
            "No write permissions for file or directory"
        );
        _;
    }

    /// @notice Modifier to check read permissions for a file or directory
    /// @param _path The path to the file or directory
    /// @param _fileName The name of the file (empty string for directories)
    modifier readPermissions(string[] memory _path, string memory _fileName) {
        bytes memory path = encodeStringArray(_path);
        uint8 _userPermissionLevel = userPermissions[msg.sender];
        Permission memory _userPermissions;
        if (bytes(_fileName).length == 0) {
            // If fileName is empty, we're checking permissions for the directory itself
            _userPermissions = directories[path].customPermissions
                ? dirPermissions[path][_userPermissionLevel]
                : permissionLevels[_userPermissionLevel];
        } else {
            // Check permissions for the file
            _userPermissions = files[path][_fileName].customPermissions
                ? filePermissions[path][_fileName][_userPermissionLevel]
                : permissionLevels[_userPermissionLevel];
        }

        require(
            msg.sender == owner() || _userPermissions.read,
            "No read permissions for file or directory"
        );

        _;
    }

    /// @notice Represents the structure of a directory
    struct Directory {
        string[] files;
        string[] directories;
        uint256 created;
        bool customPermissions;
    }

    /// @notice Modifier to check if a given path is valid
    /// @param _path The path to validate
    modifier validPath(string[] memory _path) {
        require(_path.length > 0, "Path is empty");
        require(
            keccak256(abi.encodePacked(_path[0])) ==
                keccak256(abi.encodePacked("/")),
            "Path must start with /"
        );
        require(
            directories[encodeStringArray(_path)].created != 0,
            "Path does not exist"
        );
        _;
    }

    /// @notice Gets the parent path of a given path
    /// @param _path The path to get the parent of
    /// @return The parent path
    function getParentPath(
        string[] calldata _path
    ) internal pure returns (string[] memory) {
        require(_path.length > 1, "Path has no parent");
        string[] memory parentPath = new string[](_path.length - 1);
        for (uint256 i = 0; i < _path.length - 1; i++) {
            parentPath[i] = _path[i];
        }
        return parentPath;
    }

    /// @notice Mapping of encoded paths to Directory structures
    mapping(bytes => Directory) private directories;
    /// @notice Mapping of encoded paths to permission levels for directories
    mapping(bytes => mapping(uint256 => Permission)) private dirPermissions;

    /// @notice Lists the contents of a directory
    /// @param _path The path to the directory
    /// @return The Directory structure containing the directory's contents
    function ls(
        string[] calldata _path
    )
        external
        view
        validPath(_path)
        readPermissions(_path, "")
        returns (Directory memory)
    {
        return directories[encodeStringArray(_path)];
    }

    /// @notice Creates a new directory
    /// @param _path The path where the new directory should be created
    function mkdir(
        string[] calldata _path
    ) external validPath(getParentPath(_path)) writePermissions(_path, "") {
        bytes memory path = encodeStringArray(_path);
        require(directories[path].created == 0, "Directory already exists");
        directories[path] = Directory({
            files: new string[](0),
            directories: new string[](0),
            created: block.timestamp,
            customPermissions: false
        });

        directories[encodeStringArray(getParentPath(_path))].directories.push(
            _path[_path.length - 1]
        );
    }

    /// @notice Removes a directory
    /// @param _path The path of the directory to remove
    function rmdir(
        string[] calldata _path
    ) public validPath(_path) writePermissions(getParentPath(_path), "") {
        bytes memory path = encodeStringArray(_path);
        delete directories[path];
        removeFromArray(
            directories[encodeStringArray(getParentPath(_path))].directories,
            _path[_path.length - 1]
        );
        // cannot delete permissions, be cautious when recreating a directory with the same path
    }

    /// @notice Sets custom permissions for a directory
    /// @param _path The path of the directory
    /// @param permissionLevel The permission level to set
    /// @param _permission The permission structure to apply
    function chmodDir(
        string[] memory _path,
        uint256 permissionLevel,
        Permission memory _permission
    ) external validPath(_path) onlyOwner {
        bytes memory path = encodeStringArray(_path);
        directories[path].customPermissions = true;
        dirPermissions[path][permissionLevel] = _permission;
    }

    /// @notice Represents the structure of a file
    struct File {
        string[] chunks;
        uint256 fileType;
        uint256 created;
        uint256 modified;
        bool customPermissions;
    }

    /// @notice Mapping of encoded paths and file names to File structures
    mapping(bytes => mapping(string => File)) private files;
    /// @notice Mapping of encoded paths, file names, and permission levels to their corresponding permissions
    mapping(bytes => mapping(string => mapping(uint256 => Permission)))
        private filePermissions;

    /// @notice Creates a new file or updates the modification time of an existing file
    /// @param _path The path where the file should be created or updated
    /// @param _fileName The name of the file
    function touch(
        string[] calldata _path,
        string calldata _fileName
    ) public validPath(_path) writePermissions(_path, _fileName) {
        bytes memory path = encodeStringArray(_path);
        if (files[path][_fileName].created == 0) {
            files[path][_fileName] = File({
                chunks: new string[](0),
                fileType: 0,
                created: block.timestamp,
                modified: block.timestamp,
                customPermissions: false
            });

            directories[encodeStringArray(_path)].files.push(_fileName);
        } else {
            files[path][_fileName].modified = block.timestamp;
        }
    }

    /// @notice Removes a file
    /// @param _path The path of the file to remove
    /// @param _fileName The name of the file to remove
    function rm(
        string[] calldata _path,
        string calldata _fileName
    ) public validPath(_path) writePermissions(_path, _fileName) {
        bytes memory path = encodeStringArray(_path);
        require(files[path][_fileName].created != 0, "File does not exist");

        // Remove the file content
        delete files[path][_fileName];

        // Remove the file from its parent directory
        bytes memory parentPath = encodeStringArray(getParentPath(_path));
        directories[parentPath].files = removeFromArray(
            directories[parentPath].files,
            _fileName
        );
    }

    /// @notice Updates a specific chunk of a file
    /// @param _path The path of the file to update
    /// @param _fileName The name of the file to update
    /// @param _content The new content for the chunk
    /// @param _chunkIndex The index of the chunk to update
    function nanoUpdate(
        string[] calldata _path,
        string calldata _fileName,
        string calldata _content,
        uint256 _chunkIndex
    ) public validPath(_path) writePermissions(_path, _fileName) {
        bytes memory path = encodeStringArray(_path);
        File storage file = files[path][_fileName];

        require(file.created != 0, "File does not exist");

        // Ensure the chunks array is large enough
        if (_chunkIndex >= file.chunks.length) {
            require(
                _chunkIndex == file.chunks.length,
                "Chunk index out of bounds"
            );
            file.chunks.push(_content);
        } else {
            // Only update if content is different
            require(
                keccak256(abi.encodePacked(_content)) !=
                    keccak256(abi.encodePacked(file.chunks[_chunkIndex])),
                "New content must be different from existing content"
            );
            file.chunks[_chunkIndex] = _content;
        }

        // Update the modified timestamp
        file.modified = block.timestamp;
    }

    /// @notice Retrieves a specific chunk of a file
    /// @param _path The path of the file
    /// @param _fileName The name of the file
    /// @param _chunkIndex The index of the chunk to retrieve
    /// @return The content of the specified chunk
    function fetchChunk(
        string[] calldata _path,
        string calldata _fileName,
        uint256 _chunkIndex
    )
        external
        view
        validPath(_path)
        readPermissions(_path, _fileName)
        returns (string memory)
    {
        bytes memory path = encodeStringArray(_path);
        require(files[path][_fileName].created != 0, "File does not exist");
        require(
            _chunkIndex < files[path][_fileName].chunks.length,
            "Chunk index out of bounds"
        );
        return files[path][_fileName].chunks[_chunkIndex];
    }

    /// @notice Sets custom permissions for a file
    /// @param _path The path of the file
    /// @param _fileName The name of the file
    /// @param permissionLevel The permission level to set
    /// @param _permission The permission structure to apply
    function chmod(
        string[] memory _path,
        string calldata _fileName,
        uint256 permissionLevel,
        Permission memory _permission
    ) external validPath(_path) writePermissions(_path, _fileName) {
        bytes memory path = encodeStringArray(_path);
        files[path][_fileName].customPermissions = true;
        filePermissions[path][_fileName][permissionLevel] = _permission;
    }

    /// @notice Removes an element from a string array
    /// @param arr The array to modify
    /// @param element The element to remove
    /// @return The modified array
    function removeFromArray(
        string[] storage arr,
        string memory element
    ) internal returns (string[] storage) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (keccak256(bytes(arr[i])) == keccak256(bytes(element))) {
                // Move the last element to the position of the item to be removed
                arr[i] = arr[arr.length - 1];
                // Remove the last element
                arr.pop();
                break;
            }
        }
        return arr;
    }

    /// @notice Encodes a string array into bytes
    /// @param arr The string array to encode
    /// @return The encoded bytes
    function encodeStringArray(
        string[] memory arr
    ) internal pure returns (bytes memory) {
        bytes memory encoded = abi.encode(arr);
        return encoded;
    }

    /// @notice Decodes bytes back into a string array
    /// @param encoded The encoded bytes to decode
    /// @return The decoded string array
    function decodeStringArray(
        bytes memory encoded
    ) internal pure returns (string[] memory) {
        string[] memory arr = abi.decode(encoded, (string[]));
        return arr;
    }
}
