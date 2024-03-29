const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
var Minter;
var minter;
var MarketPlace;
var marketplace;
describe("Minter", function () {
  before(async function () {
    this.timeout(10000);
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should mint new NFT", async function () {
    this.timeout(10000);
    const TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    const Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    expect(MintEvent[0].args[0].toString()).to.be.a('string');
  });
});
describe("Royalty", function () {
  before(async function () {
    this.timeout(10000);
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should get 2% royalty value from 1 Matic", async function () {
    this.timeout(10000);
    const TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
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
  before(async function () {
    this.timeout(10000);
    Minter = await ethers.getContractFactory("LikhaNFT");
    minter = await Minter.deploy();
    MarketPlace = await ethers.getContractFactory("LikhaNFTMarketplace");
    marketplace = await MarketPlace.deploy();
    await minter.deployed();
  });
  it("Should post new item for sale and lock the item from reposting", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    TX = await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    Receipt = await TX.wait();
    const ItemPostEvent = Receipt.events.filter((array) => {
      return array.event === "ItemPostEvent";
    });
    expect(ItemPostEvent[0].args[3]).equals("An NFT was listed for Sale");
    const locked = await marketplace.isItemLocked(tokenID, minter.address);
    expect(locked.toString()).equals("1");
  });
  it("Should post new item for sale with 5 matic", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    TX = await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("5000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    Receipt = await TX.wait();
    const ItemPostEvent = Receipt.events.filter((array) => {
      return array.event === "ItemPostEvent";
    });
    expect(ItemPostEvent[0].args[3]).equals("An NFT was listed for Sale");
    const locked = await marketplace.isItemLocked(tokenID, minter.address);
    expect(locked.toString()).equals("1");
  });
  it("Should sold nft with 10% cut (First Purchase 10% platform fee) and unlock item for posting", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 200);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    const [_, buyerAddress] = await ethers.getSigners()
    TX = await marketplace.connect(buyerAddress).buyNFT("dummyID", { 'value': BigNumber.from("1000000000000000000") });
    Receipt = await TX.wait();
    const NFTSaleEvent = Receipt.events.filter((array) => {
      return array.event === "NFTSaleEvent";
    });
    const locked = await marketplace.isItemLocked(tokenID, minter.address);
    expect(NFTSaleEvent[0].args[7]).equals("An NFT from marketplace has been sold");
    expect(NFTSaleEvent[0].args[4].toString()).equals("900000000000000000");
    expect(locked.toString()).equals("0");
  });
  it("Should sold nft with 5% cut (2.5% platform fee + 2.5% royalty)", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 250);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    const [_, buyerAddress] = await ethers.getSigners()
    await marketplace.connect(buyerAddress).buyNFT("dummyID", { 'value': BigNumber.from("1000000000000000000") });
    await minter.connect(buyerAddress).setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, buyerAddress.address, tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    TX = await marketplace.buyNFT("dummyID", { 'value': BigNumber.from("1000000000000000000") });
    Receipt = await TX.wait();
    const NFTSaleEvent = Receipt.events.filter((array) => {
      return array.event === "NFTSaleEvent";
    });

    expect(NFTSaleEvent[0].args[7]).equals("An NFT from marketplace has been sold");
    expect(NFTSaleEvent[0].args[5].toString()).equals("25000000000000000");
    expect(NFTSaleEvent[0].args[4].toString()).equals("950000000000000000");
  });
  it("Should sold nft with 10% cut (2.5% platform fee + 7.5% royalty)", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 750);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    const [_, buyerAddress] = await ethers.getSigners()
    await marketplace.connect(buyerAddress).buyNFT("dummyID", { 'value': BigNumber.from("1000000000000000000") });
    await minter.connect(buyerAddress).setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, buyerAddress.address, tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    TX = await marketplace.buyNFT("dummyID", { 'value': BigNumber.from("1000000000000000000") });
    Receipt = await TX.wait();
    const NFTSaleEvent = Receipt.events.filter((array) => {
      return array.event === "NFTSaleEvent";
    });
    expect(NFTSaleEvent[0].args[7]).equals("An NFT from marketplace has been sold");
    expect(NFTSaleEvent[0].args[5].toString()).equals("75000000000000000");
    expect(NFTSaleEvent[0].args[4].toString()).equals("900000000000000000");
  });
  it("Should post item and cancel it", async function () {
    this.timeout(10000);
    let TX = await minter.mintToken("https://likhafuncapp.azurewebsites.net/api/ShowMetadata?GUID=5f960b0332274502892db481cc53d154", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", "dummyID", 750);
    let Receipt = await TX.wait();
    const MintEvent = Receipt.events.filter((array) => {
      return array.event === "MintEvent";
    });
    tokenID = MintEvent[0].args[0];
    await minter.setApprovalForAll(marketplace.address, true);
    await marketplace.nftSellPosting("dummyID", minter.address, "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", tokenID, BigNumber.from("1000000000000000000"), 0, "0x0000000000000000000000000000000000000000", 0);
    await marketplace.cancelPosting("dummyID");
    let postRes = await marketplace.fetchPostingStatus("dummyID");
    let locked =  await marketplace.isItemLocked(tokenID, minter.address);
    expect(postRes[10][1]).equals(BigNumber.from(3));
    expect(locked).equals(BigNumber.from(0));
  });

});
