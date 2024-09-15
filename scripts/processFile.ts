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

    // Determine content type (you might want to expand this logic)
    const contentType = path.extname(filePath).slice(1);

    // Update the file in the contract
    const tx = await webContract.setFile(relativePath, contentType, localContent);
    await tx.wait();

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
