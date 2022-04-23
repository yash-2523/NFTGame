const { expect } = require("chai");
const { ethers } = require("hardhat");

// describe("Greeter", function () {
//   it("Should return the new greeting once it's changed", async function () {
//     const Greeter = await ethers.getContractFactory("Greeter");
//     const greeter = await Greeter.deploy("Hello, world!");
//     await greeter.deployed();

//     expect(await greeter.greet()).to.equal("Hello, world!");

//     const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

//     // wait until the transaction is mined
//     await setGreetingTx.wait();

//     expect(await greeter.greet()).to.equal("Hola, mundo!");
//   });
// });

describe("Check the hashes", () => {
  it("should return hashes", async () => {
    const NFTGAME = await ethers.getContractFactory("NFTGame");
    const nftgame = await NFTGAME.deploy();
    await nftgame.deployed();
    let tx = await nftgame.getHashes();
    console.log(tx);
  })
})
