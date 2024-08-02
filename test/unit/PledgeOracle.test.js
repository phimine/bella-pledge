const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { assert, expect } = require("chai");
const {
    LEND_TOKEN,
    AGGREGATOR_DECIMALS,
    AGGREGATOR_INITIAL_ANSWER_LEND,
} = require("../../helper-hardhat-config");

const CONTRACT_NAME = "PledgeOracle";
describe("PledgeOracle", async () => {
    let oracleContract, oracleAddress;
    let lendAggregator, lendAggregatorContract;
    let userA;

    beforeEach(async () => {
        [, userA] = await ethers.getSigners();
        await deployments.fixture([
            "mocks",
            "multisignature",
            "debttoken",
            "pledgeoracle",
        ]);
        oracleAddress = (await deployments.get(CONTRACT_NAME)).address;
        oracleContract = await ethers.getContractAt(
            CONTRACT_NAME,
            oracleAddress,
        );

        lendAggregator = (await deployments.get("MockLendAggregator")).address;
        lendAggregatorContract = await ethers.getContractAt(
            "MockLendAggregator",
            lendAggregator,
        );
    });

    it("should add token aggregator correctly", async () => {
        const [aggregator, decimals] =
            await oracleContract.getTokenAggregator(LEND_TOKEN);
        assert.equal(aggregator, lendAggregator);
        assert.equal(decimals, AGGREGATOR_DECIMALS);
    });
    it("should get price correctly if aggregator decimals is less than 18", async () => {
        const price = await oracleContract.getPrice(LEND_TOKEN);
        assert.equal(
            price,
            BigInt(AGGREGATOR_INITIAL_ANSWER_LEND) /
                ethers.parseUnits("1", AGGREGATOR_DECIMALS),
        );
    });
    it("should get price correctly if aggregator decimals is greater than 18", async () => {
        await lendAggregatorContract.setDecimals(20);
        await oracleContract
            .connect(userA)
            .addTokenAggregator(LEND_TOKEN, lendAggregator, 20);
        await lendAggregatorContract.updateAnswer(
            ethers.parseUnits("2000", 20),
        );
        const price = await oracleContract.getPrice(LEND_TOKEN);
        assert.equal(price, 2000);
    });
    it("should get price correctly if aggregator decimals is equals to 18", async () => {
        await lendAggregatorContract.setDecimals(18);
        await oracleContract
            .connect(userA)
            .addTokenAggregator(LEND_TOKEN, lendAggregator, 18);
        await lendAggregatorContract.updateAnswer(
            ethers.parseUnits("2000", 18),
        );
        const price = await oracleContract.getPrice(LEND_TOKEN);
        assert.equal(price, 2000);
    });
});
