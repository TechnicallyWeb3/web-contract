import { task, types } from "hardhat/config";
import fs from 'fs/promises';
import path from 'path';
import { WebsiteContract } from "../typechain-types";

task("write-to-contract", "Write files to the smart contract")
  .addPositionalParam("action", "Action to perform (use 'force' to force rewrite)", "", types.string)
  .setAction(async ({ action }, hre) => {
    const config = require('../webcontract.config').default;
    const buildFolder = path.resolve(config.buildFolder);
    const deployFolder = path.join(__dirname, '..', 'deploy');
    const manifestPath = path.join(deployFolder, 'manifest.json');
    const ethers = hre.ethers;

    let manifest: { ipfsFiles: Record<string, string>, contractFiles: Record<string, string> };

    try {
      const existingManifest = await fs.readFile(manifestPath, 'utf8');
      manifest = JSON.parse(existingManifest);
    } catch (error) {
      console.log("No existing manifest found. Creating a new one.");
      manifest = { ipfsFiles: {}, contractFiles: {} };
    }

    if (!manifest.contractFiles) {
      manifest.contractFiles = {};
    }

    const WebsiteContract = await ethers.getContractFactory("WebsiteContract");
    const packageJson = require('../package.json');
    const websiteContract = WebsiteContract.attach(packageJson.contract) as WebsiteContract;

    async function processFile(filePath: string) {
      const relativePath = path.relative(buildFolder, filePath);
      const fileExtension = path.extname(filePath).toLowerCase();

      if (!manifest.ipfsFiles[relativePath] && config.fileTypes.includes(fileExtension)) {
        console.log(`Processing ${relativePath}...`);
        let content = await fs.readFile(filePath, 'utf8');
        const contentType = getContentType(fileExtension);

        // Check if any files are in the IPFS manifest
        const ipfsFiles = Object.entries(manifest.ipfsFiles);
        for (const [ipfsPath, ipfsHash] of ipfsFiles) {
          const ipfsUrl = config.ipfsPath.replace('{cid}', ipfsHash);
          const regex = new RegExp(ipfsPath, 'g');
          
          if (content.match(regex)) {
            console.log(`Found reference to ${ipfsPath} in ${relativePath}. Replacing with IPFS URL: ${ipfsUrl}`);
            content = content.replace(regex, ipfsUrl);
          }
        }

        // If the file itself is in IPFS, use the IPFS URL instead of the content
        if (manifest.ipfsFiles[relativePath]) {
          const ipfsHash = manifest.ipfsFiles[relativePath];
          const ipfsUrl = config.ipfsPath.replace('{cid}', ipfsHash);
          console.log(`File ${relativePath} is on IPFS. Using IPFS URL: ${ipfsUrl}`);
          content = ipfsUrl;
        }

        // Proceed with writing to the contract (either modified content or IPFS URL)
        const chunkSize = 24 * 1024; // 24KB chunks
        let transactionHash: string = '';

        // Remove existing resource if force flag is set
        if (action === 'force') {
          await websiteContract.removeResource(relativePath);
          console.log(`Removed existing resource: ${relativePath}`);
        }

        for (let i = 0; i < content.length; i += chunkSize) {
          const chunk = content.slice(i, i + chunkSize);
          const tx = await websiteContract.setResourceChunk(relativePath, chunk, contentType);
          await tx.wait();
          transactionHash = tx.hash;
          console.log(`Chunk ${Math.floor(i / chunkSize) + 1} of ${Math.ceil(content.length / chunkSize)} uploaded for ${relativePath}`);
        }

        manifest.contractFiles[transactionHash] = relativePath;
        console.log(`File ${relativePath} written to contract. Transaction hash: ${transactionHash}`);
      }
    }

    async function processDirectory(dirPath: string) {
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dirPath, entry.name);
        if (entry.isDirectory()) {
          await processDirectory(fullPath);
        } else {
          await processFile(fullPath);
        }
      }
    }

    function getContentType(fileExtension: string): string {
      const contentTypes: Record<string, string> = {
        '.html': 'text/html',
        '.htm': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.xml': 'application/xml',
        '.pdf': 'application/pdf',
        '.map': 'application/json',
        '.ico': 'image/x-icon',
        '.txt': 'text/plain'
      };
      return contentTypes[fileExtension.toLowerCase()] || 'application/octet-stream';
    }

    try {
      await processDirectory(buildFolder);
      await fs.writeFile(manifestPath, JSON.stringify(manifest, null, 2));
      console.log(`Manifest updated at ${manifestPath}`);
    } catch (error) {
      console.error("Error during contract write:", error);
    }
  });
