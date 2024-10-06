// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WebContract is Ownable {
    mapping(string path => string content) private fileContent;

    function setFileContent(
        string calldata path,
        string calldata content
    ) public {
        fileContent[path] = content;
    }

    function addToFileContent(
        string calldata path,
        string calldata content
    ) public {
        fileContent[path] = string.concat(fileContent[path], content);
    }

    function getFileContent(
        string calldata path
    ) public view returns (string memory) {
        return fileContent[path];
    }
}
