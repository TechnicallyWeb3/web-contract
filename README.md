# web-contract
A package to deploy your react app as a smart contract for use with a web3 browser.

## Using Tasks

This project includes several Hardhat tasks to help you deploy, manage, and interact with your smart contract. Here's how to use them:

### Deploy Contract

To deploy the WebContract or use an existing deployment:

```bash
npx hardhat deploy-contract [action] --network <network-name>
```
- `[action]`: Optional. Use 'redeploy' to force redeployment.
- `--network`: Optional. The network to deploy to, if not specified, the hardhat VM network will be used.

### Upload to IPFS

To upload large and unsupported assets to IPFS:

```bash
npx hardhat upload-ipfs-assets [action] --network <network-name>
```
- `[action]`: Optional. Use 'force' to force reupload.
- `--network`: Optional. The network to upload to, if not specified, the hardhat VM network will be used.

### Write to Contract

To write files to the smart contract:

```bash
npx hardhat write-to-contract [action] --network <network-name>
```
- `[action]`: Optional. Use 'force' to force rewrite.
- `--network`: Optional. The network to write to, if not specified, the hardhat VM network will be used.