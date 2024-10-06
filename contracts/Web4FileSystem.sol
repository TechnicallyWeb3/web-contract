// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title IWeb4FileSystem
/// @notice Interface for the Web4FileSystem contract, defining core functionality.
interface IWeb4FileSystem is IERC165 {
    function getDataPointAddress(bytes memory data) external pure returns (bytes32);
    function concatBytes32Array(bytes32[] memory data) external pure returns (bytes memory);
    function splitToBytes32Array(bytes memory data) external pure returns (bytes32[] memory);
    function writeChunk(bytes memory data) external returns (bytes32 chunkAddress);
    function readChunk(bytes32 chunkAddress) external view returns (bytes memory);
}

/// @title Web4FileSystem
/// @notice A contract for storing and managing files in a decentralized manner.
/// @dev This contract implements a chunk-based file system for efficient storage and retrieval.
abstract contract Web4FileSystem is IWeb4FileSystem, ERC165 {

    /// @dev Struct representing a chunk of data in the file system.
    /// Each chunk contains metadata and content for efficient storage and retrieval.
    struct DataPoint {
        // bytes2 contentType;  /// @dev Type of content: 0x0000 (undefined), 0x0001 (filePart), etc.
        // bytes1 chunkVersion; /// @dev Version of the chunk format for future upgrades
        // bytes1 chunkLayer;   /// @dev Layer of the chunk in a hierarchical structure
        // bytes2 redirectType; /// @dev Type of redirection, if applicable
        // bytes4 chainId;      /// @dev ID of the blockchain where the chunk is stored
        // bytes2 encodingType; /// @dev Type of encoding used for the content
        bytes32 structure; // use to include all above fields plus future ones
        bytes content;       /// @dev Actual content of the chunk
    }

    struct DataPointAddress {
        address dpRegistry;
        bytes4 chainId;
        bytes32 dpHash;
        bytes8 futureUse;
    }

    /// @dev Mapping from chunk address to chunk content.
    mapping(bytes32 chunkAddress => DataPoint content) private dataChunks;

    /// @notice Calculates the keccak256 hash of the given data.
    /// @param data The data to hash.
    /// @return The keccak256 hash of the data, used as the chunk address.
    function getDataPointAddress(
        bytes4 typeWithEncoding,
        bytes memory data
    ) public pure virtual returns (bytes32) {
        return keccak256(abi.encodePacked(typeWithEncoding, data));
    }

    /// @notice Concatenates an array of bytes32 into a single bytes array.
    /// @param data The array of bytes32 to concatenate.
    /// @return A bytes array containing the concatenated data.
    function concatBytes32Array(
        bytes32[] memory data
    ) public pure returns (bytes memory) {
        return abi.encodePacked(data);
    }

    /// @notice Splits a bytes array into an array of bytes32.
    /// @param data The bytes array to split.
    /// @return An array of bytes32 containing the split data.
    function splitToBytes32Array(
        bytes memory data
    ) public pure returns (bytes32[] memory) {
        require(data.length % 32 == 0, "Invalid data length");
        bytes32[] memory result = new bytes32[](data.length / 32);
        assembly {
            calldatacopy(add(result, 32), add(data, 32), mload(data))
        }
        return result;
    }

    /// @notice Stores a chunk of data and maps it to its hash.
    /// @param content The data chunk to store.
    /// @return dpAddress The address (hash) of the stored chunk.
    function writeDataPoint(bytes32 structure, bytes memory content) public virtual returns (bytes32 dpAddress) {
        dpAddress = getDataPointAddress(content);
        dataChunks[dpAddress] = DataPoint(structure, content);
    }

    /// @notice Reads a chunk of data by its address.
    /// @param dpAddress The address of the chunk to read.
    /// @return The data chunk associated with the given address.
    function readDataPoint(
        bytes32 dpAddress
    ) public view virtual returns (bytes memory) {
        return dataChunks[dpAddress].content;
    }

    /// @notice Checks if the contract supports a given interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The interface identifier to check.
    /// @return bool True if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IWeb4FileSystem).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
