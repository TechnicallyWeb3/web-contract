import { ethers } from "hardhat";

async function main() {
  console.log("Deploying WebContract...");

  // Deploy the contract
  const WebContract = await ethers.getContractFactory("WebContract");
  const webContract = await WebContract.deploy();

  // Wait for the contract to be deployed
  await webContract.waitForDeployment();

  // Get the deployed contract address
  const deployedAddress = await webContract.getAddress();

  console.log("Updating webcontract.config.ts with the deployed address...");

  // Read the current config file
  const fs = require('fs');
  const path = require('path');
  const configPath = path.join(__dirname, '..', 'webcontract.config.ts');
  let configContent = fs.readFileSync(configPath, 'utf8');

  // Replace the existing address (including empty strings) with the actual deployed address
  configContent = configContent.replace(
    /deployedContractAddress:\s*['"].*['"]/,
    `deployedContractAddress: '${deployedAddress}'`
  );

  // Write the updated config back to the file
  fs.writeFileSync(configPath, configContent);

  console.log("webcontract.config.ts updated successfully.");

  console.log("WebContract deployed to:", webContract.target);
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
