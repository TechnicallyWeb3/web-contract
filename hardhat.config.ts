import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
import "./tasks/deployContract";
import "./tasks/uploadToIPFS";
import "./tasks/writeToContract";
import "./tasks/readFromContract";
import "./tasks/buildOrdinal";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    sepolia: {
      url: process.env.RPC_URL_11155111 || "",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    polygon: {
      url: process.env.RPC_URL_137 || "",
      accounts: [process.env.PRIVATE_KEY || ""],
      
    }
  }
};

export default config;
