const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { verify } = require("../utils/verify");
const {
    devChains,
    SIGNATURE_THRESHOLD_DEV,
    networkConfig,
} = require("../helper-hardhat-config");

const CONTRACT_NAME = "MultiSignature";

module.exports = async () => {
    const { log } = deployments;

    const multiSignatureFactory =
        await ethers.getContractFactory(CONTRACT_NAME);
    const args = [
        networkConfig[network.config.chainId].multi_signers,
        networkConfig[network.config.chainId].signature_threshold,
    ];

    const multisignatureContract = await upgrades.deployProxy(
        multiSignatureFactory,
        args,
        {
            initializer: "initialize",
        },
    );
    await multisignatureContract.waitForDeployment();
    const multisignatureAddress = multisignatureContract.target;
    log("多签合约部署在地址：", multisignatureAddress);
    log("owner一共有: ", await multisignatureContract.getOwnerCount());
    log("签名不少于", await multisignatureContract.getThreshold());

    await deployments.save(CONTRACT_NAME, {
        address: multisignatureAddress,
        abi: JSON.stringify(multisignatureContract.interface),
    });

    if (devChains.includes(network.name)) {
        // 本地部署-单元测试
    } else {
        // 测试网/主网-验证合约
        await verify(multisignatureAddress, args);
    }
};

module.exports.tags = ["all", "multisignature"];
