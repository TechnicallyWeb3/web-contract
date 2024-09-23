import { task } from "hardhat/config";
import fs from 'fs/promises';
import path from 'path';
import { create } from 'ipfs-http-client';
import config from "../webcontract.config";
import ignore from 'ignore';

const IPFS_URL = 'https://ipfs.infura.io:5001/api/v0';

task("build-ordinal", "Process build files, upload to IPFS if needed, and update ordinals.json")
  .setAction(async (_, { ethers }) => {
    const buildFolder = path.resolve(config.buildFolder);
    const ordinalsJsonPath = path.join(__dirname, '..', 'deploy', 'ordinals.json');
    const web4ignorePath = path.join(__dirname, '..', '.web4ignore');
    
    let ordinalsJson: {
      index: {
        redirect_type: string,
        redirect_value: string,
        entrypoint: string,
        next_chunk?: { link_type: string, link_value: string },
        previous_revision?: { link_type: string, link_value: string }
      },
      files: Record<string, {
        contentType: string,
        link_type: string,
        chunks: Record<string, { link_value?: string, data?: string }>
      }>
    } = {
      index: {
        redirect_type: "none",
        redirect_value: "",
        entrypoint: "index.html"
      },
      files: {}
    };

    const ipfs = create({ url: IPFS_URL });

    // Read and parse .web4ignore file
    const ignoreRules = ignore().add((await fs.readFile(web4ignorePath)).toString());

    async function processFile(filePath: string) {
      const stats = await fs.stat(filePath);
      const relativePath = path.relative(buildFolder, filePath);
      
      // Check if the file should be ignored
      if (ignoreRules.ignores(relativePath)) {
        console.log(`Ignoring file: ${relativePath}`);
        return;
      }

      const fileExtension = path.extname(filePath).toLowerCase();
      const contentType = getContentType(fileExtension);

      let linkType: string;
      let linkValue: string;
      let fileContent: string | Buffer;

      if (stats.size > config.assetLimit || !config.fileTypes.includes(fileExtension)) {
        // Upload to IPFS
        fileContent = await fs.readFile(filePath);
        const result = await ipfs.add(fileContent);
        linkType = "ipfs";
        linkValue = result.cid.toString();
      } else {
        // Store raw content
        fileContent = (await fs.readFile(filePath)).toString();
        linkType = "raw";
        linkValue = fileContent;
      }

      ordinalsJson.files[relativePath] = {
        contentType,
        link_type: linkType,
        chunks: {
          "0": linkType === "raw" ? { data: linkValue } : { link_value: linkValue }
        }
      };

      console.log(`Processed ${relativePath}: ${linkType}`);
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
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml'
      };
      return contentTypes[fileExtension] || 'application/octet-stream';
    }

    try {
      await processDirectory(buildFolder);
      await fs.writeFile(ordinalsJsonPath, JSON.stringify(ordinalsJson, null, 2));
      console.log(`ordinals.json updated at ${ordinalsJsonPath}`);
    } catch (error) {
      console.error("Error during processing:", error);
    }
  });
