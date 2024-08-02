const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { devChains, networkConfig } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async () => {
    const { log } = deployments;
    const CONTRACT_NAME = "DebtToken";
    const multiSignatureAddress = (await deployments.get("MultiSignature"))
        .address;
    const contractFactory = await ethers.getContractFactory(CONTRACT_NAME);
    const configs = networkConfig[network.config.chainId];
    const argsSP = [
        configs.sp_token_name,
        configs.sp_token_symbol,
        multiSignatureAddress,
    ];
    const argsJP = [
        configs.jp_token_name,
        configs.jp_token_symbol,
        multiSignatureAddress,
    ];
    const contractPJPT = await upgrades.deployProxy(contractFactory, argsJP, {
        initializer: "initialize",
    });
    const contractPSPT = await upgrades.deployProxy(contractFactory, argsSP, {
        initializer: "initialize",
    });
    await contractPJPT.waitForDeployment();
    await contractPSPT.waitForDeployment();
    await deployments.save("PJPT", {
        address: contractPJPT.target,
        abi: contractPJPT.interface,
    });
    await deployments.save("PSPT", {
        address: contractPSPT.target,
        abi: contractPSPT.interface,
    });
    log("PJPT部署地址：", contractPJPT.target);
    log("PSPT部署地址：", contractPSPT.target);

    if (devChains.includes(network.name)) {
    } else {
        await verify(contractPJPT.address, argsJP);
        await verify(contractPSPT.address, argsSP);
    }
};

module.exports.tags = ["all", "debttoken"];
