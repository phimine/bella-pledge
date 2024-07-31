const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { devChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

const CONTRACT_NAME = "PledgeOracle";
module.exports = async () => {
    const { log } = deployments;
    const contractFactory = await ethers.getContractFactory(CONTRACT_NAME);
    const multiSignatureAddress = (await deployments.get("MultiSignature"))
        .address;
    const args = [multiSignatureAddress];
    const oracleContract = await upgrades.deployProxy(contractFactory, args, {
        initializer: "initialize",
    });
    await oracleContract.waitForDeployment();
    const oracleAddress = oracleContract.target;
    log("PledgeOracle部署地址：", oracleAddress);

    await deployments.save(CONTRACT_NAME, {
        address: oracleAddress,
        abi: oracleContract.interface,
    });

    if (devChains.includes(network.name)) {
    } else {
        await verify(oracleAddress, args);
    }
};

module.exports.tags = ["all", "pledgeoracle"];
