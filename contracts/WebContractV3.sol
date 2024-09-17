// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract WebsiteContract {
    struct ResourceChunk {
        string content;
        string contentType;
    }

    mapping(string => ResourceChunk[]) private resourceChunks;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setResourceChunk(string memory path, string memory content, string memory contentType) public onlyOwner {
        resourceChunks[path].push(ResourceChunk(content, contentType));
    }

    function getResourceChunk(string memory path, uint256 index) public view returns (string memory, string memory) {
        require(index < resourceChunks[path].length, "Chunk does not exist");
        ResourceChunk memory chunk = resourceChunks[path][index];
        return (chunk.content, chunk.contentType);
    }

    function getTotalChunks(string memory path) public view returns (uint256) {
        return resourceChunks[path].length;
    }

    function removeResource(string memory path) public onlyOwner {
        delete resourceChunks[path];
    }
}
