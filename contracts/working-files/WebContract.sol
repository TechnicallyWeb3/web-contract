// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20 < 0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract WebContract is Ownable {

    constructor() Ownable(msg.sender) {}

    struct WebFile {
        string contentType;
        string content;
    }

    mapping ( string path => WebFile) private file;

    // used to create, update or delete a file
    function setFile(string calldata path, string calldata contentType, string calldata content) external onlyOwner {
        file[path] = WebFile(contentType, content);
    }

    // used to append content to a file when chunking is required
    function addToFile(string calldata path, string calldata content) external onlyOwner {
        file[path].content = string.concat(file[path].content, content);
    }

    // used to get a complete file
    function getFile(string calldata path) external view returns (WebFile memory) {
        return file[path];
    }

}

