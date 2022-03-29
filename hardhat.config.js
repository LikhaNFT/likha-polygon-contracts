require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('dotenv').config({path:__dirname + '/.env'});
if(process.env.DEV === "0"){
  var privateKey = process.env.SECRET_PROD || "01234567890123456789" 
}
else{
  var privateKey = process.env.SECRET_DEV || "01234567890123456789" 
}

console.log(privateKey);

const etherscanKey = process.env.API_KEY
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1011
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