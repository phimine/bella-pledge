const {
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
} = require("hardhat");
const { assert, expect } = require("chai");

const DEBT_TOKEN = "DebtToken";
const MULTI_SIGNATURE = "MultiSignature";
describe("DebtToken", async () => {
    let contract, address;
    let deployer, userA, userB, userC;
    beforeEach(async () => {
        [deployer, userA, userB, userC] = await ethers.getSigners();
        const multiSignatureFactory =
            await ethers.getContractFactory(MULTI_SIGNATURE);
        const multiSignatureArgs = [[deployer.address, userA.address], 1];
        const multiSignatureContract = await upgrades.deployProxy(
            multiSignatureFactory,
            multiSignatureArgs,
            { initializer: "initialize" },
        );
        await multiSignatureContract.waitForDeployment();
        const multiSignatureAddress = multiSignatureContract.target;

        const debtTokenFactory = await ethers.getContractFactory(DEBT_TOKEN);
        const args = ["PLGR Debt Token", "PLGR", multiSignatureAddress];
        contract = await upgrades.deployProxy(debtTokenFactory, args, {
            initializer: "initialize",
        });
        await contract.waitForDeployment();
        address = contract.target;

        // userB申请call授权
        const tx = await multiSignatureContract
            .connect(userB)
            .createTransaction(address);
        const receipt = await tx.wait(1);
        let msgHash;
        for (const event of receipt.logs) {
            if (event.eventName === "CreateTransaction") {
                msgHash = event.args[2];
                break;
            }
        }
        await multiSignatureContract.signTransaction(msgHash);
        assert.equal(
            await multiSignatureContract.hasValidSignature(msgHash),
            true,
        );

        // 给userC授权minter
        await contract.connect(userB).addMinter(userC);
        assert.equal(await contract.isMinter(userC), true);
        assert.equal(await contract.isMinter(userA), false);
    });

    describe("mint", async () => {
        const MINT_AMOUNT = 1000n;
        it("should revert with error AddressPrivilege: caller is not minter if caller is not minter", async () => {
            await expect(
                contract.connect(userA).mint(userB, MINT_AMOUNT),
            ).to.revertedWith("AddressPrivilege: caller is not minter");
        });
        it("should mint correctly", async () => {
            const balanceBefore = await contract.balanceOf(userB);
            await contract.connect(userC).mint(userB, MINT_AMOUNT);
            const balanceAfter = await contract.balanceOf(userB);
            assert.equal(balanceAfter, balanceBefore + MINT_AMOUNT);
        });
    });

    describe("burn", async () => {
        const MINT_AMOUNT = 1000n;
        const BURN_AMOUNT = 100n;
        beforeEach(async () => {
            await contract.connect(userC).mint(userB, MINT_AMOUNT);
        });
        it("should revert with error AddressPrivilege: caller is not minter if caller is not minter", async () => {
            await expect(
                contract.connect(userA).burn(userB, BURN_AMOUNT),
            ).to.revertedWith("AddressPrivilege: caller is not minter");
        });
        it("should mint correctly", async () => {
            const balanceBefore = await contract.balanceOf(userB);
            await contract.connect(userC).burn(userB, BURN_AMOUNT);
            const balanceAfter = await contract.balanceOf(userB);
            assert.equal(balanceAfter, balanceBefore - BURN_AMOUNT);
        });
    });
});
