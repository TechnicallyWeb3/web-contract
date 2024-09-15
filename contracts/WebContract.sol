// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20 < 0.9.0;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/Ownable.sol";

contract WebContract is Ownable {

    constructor() Ownable(msg.sender) {}

    struct WebFile {
        string contentType;
        string content;
    }

    mapping ( string path => WebFile) private file;

    function setFile(string path, string contentType, string content) public onlyOwner {
        file[path] = WebFile(contentType, content);
    }

    function addToFile(string path, string calldata content) public onlyOwner {
        file[path].content = string.concat(file[path].content, content);
    }

    function getFile(string path) public view returns (WebFile) {
        return file[path];
    }

}

