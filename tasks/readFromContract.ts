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
      
      const resourceInfo = await websiteContract.getResource(fileName);
      const totalChunks = resourceInfo[0];
      console.log(`Total chunks for ${fileName}: ${totalChunks}`);

      if (Number(totalChunks) === 0) {
        console.log(`File ${fileName} is empty or does not exist.`);
        return;
      }

      let fullContent = "";
      let contentType = "";

      for (let i = 0; i < Number(totalChunks); i++) {
        const response = await websiteContract.getResourceChunk(fileName, i);
        const chunkContent = response[0];
        const chunkContentType = response[1];
        fullContent += chunkContent;
        if (i === 0) contentType = chunkContentType; // Assume all chunks have the same content type
      }

      // Convert hex string to readable text
      const decodedContent = Buffer.from(fullContent.slice(2), 'hex').toString('utf8');

      console.log(decodedContent);
      console.log(`File ${fileName} content:`);
      console.log(`Content Type: ${contentType}`);

    } catch (error: any) {
      console.error("Error reading file:", error.message);
      if (error.data) {
        console.error("Error data:", error.data);
      }
    }
  });
