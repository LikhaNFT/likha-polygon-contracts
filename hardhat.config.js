require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config({path:__dirname + '/.env'});

const privateKey = process.env.SECRET || "01234567890123456789" 
const etherscanKey = process.env.API_KEY
module.exports = {
  defaultNetwork: "mumbai",
  networks: {
    hardhat: {
      chainId: 80001
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com/",
      chainId : 80001,
      accounts: [privateKey]
    },
    polygon_main : {
      url : "https://polygon-rpc.com/",
      chainId : 137,
      accounts: [privateKey]
    }

  },
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  etherscan : { apiKey  : etherscanKey }
}