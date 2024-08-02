const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const {
    devChains,
    LEND_TOKEN,
    BORROW_TOKEN,
    AGGREGATOR_DECIMALS,
} = require("../helper-hardhat-config");
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
        const [deployer, userA] = await ethers.getSigners();
        // userA 申请oracle权限
        let multiSignatureContract = await ethers.getContractAt(
            "MultiSignature",
            multiSignatureAddress,
        );
        // const multiSignatureFactory =
        //     await ethers.getContractFactory("MultiSignature");
        // multiSignatureContract = await multiSignatureFactory.attach(
        //     multiSignatureAddress,
        // );

        const tx = await multiSignatureContract
            .connect(userA)
            .createTransaction(oracleAddress);
        const receipt = await tx.wait();
        let msgHash;
        for (const event of receipt.logs) {
            if (event.eventName === "CreateTransaction") {
                msgHash = event.args[2];
                break;
            }
        }
        await multiSignatureContract.connect(deployer).signTransaction(msgHash);

        // userA 设置预言机聚合
        const lendAggregator = (await deployments.get("MockLendAggregator"))
            .address;
        const borrowAggregator = (await deployments.get("MockBorrowAggregator"))
            .address;
        await oracleContract
            .connect(userA)
            .addTokenAggregator(
                LEND_TOKEN,
                lendAggregator,
                AGGREGATOR_DECIMALS,
            );
        await oracleContract
            .connect(userA)
            .addTokenAggregator(
                BORROW_TOKEN,
                borrowAggregator,
                AGGREGATOR_DECIMALS,
            );
    } else {
        await verify(oracleAddress, args);
    }
};

module.exports.tags = ["all", "pledgeoracle"];
