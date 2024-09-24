# WTTP Specification (Web3 Transfer Transfer Protocol)

## 1. Introduction

WTTP is a protocol designed for WebContractV5 to enable linking and redirecting to resources on various blockchains and decentralized storage systems. This specification defines custom MIME types and redirect mechanisms for efficient content retrieval and management in Web3 environments.

## 2. Custom MIME Types

### 2.1 Redirect Types

- Format: `redirect/<SUBTYPE>`
- Subtypes:
  - `ipfs`: Redirects to IPFS content
  - `ordinals`: Redirects to Bitcoin Ordinals inscriptions
  - `<CHAIN_ID>`: Redirects to a specific blockchain (e.g., `redirect/1` for Ethereum mainnet)
  - `<CHAIN_ALIAS>`: Redirects using a chain alias (e.g., `redirect/eth`, `redirect/pol`)

### 2.2 Link Types

- Format: `link/<SUBTYPE>`
- Subtypes:
  - `ipfs`: Links to IPFS content
  - `ordinals`: Links to Bitcoin Ordinals inscriptions
  - `<CHAIN_ID>`: Links to a specific blockchain (e.g., `link/1`, `link/137`)
  - `<CHAIN_ALIAS>`: Links using a chain alias (e.g., `link/eth`, `link/goerli`, `link/pol`)

## 3. Redirect Codes

WTTP uses a uint8 redirect code system, allowing for expansion beyond traditional HTTP redirect codes:

- `0`: No redirect (default)
- `1`: Permanent redirect (similar to HTTP 301)
- `2`: Temporary redirect (similar to HTTP 302)
- `3`: See Other (similar to HTTP 303)
- `4`: Temporary redirect, preserve method (similar to HTTP 307)
- `5`: Permanent redirect, preserve method (similar to HTTP 308)

Codes 6-255 are reserved for future use or custom implementations.

## 4. Usage in WebContractV5

### 4.1 Contract-wide Redirect

Set a contract-wide redirect using the `setRedirect` function:

```solidity
function setRedirect(string memory _type, string memory _value, uint8 _code) public virtual onlyOwner
```

Example:
```solidity
contract.setRedirect("redirect/ipfs", "QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ", 1);
```

### 4.2 Resource-specific Links

Set a resource-specific link using the `setResourceChunk` function:

```solidity
function setResourceChunk(
    string calldata _path,
    string calldata _content,
    string calldata _contentType,
    uint256 _chunkIndex,
    uint8 _redirectCode
) public virtual onlyAdmin notLocked
```

Example:
```solidity
contract.setResourceChunk(
    "/example.json",
    "0x123...abc/1234",
    "link/1",
    0,
    2
);
```

## 5. Client-side Handling

Browsers or client applications should handle WTTP types as follows:

1. For contract-wide redirects:
   - Check the contract's redirect information first.
   - If a redirect is set, follow it according to the specified type and code.

2. For resource-specific links:
   - Interpret the `link/<SUBTYPE>` and retrieve content accordingly.
   - Apply the resource-specific redirect code if present.

3. Redirect code handling:
   - Codes 1-5: Handle similarly to their HTTP counterparts.
   - Codes 0 and 6-255: Implementation-specific behavior.

## 6. Examples

1. Contract-wide IPFS redirect:
   - Type: `redirect/ipfs`
   - Value: `QmW2WQi7j6c7UgJTarActp7tDNikE4B2qXtFCfLPdsgaTQ`
   - Code: `1` (Permanent)

2. Resource-specific Ethereum mainnet link:
   - Type: `link/1`
   - Value: `0x123...abc/1234`
   - Code: `2` (Temporary)

3. Resource-specific Polygon link using alias:
   - Type: `link/pol`
   - Value: `0x456...def/5678`
   - Code: `0` (No redirect)

## 7. Benefits

- Unified system for Web3 content addressing and redirects.
- Flexible content retrieval from various decentralized systems.
- Extensible redirect code system for future enhancements.
- Reduced redundant storage by linking to existing on-chain resources.