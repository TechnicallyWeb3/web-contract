import { task } from "hardhat/config";
import { WebsiteContract } from "../typechain-types";

task("read-from-contract", "Read files from the smart contract")
  .addPositionalParam("fileName", "Name of the file to read")
  .setAction(async (taskArgs, hre) => {
    const fileName = taskArgs.fileName;
    console.log(`Reading file: ${fileName}`);

    const ethers = hre.ethers;
    const WebsiteContract = await ethers.getContractFactory("WebsiteContract");
    const packageJson = require('../package.json');
    const websiteContract = WebsiteContract.attach(packageJson.contract) as WebsiteContract;

    try {
      console.log("Contract address:", websiteContract.target);
      let decodedContent = '';
      const resourceInfo = await websiteContract.getResource(fileName);
      const content = resourceInfo[0];
      const contentType = resourceInfo[1];
      //console.log(`content: ${content}`);

      // Check if the content is empty
      if (content.length === 0) {
        console.log("No content found for this file.");
        return;
      } else {
        // console.log('content.slice(2):', remove0x);
        decodedContent = Buffer.from(content.substring(2), 'hex').toString('utf8');
        console.log(`decodedContent: ${decodedContent}`);
        console.log(`Content Type: ${contentType}`);

      }
      

    } catch (error: any) {
      console.error("Error reading file:", error.message);
      if (error.data) {
        console.error("Error data:", error.data);
      }
    }
  });
