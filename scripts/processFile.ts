import { ethers } from "hardhat";
import fs from "fs";
import path from "path";
import config from "../webcontract.config";

async function processFile(filePath: string, relativePath: string) {
    // Check if contract address is defined
  if (!config.deployedContractAddress) {
    throw new Error("Deployed contract address is not defined in webcontract.config.ts");
  }

  // Get the contract instance
  const WebContract = await ethers.getContractFactory("WebContract");
  const webContract = WebContract.attach(config.deployedContractAddress);
  // Read local file
  const localContent = fs.readFileSync(filePath, "utf8");

  // Check if the file extension is in the assetTypes array
  const fileExtension = path.extname(filePath);
  if (config.assetTypes && config.assetTypes.includes(fileExtension)) {
    console.log(`Skipping ${relativePath} (asset type: ${fileExtension})`);
    return;
  }

  // Get file content from contract
  const contractFile = await webContract.getFile(relativePath);
  const contractContent = contractFile.content;

  console.log(`Comparing ${relativePath}:`);
  console.log("Local file content:", localContent);
  console.log("Contract file content:", contractContent);

  if (localContent === contractContent) {
    console.log("Contents match!");
  } else {
    console.log("Contents do not match.");
    console.log("Differences:");
    console.log(diffStrings(localContent, contractContent));

    console.log("Updating contract...");

    // Determine content type based on file extension
    let contentType: string;
    switch (path.extname(filePath).toLowerCase()) {
      case '.html':
        contentType = 'text/html';
        break;
      case '.css':
        contentType = 'text/css';
        break;
      case '.js':
        contentType = 'application/javascript';
        break;
      case '.json':
        contentType = 'application/json';
        break;
      case '.png':
        contentType = 'image/png';
        break;
      case '.jpg':
      case '.jpeg':
        contentType = 'image/jpeg';
        break;
      case '.gif':
        contentType = 'image/gif';
        break;
      case '.svg':
        contentType = 'image/svg+xml';
        break;
      case '.xml':
        contentType = 'application/xml';
        break;
      case '.pdf':
        contentType = 'application/pdf';
        break;
      case '.map':
        contentType = 'application/json';
        break;
      case '.ico':
        contentType = 'image/x-icon';
        break;
      case '.txt':
        contentType = 'text/plain';
        break;
      default:
        contentType = 'application/octet-stream';
    }

    // Update the file in the contract
    const chunkSize = 40 * 1024; // 40KB
    for (let i = 0; i < localContent.length; i += chunkSize) {
      const chunk = localContent.slice(i, i + chunkSize);
      let tx;
      if (i === 0) {
        // For the first chunk, use setFile to initialize the file
        tx = await webContract.setFile(relativePath, contentType, chunk);
      } else {
        // For subsequent chunks, use addToFile to append content
        tx = await webContract.addToFile(relativePath, chunk);
      }
      await tx.wait();
      console.log(`Chunk ${Math.floor(i / chunkSize) + 1} of ${Math.ceil(localContent.length / chunkSize)} uploaded for ${relativePath}`);
    }

    console.log(`File ${relativePath} updated in the contract.`);
  }
}

async function processDirectory(dirPath: string, baseDir: string) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dirPath, entry.name);
    const relativePath = path.relative(baseDir, fullPath);

    if (entry.isDirectory()) {
      await processDirectory(fullPath, baseDir);
    } else {
      await processFile(fullPath, relativePath);
    }
  }
}

async function main() {
  // Check if contract address is defined
  if (!config.deployedContractAddress) {
    throw new Error("Deployed contract address is not defined in webcontract.config.ts");
  }

  // Get the contract instance
  const WebContract = await ethers.getContractFactory("WebContract");
  const webContract = WebContract.attach(config.deployedContractAddress);

  const buildFolder = config.buildFolder;
  await processDirectory(buildFolder, buildFolder);

  console.log("All files processed.");
}

// Simple diff function to show differences
function diffStrings(str1: string, str2: string): string {
  const diff = [];
  const lines1 = str1.split("\n");
  const lines2 = str2.split("\n");
  const maxLines = Math.max(lines1.length, lines2.length);

  for (let i = 0; i < maxLines; i++) {
    if (lines1[i] !== lines2[i]) {
      diff.push(`Line ${i + 1}:`);
      diff.push(`- ${lines1[i] || ""}`);
      diff.push(`+ ${lines2[i] || ""}`);
    }
  }

  return diff.join("\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
