const {
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
} = require("hardhat");
const { devChains } = require("../helper-hardhat-config");

const CONTRACT_NAME = "PledgePool";
module.exports = async () => {
    const pledgePoolFactory = await ethers.getContractFactory(CONTRACT_NAME);
    const [deployer, userA] = await ethers.getSigners();
    const oracleAddress = (await deployments.get("PledgeOracle")).address;
    const multiSignatureAddress = (await deployments.get("MultiSignature"))
        .address;
    // address _feeAddress, address _swapRouter, address _oracle, address multiSignature
    const args = [
        deployer.address,
        "0xbe9c40a0eab26a4223309ea650dea0dd4612767e",
        oracleAddress,
        multiSignatureAddress,
    ];
    const pledgePoolContract = await upgrades.deployProxy(
        pledgePoolFactory,
        args,
        { initializer: "initialize" },
    );
    await pledgePoolContract.waitForDeployment();

    await deployments.save(CONTRACT_NAME, {
        address: pledgePoolContract.target,
        abi: JSON.stringify(pledgePoolContract.interface),
    });

    const multiSignatureContract = await ethers.getContractAt(
        "MultiSignature",
        multiSignatureAddress,
    );

    if (devChains.includes(network.name)) {
        // dev链 - 给userA授权
        const tx = await multiSignatureContract
            .connect(userA)
            .createTransaction(pledgePoolContract.target);
        const receipt = await tx.wait();
        let msgHash;
        for (const event of receipt.logs) {
            if (event.eventName == "CreateTransaction") {
                msgHash = event.args[2];
                break;
            }
        }
        await multiSignatureContract.signTransaction(msgHash);
    }
};

module.exports.tags = ["all", "pledgepool"];
