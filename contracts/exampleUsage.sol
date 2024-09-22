// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;  

import {WebContractV5} from "./WebContractV5.sol";

contract MyWebContract is WebContractV5 {

    constructor() WebContractV5(msg.sender) {}

    function setSmallFile(string calldata path, string calldata contentType, string calldata content) external onlyOwner {
        file[path] = WebFile(contentType, [content]);
    }

}
