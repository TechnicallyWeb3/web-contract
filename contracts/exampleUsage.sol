// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;  

import {WebContract} from "@tw3/solidity/contracts/WebContract.sol";

contract MyWebContract is WebContract {

    constructor() WebContract(msg.sender) {}

    function setSmallFile(string calldata path, string calldata contentType, string calldata content) external onlyOwner {
        setResourceChunk(path, content, contentType, 0);
    }
}