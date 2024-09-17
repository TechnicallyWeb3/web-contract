import { task, types } from "hardhat/config";
import fs from 'fs';
import path from 'path';

task("deploy-contract", "Deploy the WebContract or use existing deployment")
  .addPositionalParam("action", "Action to perform (use 'redeploy' to force redeployment)", "", types.string)
  .setAction(async ({ action }, hre) => {
    const ethers = hre.ethers;
    const packageJsonPath = path.join(__dirname, '..', 'package.json');
    const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
    const shouldDeploy = !packageJson.contract || action === "redeploy";

    const feeData = await hre.ethers.provider.getFeeData();
    console.log("Gas Price:", feeData);

    if (shouldDeploy) {
      console.log("Deploying WebContract...");
      const WebContract = await ethers.getContractFactory("WebsiteContract");
      console.log("Creating Factory...", WebContract);
      const webContract = await WebContract.deploy({gasPrice:feeData.gasPrice});
      console.log("Deployment Started...");
      await webContract.waitForDeployment();
      console.log("Deployment Complete...");
      const deployedAddress = await webContract.getAddress();

    // // Update webcontract.config.ts
    // // ... existing update code ...
    // const configPath = path.join(__dirname, '..', 'webcontract.config.ts');
    // let configContent = fs.readFileSync(configPath, 'utf8');
    // configContent = configContent.replace(
    //   /deployedContractAddress:\s*['"].*['"]/,
    //   `deployedContractAddress: '${deployedAddress}'`
    // );
    // fs.writeFileSync(configPath, configContent);

    // Update package.json with the new contract address
    packageJson.contract = deployedAddress;
    fs.writeFileSync(packageJsonPath, JSON.stringify(packageJson, null, 2));

      console.log("WebContract deployed to:", deployedAddress);
      console.log("package.json updated with new contract");
    } else {
      console.log("Skipping deployment. Use 'redeploy' as the action to force deployment.");
    }
  });
