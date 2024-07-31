const {
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
} = require("hardhat");
const { assert, expect } = require("chai");

const CONTRACT_NAME = "MultiSignature";
const THRESHOLD = 1;
describe("MultiSignature", async () => {
    let contract, address;
    let deployer, userA, userB, userC;
    beforeEach(async () => {
        [deployer, userA, userB, userC] = await ethers.getSigners();
        const contractFactory = await ethers.getContractFactory(CONTRACT_NAME);
        const args = [
            [deployer.address, userA.address, userB.address, userC.address],
            THRESHOLD,
        ];
        contract = await upgrades.deployProxy(contractFactory, args, {
            initializer: "initialize",
        });
        await contract.waitForDeployment();
        address = contract.target;
    });

    describe("initialize", async () => {
        it("should set owners correctly", async () => {
            assert.equal(await contract.getOwnerCount(), 4);
            assert.equal(await contract.ifOwner(deployer), true);
            assert.equal(await contract.ifOwner(userA), true);
            assert.equal(await contract.ifOwner(userB), true);
            assert.equal(await contract.ifOwner(userC), true);
        });
        it("should set threshold correctly", async () => {
            assert.equal(await contract.getThreshold(), THRESHOLD);
        });
        it("should set distinct owner if has duplicated owners", async () => {
            const contractFactory =
                await ethers.getContractFactory(CONTRACT_NAME);
            const args = [
                [
                    deployer.address,
                    deployer.address,
                    deployer.address,
                    deployer.address,
                ],
                THRESHOLD,
            ];
            const duplicatedContract = await upgrades.deployProxy(
                contractFactory,
                args,
                {
                    initializer: "initialize",
                },
            );
            await duplicatedContract.waitForDeployment();
            assert.equal(await duplicatedContract.getOwnerCount(), 1);
        });
        it("revert with error message if threshold is greater than owner length", async () => {
            const INVALID_THRESHOLD = 10;
            const contractFactory =
                await ethers.getContractFactory(CONTRACT_NAME);
            const args = [[deployer.address], INVALID_THRESHOLD];
            await expect(
                upgrades.deployProxy(contractFactory, args, {
                    initializer: "initialize",
                }),
            ).to.revertedWith(
                "MultiSignature: threshold is greater than owners length",
            );
        });
        it("revert with error message if owner address is zero", async () => {
            const contractFactory =
                await ethers.getContractFactory(CONTRACT_NAME);
            const args = [[ethers.ZeroAddress], THRESHOLD];
            await expect(
                upgrades.deployProxy(contractFactory, args, {
                    initializer: "initialize",
                }),
            ).to.revertedWith("MultiSignature: Zero address");
        });
    });

    describe("transferOwner", async () => {
        it("should revert with error MultiSignature: Not owner if it's non-owner", async () => {});
        it("should revert with error MultiSignature.transferOwner: Not owner if old account is not owner", async () => {});
        it("should revert with error MultiSignature.transferOwner: Already owner if new account is already owner", async () => {});
        it("should revert with error MultiSignature.transferOwner: Zero address if new address is zero", async () => {});
        it("should emit TransferOwner event correctly", async () => {});
        it("should cancel old owner and grant new owner correctly", async () => {});
    });

    describe("createTransaction", async () => {
        it("should revert with error MultiSignature.createTransaction: tx exists if transaction already created", async () => {});
        it("should emit CreateTransaction event correctly", async () => {});
        it("should create transaction correctly", async () => {});
    });

    describe("signTransaction", async () => {
        it("should revert with error MultiSignature: Not owner if it's non-owner", async () => {});
        it("should revert with error MultiSignature: tx not exists if transaction not exists", async () => {});
        it("should emit SignTransaction event correctly", async () => {});
        it("should sign transaction correctly", async () => {});
    });

    describe("revokeSignature", async () => {
        it("should revert with error MultiSignature: Not owner if it's non-owner", async () => {});
        it("should revert with error MultiSignature: tx not exists if transaction not exists", async () => {});
        it("should revert with error MultiSignature.revokeSignature: not signed tx if msg.sender didn't signed tx", async () => {});
        it("should emit RevokeSignature event correctly", async () => {});
        it("should revoke signature correctly", async () => {});
    });

    describe("getTransactionHash", async () => {
        it("should get transaction hash correctly", async () => {});
    });
});
