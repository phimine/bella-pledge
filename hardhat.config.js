require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-deploy");
require("hardhat-gas-reporter");
require("dotenv").config();

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.24",
    settings: {
        viaIR: true,
        optimizer: {
            enabled: true,
            runs: 100, // Reduce 'runs' to a lower value like 100 if code size is still an issue
        },
    },
    defaultNetwork: "hardhat",
    networks: {
        sepolia: {
            url: SEPOLIA_RPC_URL,
            chainId: 11155111,
            accounts: [PRIVATE_KEY],
        },
        localhost: {
            url: "http://127.0.0.1:8545/",
            chainId: 31337,
        },
    },
    namedAccounts: {
        deployer: {
            default: 0,
        },
        userA: {
            default: 1,
        },
        userB: {
            default: 2,
        },
        userC: {
            default: 3,
        },
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
};
