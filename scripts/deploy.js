// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

const hre = require("hardhat");
const Path = require('path');
require('dotenv').config({path:Path.join(__dirname, '../.env')});

async function main() {
  const NFTMarket = await hre.ethers.getContractFactory("LikhaNFTMarketplace");
  const nftMarket = await NFTMarket.deploy();
  await nftMarket.deployed();
  console.log("nftMarket deployed to:", nftMarket.address);
  console.log('nftMarket', nftMarket);

  // const NFT = await hre.ethers.getContractFactory("LikhaNFT");
  // const nft = await NFT.deploy();
  // await nft.deployed();
  // console.log("nft deployed to:", nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
