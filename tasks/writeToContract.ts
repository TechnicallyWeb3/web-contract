import { task, types } from "hardhat/config";
import fs from 'fs/promises';
import path from 'path';
import { WebsiteContract } from "../typechain-types";

task("write-to-contract", "Write files to the smart contract")
  .addOptionalParam("filePath", "Relative path of the file to upload (from build folder)", "", types.string)
  .addOptionalParam("key", "Key to write the file to in the contract", "", types.string)
  .setAction(async ({ filePath, key }, hre) => {
    const config = require('../webcontract.config').default;
    const buildFolder = path.resolve(config.buildFolder);
    const deployFolder = path.join(__dirname, '..', 'deploy');
    const manifestPath = path.join(deployFolder, 'manifest.json');
    const ethers = hre.ethers;

    key = key || filePath;

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

    async function processFile(filePath: string, key: string) {
      const relativePath = path.relative(buildFolder, filePath);
      const fileExtension = path.extname(filePath).toLowerCase();
      const targetKey = key || relativePath; // Use the provided key or default to relativePath

      if (!manifest.ipfsFiles[relativePath]) {
        console.log(`Processing ${relativePath}...`);
        console.log(`Reading file: ${filePath}`);
        let content = await fs.readFile(filePath);
        console.log(`File content length: ${content.length} characters`);

        const contentType = getContentType(fileExtension);
        console.log(`Determined content type: ${contentType}`);

        // Check if any files are in the IPFS manifest
        const ipfsFiles = Object.entries(manifest.ipfsFiles);
        console.log(`Number of IPFS files in manifest: ${ipfsFiles.length}`);

        // for (const [ipfsPath, ipfsHash] of ipfsFiles) {
        //   console.log(`Processing IPFS file: ${ipfsPath}`);
        //   const ipfsUrl = config.ipfsPath.replace('{cid}', ipfsHash);
        //   // console.log(`Generated IPFS URL: ${ipfsUrl}`);
        //   const regex = new RegExp(ipfsPath, 'g');
        //   // console.log(`Created regex: ${regex}`);
        //   if (content.match(regex)) {
        //     console.log(`Found reference to ${ipfsPath} in ${relativePath}. Replacing with IPFS URL: ${ipfsUrl}`);
        //     content = content.replace(regex, ipfsUrl);
        //   }
        // }

        // If the file itself is in IPFS, use the IPFS URL instead of the content
        if (manifest.ipfsFiles[relativePath]) {
          const ipfsHash = manifest.ipfsFiles[relativePath];
          const ipfsUrl = config.ipfsPath.replace('{cid}', ipfsHash);
          console.log(`File ${relativePath} is on IPFS. Using IPFS URL: ${ipfsUrl}`);
          // console.log(`Original content length: ${content.length}`);
          content = ipfsUrl;
          // console.log(`New content (IPFS URL): ${content}`);
        } else {
          console.log(`File ${relativePath} is not on IPFS. Using original content.`);
        }

        async function writeChunks(content: Buffer) {
          // console.log(`Starting writeChunks for ${relativePath}`);
          const chunkSize = 16 * 1024; // 16KB chunks
          console.log(`Chunk size: ${chunkSize} bytes`);
          let transactionHash: string = '';
          let contentChanged = false;

          console.log(`Total content length: ${content.length}`);
          console.log(`Number of chunks: ${Math.ceil(content.length / chunkSize)}`);

          for (let i = 0; i < content.length; i += chunkSize) {
            let _chunkIndex = Math.floor(i / chunkSize);
            console.log(`Processing chunk ${_chunkIndex}`);
            const chunk = content.subarray(i, i + chunkSize);
            console.log(`Read chunk: ${_chunkIndex} @ ${relativePath}`);
            let existingChunk: [Buffer, string] = [Buffer.alloc(0), ''];
            try {
              const [existingContent, existingContentType] = await websiteContract.getResourceChunk(targetKey, _chunkIndex);
              existingChunk = [Buffer.from(existingContent), existingContentType];
            } catch (error) {
              console.log(`Chunk ${_chunkIndex} doesn't exist yet. Creating new chunk.`);
            }
            console.log(`Existing chunk length: ${existingChunk[0].length}`);
            console.log(`New chunk length: ${chunk.length}`);

            console.log(`Comparing new chunk with existing chunk...`);
            const newChunkHex = `0x${chunk.toString('hex')}`;
            const existingChunkUtf8 = existingChunk[0].toString('utf8');
            if (newChunkHex !== existingChunkUtf8) {
              console.log(`Chunks are different. Logging first 50 bytes of each:`);
              // console.log(`New chunk (hex): ${newChunkHex.slice(0, 50)}...`);
              // console.log(`Existing chunk (utf8): ${existingChunkUtf8.slice(0, 50)}...`);
              // console.log(`Content matches: ${newChunkHex === existingChunkUtf8}`)
              console.log('target key is: ', targetKey);

              const tx = await websiteContract.setResourceChunk(
                targetKey,   // Use targetKey instead of relativePath
                chunk,       // _content
                contentType, // _contentType
                _chunkIndex, // _chunkIndex
                0             // _redirectCode, assuming 0 since writing to contract
              );
              await tx.wait();
              transactionHash = tx.hash;
              contentChanged = true;
              console.log(`Chunk ${_chunkIndex} of ${Math.ceil(content.length / chunkSize)} updated for ${relativePath}`);
            } else {
              console.log(`Chunks are identical.`);
            }
          }

          return { transactionHash, contentChanged };
        }

        // Proceed with writing to the contract (either modified content or IPFS URL)
        const { transactionHash, contentChanged } = await writeChunks(content);

        if (contentChanged) {
          manifest.contractFiles[transactionHash] = relativePath;
          console.log(`File ${relativePath} updated in contract. Transaction hash: ${transactionHash}`);
        } else {
          console.log(`File ${relativePath} unchanged. No updates needed.`);
        }
      }
    }

    async function processDirectory(dirPath: string) {
      const entries = await fs.readdir(dirPath, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dirPath, entry.name);
        if (entry.isDirectory()) {
          await processDirectory(fullPath);
        } else {
          await processFile(fullPath, key);
        }
      }
    }

    async function processSpecificFile(specificPath: string, key: string) {
      const fullPath = path.join(buildFolder, specificPath);
      try {
        await fs.access(fullPath);
        await processFile(fullPath, key);
      } catch (error) {
        console.error(`Error: File not found - ${error}`);
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
      if (filePath) {
        await processSpecificFile(filePath, key);
      } else {
        await processDirectory(buildFolder);
      }
      await fs.writeFile(manifestPath, JSON.stringify(manifest, null, 2));
      console.log(`Manifest updated at ${manifestPath}`);
    } catch (error) {
      console.error("Error during contract write:", error);
    }
  });
