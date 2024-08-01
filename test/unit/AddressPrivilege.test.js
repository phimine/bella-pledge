const {
    getNamedAccounts,
    deployments,
    ethers,
    network,
    upgrades,
} = require("hardhat");
const { assert, expect } = require("chai");

const DEBT_TOKEN = "DebtToken";
const MULTI_SIGNATURE = "MultiSignature";
describe("AddressPriviledge", async () => {
    let contract, address;
    let deployer, userA, userB, userC;
    beforeEach(async () => {
        [deployer, userA, userB, userC] = await ethers.getSigners();
        const multiSignatureFactory =
            await ethers.getContractFactory(MULTI_SIGNATURE);
        const multiSignatureArgs = [[deployer.address, userA.address], "1"];
        const multiSignatureContract = await upgrades.deployProxy(
            multiSignatureFactory,
            multiSignatureArgs,
            { initializer: "initialize" },
        );
        await multiSignatureContract.waitForDeployment();
        const multiSignatureAddress = multiSignatureContract.target;

        const debtTokenFactory = await ethers.getContractFactory(DEBT_TOKEN);
        const args = ["Test Token", "TETK", multiSignatureAddress];
        contract = await upgrades.deployProxy(debtTokenFactory, args, {
            initializer: "initialize",
        });
        await contract.waitForDeployment();
        address = contract.target;

        // userB申请call权限
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

        const packed = ethers.concat([
            ethers.getAddress(userB.address),
            ethers.getAddress(address),
        ]);
        const expectedHash = ethers.keccak256(packed);

        assert.equal(msgHash, expectedHash);
        await multiSignatureContract.signTransaction(msgHash);

        assert.equal(
            await multiSignatureContract.hasValidSignature(msgHash),
            true,
        );
    });

    describe("initialize", async () => {
        it("should has no minter", async () => {
            assert.equal(await contract.getMinterLength(), 0);
        });
    });

    describe("addMinter", async () => {
        it("should revert with error AddressPrivilege: zero address if minter address is 0x", async () => {
            await expect(
                contract.connect(userB).addMinter(ethers.ZeroAddress),
            ).to.revertedWith("AddressPrivilege: zero address");
        });
        it("should revert with error MultiSignatureClient: the tx is not approved if caller has no permission", async () => {
            await expect(contract.connect(userC).addMinter(userA));
        });
        it("should add minter correctly", async () => {
            const minterLength = await contract.getMinterLength();
            await contract.connect(userB).addMinter(userA);
            const minterLengthAfter = await contract.getMinterLength();
            assert.equal(minterLengthAfter, minterLength + 1n);
            const minter = await contract.getMinter(minterLengthAfter - 1n);
            assert.equal(minter, userA.address);
        });
    });

    describe("delMinter", async () => {
        let minterLength, index;
        beforeEach(async () => {
            await contract.connect(userB).addMinter(userA);
            minterLength = await contract.getMinterLength();
            assert.equal(minterLength, 1);
            index = minterLength - 1n;
        });

        it("should revert with error AddressPrivilege: zero address if minter address is 0x", async () => {
            await expect(
                contract.connect(userB).delMinter(ethers.ZeroAddress),
            ).to.revertedWith("AddressPrivilege: zero address");
        });
        it("should revert with error MultiSignatureClient: the tx is not approved if caller has no permission", async () => {
            await expect(contract.connect(userC).delMinter(userA));
        });
        it("should delete minter correctly", async () => {
            await contract.connect(userB).delMinter(userA);
            const minterLengthAfter = await contract.getMinterLength();
            assert.equal(minterLengthAfter, minterLength - 1n);
            assert.equal(await contract.isMinter(userA), false);
        });
    });

    describe("getMinter", async () => {
        let minterLength, index;
        beforeEach(async () => {
            await contract.connect(userB).addMinter(userA);
            minterLength = await contract.getMinterLength();
            assert.equal(minterLength, 1);
            index = minterLength - 1n;
        });
        it("should revert with error AddressPrivilege: index out of bounds if index is too large", async () => {
            await expect(contract.getMinter(minterLength)).to.revertedWith(
                "AddressPrivilege: index out of bounds",
            );
        });
    });
});
