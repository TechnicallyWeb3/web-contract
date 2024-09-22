## ERC: Transferrable File and Token Storage Contract

### Preamble

```
ERC: TBD
Title: Transferrable File and Token Storage Contract
Author: [Your Name]
Status: Draft
Type: Standards Track
Category: ERC
Created: 2023-10-XX
```

### Simple Summary

A standard interface for a smart contract that allows for the storage, management, and transfer of files and tokens, including Ether, ERC20, and ERC721 tokens, with support for ERC4804 URL standards.

### Abstract

This ERC proposes a standard for a smart contract that provides functionality for storing and managing files in chunks, redirecting to specific resources, handling token operations, and transferring ownership. The contract includes features for versioning, locking, admin management, and ENS domain renewal, and adheres to ERC4804 URL standards.

### Motivation

The need for a standardized contract that can handle complex file storage and token operations, while also providing robust access control and transfer mechanisms, is essential for decentralized applications. This proposal aims to create a versatile and secure contract that can be widely adopted, with support for ERC4804 URL standards to enhance interoperability.

### Specification

#### Data Structures

```solidity
struct Version {
    uint256 majorVersion;
    uint256 minorVersion;
    uint256 patchVersion;
}

struct ResourceFile {
    string[] content;
    string contentType;
}
```

#### State Variables

```solidity
uint256 public immutable MAJOR_VERSION;
uint256 public immutable MINOR_VERSION;
uint256 public immutable PATCH_VERSION;

uint256 private redirectChainId;
address private redirectAddress;
string private redirectIPFSHash;

bool private isLocked;
bool private isImmutable;

mapping(address => bool) private admins;
mapping(string => ResourceFile) private resourceChunks;
mapping(address => bool) private _approvals;
```

#### Events

```solidity
event ENSDomainRenewed(string name, uint256 duration, uint256 cost);
event Approval(address indexed owner, address indexed approved, bool approved);
```

#### Functions

```solidity
function webContractVersion() public pure returns (Version memory);

function getRedirectChainId() public view returns (uint256);
function setRedirectChainId(uint256 _chainId) public onlyOwner;

function getRedirectAddress() public view returns (address);
function setRedirectAddress(address _address) public onlyOwner;

function getRedirectIPFSHash() public view returns (string memory);
function setRedirectIPFSHash(string memory _hash) public onlyOwner;

function isLocked() public view returns (bool);
function lockContract() public onlyOwner;
function unlockContract() public onlyOwner;
function makeImmutable() public onlyOwner;

function addAdmin(address _admin) public onlyOwner;
function removeAdmin(address _admin) public onlyOwner;
function isAdmin(address _admin) public view returns (bool);

function setResourceChunk(
    string calldata _path,
    string calldata _content,
    string calldata _contentType,
    uint256 _chunkIndex
) public onlyAdmin notLocked;

function getResourceChunk(
    string memory path,
    uint256 index
) public view returns (string memory, string memory);

function getTotalChunks(string memory path) public view returns (uint256);
function removeResource(string memory path) public onlyAdmin notLocked;

function withdrawEther(address payable _to, uint256 _amount) public onlyOwner;
function withdrawERC20(address _tokenContract, address _to, uint256 _amount) public onlyOwner;
function withdrawERC721(address _tokenContract, address _to, uint256 _tokenId) public onlyOwner;

function onERC721Received(address, address, uint256, bytes memory) public returns (bytes4);

function renewENSDomain(string memory _name, uint256 _duration) public onlyOwner;

function approve(address to, bool approved) public onlyOwner;
function isApproved(address operator) public view returns (bool);

function transferFrom(address from, address to) public;
```

### Rationale

The proposed standard provides a comprehensive solution for managing files and tokens within a smart contract. By including features such as versioning, locking, admin management, and ENS domain renewal, the contract ensures robust access control and flexibility. The ability to transfer ownership and approve other addresses to manage the contract further enhances its utility. Adhering to ERC4804 URL standards ensures better interoperability and integration with other decentralized applications.

### Backwards Compatibility

This proposal does not conflict with existing ERC standards and can be implemented alongside other token standards such as ERC20 and ERC721.

### Implementation

An example implementation is provided in the `WebContractV5` contract.

### Security Considerations

- Ensure proper access control by using the `onlyOwner` and `onlyAdmin` modifiers.
- Validate inputs to prevent out-of-bounds errors and content type mismatches.
- Handle token transfers securely to prevent loss of funds.
- Use the `notLocked` modifier to prevent unauthorized operations when the contract is locked or immutable.

### References

- [ERC20: Token Standard](https://eips.ethereum.org/EIPS/eip-20)
- [ERC721: Non-Fungible Token Standard](https://eips.ethereum.org/EIPS/eip-721)
- [ERC4804: URL Standards](https://eips.ethereum.org/EIPS/eip-4804)
- [ENS: Ethereum Name Service](https://ens.domains/)
