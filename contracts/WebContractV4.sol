// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@tw3/solidity/contracts/utils/Array.sol";
import "@tw3/solidity/contracts/utils/String.sol";

contract WebContract is Ownable {
    using String for string;
    using Array for string[];

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    struct ResourceChunk {
        string content;
        string contentType;
    }

    // Mappings to store content at specific paths
    mapping(string path => ResourceChunk[] content) private fileContent;
    mapping(string path => string[] structure) private directory;

    // Event to emit when content is added or updated
    event ContentUpdated(string contentType, string path, string newContent);

    modifier validPath(string calldata path, string memory fileType) {
        require(path.startsWith("/"), "path must start with '/'");
        require(
            path.endsWith(fileType.toLowerCase()),
            "invalid path: fileType"
        );
        require(
            !path.includes("//"),
            "all directories must contain at least 1 char"
        );
        _;
    }

    // Function to set or update HTML content
    function setHTML(
        string calldata path,
        string calldata content
    ) external validPath(path, ".html") {
        if (content.equals("")) {
            removePathComponents(path);
        } else {
            addPathComponents(path.toLowerCase());
        }

        htmlContent[path] = content;
        emit ContentUpdated("HTML", path, content);
    }

    // Function to set or update JavaScript content
    function setJS(
        string calldata path,
        string calldata content
    ) external validPath(path, ".js") {
        addPathComponents(path);
        jsContent[path] = content;
        emit ContentUpdated("JS", path, content);
    }

    // Function to set or update CSS content
    function setCSS(
        string calldata path,
        string calldata content
    ) external validPath(path, ".css") {
        addPathComponents(path);
        cssContent[path] = content;
        emit ContentUpdated("CSS", path, content);
    }

    // Function to retrieve HTML content
    function getHTML(
        string calldata path
    ) external view validPath(path, ".html") returns (string memory) {
        return htmlContent[path];
    }

    // Function to retrieve JavaScript content
    function getJS(
        string calldata path
    ) external view validPath(path, ".js") returns (string memory) {
        return jsContent[path];
    }

    // Function to retrieve CSS content
    function getCSS(
        string calldata path
    ) external view validPath(path, ".css") returns (string memory) {
        return cssContent[path];
    }

    // Function to get files and directories at a certain path
    function ls(
        string calldata path
    ) public view validPath(path, "/") returns (string[] memory) {
        return directory[path];
    }

    // this should be called from functions with the validPath modifier
    function addPathComponents(string calldata path) internal {
        string[] memory pathComponent = path.split("/");
        string memory currentDirectory = "/";

        for (uint256 i; i < pathComponent.length - 1; i++) {
            if (!directory[currentDirectory].includes(pathComponent[i + 1])) {
                directory[currentDirectory].push(pathComponent[i + 1]);
            }
            currentDirectory = i == 0
                ? string.concat(currentDirectory, pathComponent[i + 1]) // first path already includes / to check contract root
                : string.concat(currentDirectory, "/", pathComponent[i + 1]); // subsuquent paths will need / between the strings
        }
    }

    function removePathComponents(string calldata path) internal {
        string[] memory pathComponents = path.split("/");
        string memory currentDirectory = path;

        // Iterate from the end of the pathComponents array
        for (uint256 i = pathComponents.last(); i > 0; i--) {
            uint256 offset = i > 0 ? 1 : 0; // if index 0 the offset will be 0 to prevent removing the leading "/"
            uint256 componentLength = pathComponents[i].length();
            currentDirectory = currentDirectory.slice(
                0,
                int256(componentLength + offset)
            );
            // Remove the component from the current directory
            while (directory[currentDirectory].includes(pathComponents[i])) {
                directory[currentDirectory] = directory[currentDirectory]
                    .remove(
                        directory[currentDirectory].indexOf(pathComponents[i])
                    );
            }
        }
    }
}
