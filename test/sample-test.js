const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
var Minter;
var minter;
var MarketPlace;
var marketplace;
describe("Minter", function () {
  before(async function(){
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should mint new NFT", async function () {
    const TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    const Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
        return array.event === "MintEvent";
    });
    expect(MintEvent[0].args[0].toString()).to.be.a('string');
  });
});
describe("Royalty", function () {
  before(async function(){
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should get 2% royalty value from 1 Matic", async function () {
    const TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    const Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
        return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];

    return_vals = await minter.royaltyInfo(tokenID, BigNumber.from("1000000000000000000")) 
    expect(return_vals.royaltyAmount.toString()).equals(((BigNumber.from("1000000000000000000") * BigNumber.from("200")) / BigNumber.from(10000)).toString());
  });
});

describe("MarketPlace", function () {
  before(async function(){
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should post new item for sale", async function () {
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
        return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    TX = await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), BigNumber.from(1));
    Receipt = await TX.wait();
    const ItemPostEvent = Receipt.events.filter((array) => {
        return array.event === "ItemPostEvent";
    });
    expect(ItemPostEvent[0].args[3]).equals("An NFT was listed for Sale");
  });
  it("Should sold nft with 10% cut", async function () {
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
        return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), BigNumber.from(1));
    const [_, buyerAddress] = await ethers.getSigners()
    TX = await marketplace.connect(buyerAddress).buyNFT("dummyID", {'value' : BigNumber.from("1000000000000000000")});
    Receipt = await TX.wait();
    const NFTSaleEvent = Receipt.events.filter((array) => {
        return array.event === "NFTSaleEvent";
    });
    expect(NFTSaleEvent[0].args[5]).equals("An NFT from marketplace has been sold");
    expect(NFTSaleEvent[0].args[4].toString()).equals("900000000000000000");
  });
  it("Should sold nft with 5% cut (2.5% platform fee + 2.5% royalty)", async function () {
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154","0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 250);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
        return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), BigNumber.from(0));
    const [_, buyerAddress] = await ethers.getSigners()
    TX = await marketplace.connect(buyerAddress).buyNFT("dummyID", {'value' : BigNumber.from("1000000000000000000")});
    Receipt = await TX.wait();
    const NFTSaleEvent = Receipt.events.filter((array) => {
        return array.event === "NFTSaleEvent";
    });
    expect(NFTSaleEvent[0].args[5]).equals("An NFT from marketplace has been sold");
    expect(NFTSaleEvent[0].args[4].toString()).equals("950000000000000000");
  });
});
