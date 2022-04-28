// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const NFTGAME = await hre.ethers.getContractFactory("NFTGame");
  const nftGame = await NFTGAME.deploy();
  // const NFTCONTRACT = await hre.ethers.getContractFactory("MyNFT");
  // const nft1 = await NFTCONTRACT.deploy();
  // const nft2 = await NFTCONTRACT.deploy();
  // const nft3 = await NFTCONTRACT.deploy();

  await nftGame.deployed();
  // await nft1.deployed();
  // await nft2.deployed();
  // await nft3.deployed();

  console.log("NFTGame deployed to:", nftGame.address);
  // console.log("NFT1 deployed to:", nft1.address);
  // console.log("NFT2 deployed to:", nft2.address);
  // console.log("NFT3 deployed to:", nft3.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
