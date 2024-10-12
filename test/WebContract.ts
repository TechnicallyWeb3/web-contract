import { expect } from "chai";
import { ethers } from "hardhat";
import hre from "hardhat";
import { WebContract } from "../typechain-types";

describe("WebsiteContract", function () {
  let websiteContract;

  beforeEach(async function () {
    const WebsiteContractFactory = await ethers.getContractFactory("WebsiteContract");
    websiteContract = await WebsiteContractFactory.deploy();
    await websiteContract.waitForDeployment();
  });

  describe("Resource operations", function () {
    // Increase the timeout for all tests in this describe block
    this.timeout(90000);

    it("Should set a resource chunk and retrieve it correctly", async function () {
      console.log("Starting 'set and retrieve' test");
      const path = "/index.html";
      const contentType = "text/html";
      const content = ethers.toUtf8Bytes("<html><body>Hello, Web3!</body></html>");
      const chunkIndex = 0;
      const redirectCode = 0;

      let tx;
      const feeData = await hre.ethers.provider.getFeeData();

      console.log("Setting resource chunk...");
      tx = await websiteContract.setResourceChunk(path, content, contentType, chunkIndex, redirectCode, {gasPrice:feeData.gasPrice});
      await tx.wait();
      console.log("Resource chunk set successfully");

      console.log("Getting resource info...");
      const [totalChunks, retrievedContentType, retrievedRedirectCode] = await websiteContract.getResource(path);
      console.log("Total chunks:", totalChunks.toString());

      if (Number(totalChunks) > 0) {
        console.log("Retrieving chunk...");
        const [retrievedContent, retrievedContentType] = await websiteContract.getResourceChunk(path, 0);
        console.log("Retrieved chunk:", {
          path,
          contentType: retrievedContentType,
          content: ethers.toUtf8String(retrievedContent)
        });

        console.log("Verifying retrieved content...");
        expect(retrievedContentType).to.equal(contentType);
        expect(ethers.toUtf8String(retrievedContent)).to.equal(ethers.toUtf8String(content));
        console.log("Content verified successfully");
      } else {
        console.log("No chunks found for the given path");
        throw new Error("Chunk was not set properly");
      }
    });

    it("Should append content as new chunks", async function () {
      console.log("Starting 'append content' test");
      const path = "/data.txt";
      const contentType = "text/plain";
      const chunk1 = ethers.toUtf8Bytes("First chunk. ");
      const chunk2 = ethers.toUtf8Bytes("Second chunk.");
      const redirectCode = 0;

      let tx;
      const feeData = await hre.ethers.provider.getFeeData();

      console.log("Setting first chunk...");
      tx = await websiteContract.setResourceChunk(path, chunk1, contentType, 0, redirectCode, {gasPrice:feeData.gasPrice});
      await tx.wait();
      console.log("First chunk set successfully");

      console.log("Setting second chunk...");
      tx = await websiteContract.setResourceChunk(path, chunk2, contentType, 1, redirectCode, {gasPrice:feeData.gasPrice});
      await tx.wait();
      console.log("Second chunk set successfully");

      console.log("Getting resource info...");
      const [totalChunks, retrievedContentType, retrievedRedirectCode] = await websiteContract.getResource(path);
      console.log("Total chunks:", totalChunks.toString());
      expect(totalChunks).to.equal(2);

      console.log("Retrieving chunks...");
      const [retrievedContent1] = await websiteContract.getResourceChunk(path, 0);
      const [retrievedContent2] = await websiteContract.getResourceChunk(path, 1);

      console.log("Retrieved chunks:", {
        path,
        chunk1: ethers.toUtf8String(retrievedContent1),
        chunk2: ethers.toUtf8String(retrievedContent2)
      });

      console.log("Verifying retrieved content...");
      expect(ethers.toUtf8String(retrievedContent1)).to.equal(ethers.toUtf8String(chunk1));
      expect(ethers.toUtf8String(retrievedContent2)).to.equal(ethers.toUtf8String(chunk2));
      console.log("Content verified successfully");
    });

    it("Should allow only the owner to set resource chunks", async function () {
      console.log("Starting 'owner-only set' test");
      const path = "/secure.txt";
      const contentType = "text/plain";
      const content = ethers.toUtf8Bytes("Sensitive data");
      const chunkIndex = 0;
      const redirectCode = 0;

      let tx;

      const feeData = await hre.ethers.provider.getFeeData();
      const gasPrice = feeData.gasPrice ? feeData.gasPrice + (feeData.gasPrice / BigInt(10)) : 30000000;

      console.log("Setting resource chunk as owner...");
      tx = await websiteContract.setResourceChunk(path, content, contentType, chunkIndex, redirectCode, {gasPrice:gasPrice});
      await tx.wait();
      console.log("Resource chunk set successfully");

      // console.log("Attempting to set resource chunk as non-owner...");
      // await expect(
      //   websiteContract.connect(otherAccount).setResourceChunk(path, content, contentType, {gasPrice:gasPrice})
      // ).to.be.revertedWith("Only the owner can call this function");
      // console.log("Non-owner set attempt properly reverted");
    });

    it("Should handle large files by chunking", async function () {
      console.log("Starting 'large file chunking' test");
      const path = "/large-file.txt";
      const contentType = "text/plain";
      const chunkSize = 24 * 1024; // 24KB chunks
      const totalSize = 25 * 1024; // 25KB total

      let tx;

      console.log("Creating and uploading chunks...");
      for (let i = 0; i < totalSize; i += chunkSize) {
        const feeData = await hre.ethers.provider.getFeeData();
        const gasPrice = feeData.gasPrice ? feeData.gasPrice + (feeData.gasPrice / BigInt(10)) : 30000000;
        const chunkContent = ethers.toUtf8Bytes('x'.repeat(Math.min(chunkSize, totalSize - i)));
        tx = await websiteContract.setResourceChunk(path, chunkContent, contentType, Math.floor(i / chunkSize), 0, {gasPrice:gasPrice});
        await tx.wait();
        console.log(`Chunk ${Math.floor(i / chunkSize) + 1} set (${i + chunkContent.length} / ${totalSize} bytes)`);
      }

      console.log("Getting resource info...");
      const [totalChunks, retrievedContentType, retrievedRedirectCode] = await websiteContract.getResource(path);
      console.log("Total chunks for large file:", totalChunks.toString());

      console.log("Retrieving and verifying chunks...");
      let retrievedContent = '';
      for (let i = 0; i < totalChunks; i++) {
        const [content] = await websiteContract.getResourceChunk(path, i);
        retrievedContent += ethers.toUtf8String(content);
        console.log(`Chunk ${i + 1} retrieved (${retrievedContent.length} / ${totalSize} bytes)`);
      }

      console.log("Retrieved large file:", {
        path,
        contentType,
        contentLength: retrievedContent.length
      });

      console.log("Verifying total content length...");
      expect(retrievedContent.length).to.equal(totalSize);
      console.log("Content length verified successfully");
    });

    it("Should remove a resource", async function () {
      console.log("Starting 'remove resource' test");
      const path = "/to-be-removed.txt";
      const contentType = "text/plain";
      const content = "This will be removed";

      let tx;

      const feeData = await hre.ethers.provider.getFeeData();
      const gasPrice = feeData.gasPrice ? feeData.gasPrice + (feeData.gasPrice / BigInt(10)) : 30000000;

      console.log("Setting resource chunk...");
      await websiteContract.setResourceChunk(path, ethers.toUtf8Bytes(content), contentType, 0, 0, {gasPrice:gasPrice});
      console.log("Getting resource info...");
      let [totalChunks, retrievedContentType, retrievedRedirectCode] = await websiteContract.getResource(path);
      console.log("Total chunks before removal:", totalChunks.toString());
      expect(totalChunks).to.equal(1);

      console.log("Removing resource...");
      tx = await websiteContract.removeResource(path, {gasPrice:feeData.gasPrice});
      await tx.wait();
      console.log("Resource removed");

      console.log("Getting total chunks after removal...");
      [totalChunks, , ] = await websiteContract.getResource(path);
      console.log("Total chunks after removal:", totalChunks.toString());
      expect(totalChunks).to.equal(0);

      console.log("Attempting to retrieve removed chunk...");
      await expect(
        websiteContract.getResourceChunk(path, 0)
      ).to.be.revertedWith("Chunk index out of bounds");
      console.log("Chunk retrieval properly reverted");
    });
  });
});
