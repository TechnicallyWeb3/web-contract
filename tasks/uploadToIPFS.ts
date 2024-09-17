import { task, types } from "hardhat/config";
import fs from 'fs/promises';
import { createReadStream } from 'fs';
import path from 'path';
import PinataClient, { PinataPinOptions } from '@pinata/sdk';

task("upload-ipfs-assets", "Upload large and unsupported assets to IPFS")
    .addPositionalParam("action", "Action to perform (use 'force' to force reupload)", "", types.string)
    .setAction(async ({ action }, hre) => {
        const config = require('../webcontract.config').default;
        const pinataSDK = require('@pinata/sdk');

        if (!config.pinata || !config.pinata.apiKey || !config.pinata.apiSecret) {
            console.log("Pinata configuration not found. Skipping IPFS upload.");
            return;
        }

        const pinata: PinataClient = new pinataSDK(config.pinata.apiKey, config.pinata.apiSecret);
        const buildFolder = path.resolve(config.buildFolder);
        const deployFolder = path.join(__dirname, '..', 'deploy');
        const manifestPath = path.join(deployFolder, 'manifest.json');

        interface Manifest {
            ipfsFiles: Record<string, string>;
        }

        let manifest: Manifest = { ipfsFiles: {} };

        // Load existing manifest if it exists
        try {
            const existingManifest = await fs.readFile(manifestPath, 'utf8');
            manifest = JSON.parse(existingManifest);
        } catch (error) {
            console.log("No existing manifest found. Creating a new one.");
        }

        async function processFile(filePath: string) {
            const stats = await fs.stat(filePath);
            const relativePath = path.relative(buildFolder, filePath);
            const fileExtension = path.extname(filePath).toLowerCase();

            if (
                !config.fileTypes.includes(fileExtension) ||
                stats.size > config.assetLimit
            ) {

                console.log(`Uploading ${relativePath} to IPFS...`);
                const readableStream = createReadStream(filePath);
                const options: PinataPinOptions = {
                    pinataMetadata: {
                        name: path.basename(filePath),
                    },
                };
                const result = await pinata.pinFileToIPFS(readableStream, options);
                manifest.ipfsFiles[relativePath] = result.IpfsHash;
                console.log(`Uploaded ${relativePath} to IPFS: ${result.IpfsHash}`);
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

        // async function uploadToPinata(filePath: string) {
        //     const url = `https://api.pinata.cloud/pinning/pinFileToIPFS`;

        //     let data = new FormData();
        //     data.append('file', fs.createReadStream(filePath));

        //     console.log(`Uploading ${filePath} to Pinata...`);
        //     const response = await axios.post(url, data, {
        //       maxBodyLength: 'Infinity',
        //       headers: {
        //         'Content-Type': `multipart/form-data; boundary=${data._boundary}`,
        //         pinata_api_key: config.pinata.apiKey,
        //         pinata_secret_api_key: config.pinata.apiSecret
        //       }
        //     });

        //     console.log(`Successfully uploaded ${filePath} to Pinata. IPFS hash: ${response.data.IpfsHash}`);
        //     return response.data.IpfsHash;
        //   }

        try {
            await fs.mkdir(deployFolder, { recursive: true });
            await processDirectory(buildFolder);
            await fs.writeFile(manifestPath, JSON.stringify(manifest, null, 2));
            console.log(`Manifest updated at ${manifestPath}`);
        } catch (error) {
            console.error("Error during IPFS upload:", error);
        }
    });

