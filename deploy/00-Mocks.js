const { getNamedAccounts, deployments, ethers, network } = require("hardhat");
const {
    devChains,
    AGGREGATOR_DECIMALS,
    AGGREGATOR_INITIAL_ANSWER_LEND,
    AGGREGATOR_INITIAL_ANSWER_BORROW,
} = require("../helper-hardhat-config");

module.exports = async () => {
    // 本地网络执行mocks
    if (devChains.includes(network.name)) {
        console.log("Deploying mocks...");

        const { deploy, log } = deployments;
        const { deployer } = await getNamedAccounts();

        const lendAggregator = await deploy("MockLendAggregator", {
            from: deployer,
            args: [AGGREGATOR_DECIMALS, AGGREGATOR_INITIAL_ANSWER_LEND],
            log: true,
        });
        const borrowAggregator = await deploy("MockBorrowAggregator", {
            from: deployer,
            args: [AGGREGATOR_DECIMALS + 1, AGGREGATOR_INITIAL_ANSWER_BORROW],
            log: true,
        });
        log("lendAggregator contract deployed at ", lendAggregator.address);
        log("borrowAggregator contract deployed at ", borrowAggregator.address);
    }
};

module.exports.tags = ["all", "mocks"];
