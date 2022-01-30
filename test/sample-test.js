const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Greeter", function () {
  it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("LikhaNFTMarketplace");
    const greeter = await Greeter.deploy();
    await greeter.deployed();
    console.log(await greeter.fetchInterfaceID());
    expect(await greeter.fetchInterfaceID()).to.equal("0x2a55205a");
  });
});
