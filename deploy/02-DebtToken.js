const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { devChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

const TOKEN_NAMES = ["Pledge JP Token", "Pledge SP Token", "PLGR Token"];
const TOKEN_SYMBOLS = ["PJPT", "PSPT", "PLGR"];
module.exports = async () => {
    const { log } = deployments;
    const CONTRACT_NAME = "DebtToken";
    const multiSignatureAddress = (await deployments.get("MultiSignature"))
        .address;
    const contractFactory = await ethers.getContractFactory(CONTRACT_NAME);
    const args0 = [TOKEN_NAMES[0], TOKEN_SYMBOLS[0], multiSignatureAddress];
    const args1 = [TOKEN_NAMES[1], TOKEN_SYMBOLS[1], multiSignatureAddress];
    const args2 = [TOKEN_NAMES[2], TOKEN_SYMBOLS[2], multiSignatureAddress];
    const contractPJPT = await upgrades.deployProxy(contractFactory, args0, {
        initializer: "initialize",
    });
    const contractPSPT = await upgrades.deployProxy(contractFactory, args1, {
        initializer: "initialize",
    });
    const contractPLGR = await upgrades.deployProxy(contractFactory, args2, {
        initializer: "initialize",
    });
    await contractPJPT.waitForDeployment();
    await contractPSPT.waitForDeployment();
    await contractPLGR.waitForDeployment();
    await deployments.save("PJPT", {
        address: contractPJPT.target,
        abi: contractPJPT.interface,
    });
    await deployments.save("PSPT", {
        address: contractPSPT.target,
        abi: contractPSPT.interface,
    });
    await deployments.save("PLGR", {
        address: contractPLGR.target,
        abi: contractPLGR.interface,
    });
    log("PJPT部署地址：", contractPJPT.target);
    log("PSPT部署地址：", contractPSPT.target);
    log("PLGR部署地址：", contractPLGR.target);

    if (devChains.includes(network.name)) {
    } else {
        await verify(contractPJPT.address, args0);
        await verify(contractPSPT.address, args1);
        await verify(contractPLGR.address, args2);
    }
};

module.exports.tags = ["all", "debttoken"];
