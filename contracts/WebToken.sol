// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./WebContract.sol";

contract WebsiteContract is WebContractToken {
    constructor() WebContractToken(msg.sender) {
        // Additional constructor logic can be added here
    }
}
