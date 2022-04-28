const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Deploy the NFTGame", async () => {
  let nftGame;
  let [owner, alice, bob] = await ethers.getSigners();
  it("deploy the contract", () => {
    const NFTGAME = await ethers.getContractFactory("NFTGame");
    nftGame = await NFTGAME.deploy();
    console.log("NFTGame deployed to:", nftGame.address);
  })

  it("Create a lobby", () => {
    let tx = await nftGame.createLobby(ethers.constants.AddressZero, 0, ethers.utils.parse);
  })

})

describe("Check the hashes", () => {
  it("should return hashes", async () => {
    const NFTGAME = await ethers.getContractFactory("NFTGame");
    const nftgame = await NFTGAME.deploy();
    await nftgame.deployed();
    let tx = await nftgame.getHashes();
    console.log(tx);
  })
})
