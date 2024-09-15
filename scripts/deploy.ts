import { ethers } from "hardhat";

async function main() {
  console.log("Deploying WebContract...");

  // Deploy the contract
  const WebContract = await ethers.getContractFactory("WebContract");
  const webContract = await WebContract.deploy();

  // Wait for the contract to be deployed
  await webContract.deployed();

  console.log("WebContract deployed to:", webContract.address);
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
