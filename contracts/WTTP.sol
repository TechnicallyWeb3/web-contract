// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Web3TransferProtocol is Ownable {
    // Function to encode string array to bytes
    function encodeStringArray(string[] memory arr)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory encoded = abi.encode(arr);
        return encoded;
    }

    // Function to decode bytes back to string array
    function decodeStringArray(bytes memory encoded)
        internal
        pure
        returns (string[] memory)
    {
        string[] memory arr = abi.decode(encoded, (string[]));
        return arr;
    }

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

    /// @dev Versioning system for the protocol
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }

    uint256 immutable majorVersion = 0;
    uint256 immutable minorVersion = 1;
    uint256 immutable patchVersion = 0;

    function getVersion() public pure returns (Version memory) {
        return Version(majorVersion, minorVersion, patchVersion);
    }

    bool public isLocked;
    function lockFS() external onlyOwner {
        isLocked = true;
    }

    uint256 public redirectChainId;
    function setRedirectChainId(uint256 _chainId) external onlyOwner {
        redirectChainId = _chainId;
    }

    string public redirectIPFSHash;
    function setRedirectIPFSHash(string memory _hash) external onlyOwner {
        redirectIPFSHash = _hash;
    }

    /// @dev encoding tools for path strings
    // Function to encode string array to bytes
    // function encodeStringArray(string[] memory arr) internal pure returns (bytes memory) {
    //     bytes memory encoded = abi.encode(arr);
    //     return encoded;
    // }

    // // Function to decode bytes back to string array
    // function decodeStringArray(bytes memory encoded) internal pure returns (string[] memory) {
    //     string[] memory arr = abi.decode(encoded, (string[]));
    //     return arr;
    // }

    /// @dev Permission structure
    struct Permission {
        bool read;
        bool write;
        bool execute;
    }

    // default permission levels for groups
    mapping(uint8 => Permission) private permissionLevels;
    // user group permissions
    mapping(address => uint8) private userPermissions;

    function setDefaultPermissionLevel(
        uint8 _groupId,
        Permission calldata group
    ) public onlyOwner {
        permissionLevels[_groupId] = group;
    }

    function setUserPermissionLevel(address _user, uint8 _permissionLevel) public onlyOwner {
        userPermissions[_user] = _permissionLevel;
    }

    modifier writePermissions(
        string[] memory _path,
        string memory _fileName
    ) {
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

    modifier readPermissions(
        string[] memory _path,
        string memory _fileName
    ) {
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

    /// @dev Directory structure
    struct Directory {
        string[] files;
        string[] directories;
        uint256 created;
        bool customPermissions;
    }

    modifier validPath(string[] memory _path) {
        require(_path.length > 0, "Path is empty");
        require(
            keccak256(abi.encodePacked(_path[0])) ==
                keccak256(abi.encodePacked("/")),
            "Path must start with /"
        );
        require(directories[encodeStringArray(_path)].created != 0, "Path does not exist");
        _;
    }

    function getParentPath(string[] calldata _path)
        internal
        pure
        returns (string[] memory)
    {
        require(_path.length > 1, "Path has no parent");
        string[] memory parentPath = new string[](_path.length - 1);
        for (uint256 i = 0; i < _path.length - 1; i++) {
            parentPath[i] = _path[i];
        }
        return parentPath;
    }

    mapping(bytes => Directory) private directories;
    mapping(bytes => mapping(uint256 => Permission)) private dirPermissions;

    // Function to list contents of a directory
    function ls(string[] calldata _path)
        external
        view
        validPath(_path)
        readPermissions(_path, "")
        returns (Directory memory)
    {
        return directories[encodeStringArray(_path)];
    }

    // Function to create a new directory
    function mkdir(string[] calldata _path)
        external
        validPath(getParentPath(_path))
        writePermissions(_path, "")
    {
        bytes memory path = encodeStringArray(_path);
        require(directories[path].created == 0, "Directory already exists");
        directories[path] = Directory({
            files: new string[](0),
            directories: new string[](0),
            created: block.timestamp,
            customPermissions: false
        });

        directories[encodeStringArray(getParentPath(_path))].directories.push(_path[_path.length - 1]);
    }

    // Function to remove a directory
    function rmdir(string[] calldata _path)
        public
        validPath(_path)
        writePermissions(getParentPath(_path), "")
    {
        bytes memory path = encodeStringArray(_path);
        delete directories[path];
        // cannot delete permissions, be cautious when recreating a directory with the same path
    }

    // Function to set custom permissions for a directory
    function chmodDir(
        string[] memory _path,
        uint256 permissionLevel,
        Permission memory _permission
    ) external validPath(_path) onlyOwner {
        bytes memory path = encodeStringArray(_path);
        directories[path].customPermissions = true;
        dirPermissions[path][permissionLevel] = _permission;
    }

    struct File {
        string[] chunks;
        uint256 fileType;
        uint256 created;
        uint256 modified;
        bool customPermissions;
    }

    mapping(bytes => mapping(string => File)) private files;
    mapping(bytes => mapping(string => mapping(uint256 => Permission)))
        private filePermissions;

    // // Function to add an item to a directory
    // function addToDirectory(string memory dirPath, string memory item) internal {
    //     require(isDirectory[dirPath], "Directory does not exist");
    //     directories[dirPath].push(item);
    // }

    // // Function to remove an item from a directory
    // function removeFromDirectory(string memory dirPath, string memory item) internal {
    //     require(isDirectory[dirPath], "Directory does not exist");
    //     uint256 length = directories[dirPath].length;
    //     for (uint256 i = 0; i < length; i++) {
    //         if (keccak256(bytes(directories[dirPath][i])) == keccak256(bytes(item))) {
    //             // Move the last element to the position of the item to be removed
    //             directories[dirPath][i] = directories[dirPath][length - 1];
    //             // Remove the last element
    //             directories[dirPath].pop();
    //             break;
    //         }
    //     }
    // }

    // Function to create a new file
    function touch(string[] calldata _path, string calldata _fileName)
        public
        validPath(_path)
        writePermissions(_path, _fileName)
    {
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

    // Function to remove a file
    function rm(string[] calldata _path, string calldata _fileName)
        public
        validPath(_path)
        writePermissions(_path, _fileName)
    {
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

    // Helper function to remove an element from a string array
    function removeFromArray(string[] storage arr, string memory element)
        internal
        returns (string[] storage)
    {
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
}
