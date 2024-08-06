const {
    getNamedAccounts,
    deployments,
    ethers,
    upgrades,
    network,
} = require("hardhat");
const { assert, expect } = require("chai");
const { devChains } = require("../../helper-hardhat-config");

const CONTRACT_NAME = "PledgePool";
describe("AdminControl", async () => {
    let poolContract, poolAddress;
    let userA, userB;
    beforeEach(async () => {
        await deployments.fixture([
            "mocks",
            "multisignature",
            "debttoken",
            "pledgeoracle",
            "pledgepool",
        ]);
        [, userA, userB] = await ethers.getSigners();
        poolAddress = (await deployments.get(CONTRACT_NAME)).address;
        poolContract = await ethers.getContractAt(CONTRACT_NAME, poolAddress);
    });

    describe("setMinDeposit", async () => {
        const MIN_DEPOSIT = 10n;
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract.connect(userB).setMinDeposit(MIN_DEPOSIT),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });
        it("should revert with error PledgePool: _minAmount is 0 if value is 0", async () => {
            await expect(
                poolContract.connect(userA).setMinDeposit(0),
            ).to.revertedWith("PledgePool: _minAmount is 0");
        });
        it("should emit SetMinDeposit event correctly", async () => {
            const oldMinDeposit = await poolContract.getMinDeposit();
            await expect(poolContract.connect(userA).setMinDeposit(MIN_DEPOSIT))
                .to.emit(poolContract, "SetMinDeposit")
                .withArgs(userA, oldMinDeposit, MIN_DEPOSIT);
        });
        it("should set min deposit correctly", async () => {
            await poolContract.connect(userA).setMinDeposit(MIN_DEPOSIT);
            const newMinDeposit = await poolContract.getMinDeposit();
            assert.equal(newMinDeposit, MIN_DEPOSIT);
        });
    });

    describe("setLendFee", async () => {
        const LEND_FEE = 3000000n;
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract.connect(userB).setLendFee(LEND_FEE),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });
        it("should revert with error PledgePool: _lendFee is 0 if value is 0", async () => {
            await expect(
                poolContract.connect(userA).setLendFee(0),
            ).to.revertedWith("PledgePool: _lendFee is 0");
        });
        it("should emit SetLendFee event correctly", async () => {
            const oldLendFee = await poolContract.getLendFee();
            await expect(poolContract.connect(userA).setLendFee(LEND_FEE))
                .to.emit(poolContract, "SetLendFee")
                .withArgs(userA, oldLendFee, LEND_FEE);
        });
        it("should set lend fee correctly", async () => {
            await poolContract.connect(userA).setLendFee(LEND_FEE);
            const newLendFee = await poolContract.getLendFee();
            assert.equal(newLendFee, LEND_FEE);
        });
    });

    describe("setBorrowFee", async () => {
        const BORROW_FEE = 3000000n;
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract.connect(userB).setBorrowFee(BORROW_FEE),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });
        it("should revert with error PledgePool: _borrowFee is 0 if value is 0", async () => {
            await expect(
                poolContract.connect(userA).setBorrowFee(0),
            ).to.revertedWith("PledgePool: _borrowFee is 0");
        });
        it("should emit SetBorrowFee event correctly", async () => {
            const oldBorrowFee = await poolContract.getBorrowFee();
            await expect(poolContract.connect(userA).setBorrowFee(BORROW_FEE))
                .to.emit(poolContract, "SetBorrowFee")
                .withArgs(userA, oldBorrowFee, BORROW_FEE);
        });
        it("should set borrow fee correctly", async () => {
            await poolContract.connect(userA).setBorrowFee(BORROW_FEE);
            const newBorrowFee = await poolContract.getBorrowFee();
            assert.equal(newBorrowFee, BORROW_FEE);
        });
    });

    describe("setSwapRouter", async () => {
        const SWAP_ROUNTER = "0x272aCa56637FDaBb2064f19d64BC3dE64A85A1b2";
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract.connect(userB).setSwapRouter(SWAP_ROUNTER),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });
        it("should revert with error PledgePool: _swapRouter is 0x if value is 0", async () => {
            await expect(
                poolContract.connect(userA).setSwapRouter(ethers.ZeroAddress),
            ).to.revertedWith("PledgePool: _swapRouter is 0x");
        });
        it("should emit SetSwapRouter event correctly", async () => {
            const oldSwapRouter = await poolContract.getSwapRouter();
            await expect(
                poolContract.connect(userA).setSwapRouter(SWAP_ROUNTER),
            )
                .to.emit(poolContract, "SetSwapRouter")
                .withArgs(userA, oldSwapRouter, SWAP_ROUNTER);
        });
        it("should set swap router correctly", async () => {
            await poolContract.connect(userA).setSwapRouter(SWAP_ROUNTER);
            const newSwapRouter = await poolContract.getSwapRouter();
            assert.equal(newSwapRouter, SWAP_ROUNTER);
        });
    });

    describe("setFeeAddress", async () => {
        const FEE_ADDRESS = "0x272aCa56637FDaBb2064f19d64BC3dE64A85A1b2";
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract.connect(userB).setFeeAddress(FEE_ADDRESS),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });
        it("should revert with error PledgePool: _feeAddress is 0x if value is 0", async () => {
            await expect(
                poolContract.connect(userA).setFeeAddress(ethers.ZeroAddress),
            ).to.revertedWith("PledgePool: _feeAddress is 0x");
        });
        it("should emit SetFeeAddress event correctly", async () => {
            const oldFeeAddress = await poolContract.getFeeAddress();
            await expect(poolContract.connect(userA).setFeeAddress(FEE_ADDRESS))
                .to.emit(poolContract, "SetFeeAddress")
                .withArgs(userA, oldFeeAddress, FEE_ADDRESS);
        });
        it("should set fee address correctly", async () => {
            await poolContract.connect(userA).setFeeAddress(FEE_ADDRESS);
            const newFeeAddress = await poolContract.getFeeAddress();
            assert.equal(newFeeAddress, FEE_ADDRESS);
        });
    });

    describe("pause", async () => {
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(poolContract.connect(userB).pause()).to.revertedWith(
                "MultiSignatureClient: the tx is not approved",
            );
        });
        it("should emit Pause event correctly", async () => {
            await expect(poolContract.connect(userA).pause())
                .to.emit(poolContract, "Paused")
                .withArgs(userA);
        });
    });

    describe("unpause", async () => {
        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(poolContract.connect(userB).unpause()).to.revertedWith(
                "MultiSignatureClient: the tx is not approved",
            );
        });
        it("should emit Unpause event correctly", async () => {
            await poolContract.connect(userA).pause();
            await expect(poolContract.connect(userA).unpause())
                .to.emit(poolContract, "Unpaused")
                .withArgs(userA);
        });
    });

    describe("createPool", async () => {
        let _settleTime,
            _endTime,
            _maxSupply,
            _lendToken,
            _borrowToken,
            _mortgageRate,
            _interestRate,
            _spToken,
            _jpToken,
            _autoLiquidateThreshold;
        beforeEach(async () => {
            const now = (await ethers.provider.getBlock("latest")).timestamp;
            _settleTime = now + 100;
            _endTime = now + 1000 * 3600;
            _maxSupply = ethers.parseUnits("1000", 18);
            _mortgageRate = ethers.parseUnits("2", 8);
            _autoLiquidateThreshold = ethers.parseUnits("2", 7);
            _interestRate = ethers.parseUnits("1", 6);

            _jpToken = (await deployments.get("PJPT")).address;
            _spToken = (await deployments.get("PSPT")).address;

            _lendToken = _jpToken;
            _borrowToken = _spToken;
        });

        it("should revert with error MultiSignatureClient: the tx is not approved if caller is not approved", async () => {
            await expect(
                poolContract
                    .connect(userB)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("MultiSignatureClient: the tx is not approved");
        });

        it("should revert with error PledgePool.createPool: end time is less than settle time", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _settleTime - 1,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith(
                "PledgePool.createPool: end time is less than settle time",
            );
        });

        it("should revert with error PledgePool.createPool: max supply is less than 0", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        0,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith(
                "PledgePool.createPool: max supply is less than 0",
            );
        });

        it("should revert with error PledgePool.createPool: _lendToken is 0x", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        ethers.ZeroAddress,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _lendToken is 0x");
        });

        it("should revert with error PledgePool.createPool: _borrowToken is 0x", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        ethers.ZeroAddress,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _borrowToken is 0x");
        });

        it("should revert with error PledgePool.createPool: _spToken is 0x", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        ethers.ZeroAddress,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _spToken is 0x");
        });

        it("should revert with error PledgePool.createPool: _jpToken is 0x", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        ethers.ZeroAddress,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _jpToken is 0x");
        });

        it("should revert with error PledgePool.createPool: _mortgageRate is le 0", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        0,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _mortgageRate is le 0");
        });

        it("should revert with error PledgePool.createPool: _interestRate is le 0", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        0,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            ).to.revertedWith("PledgePool.createPool: _interestRate is le 0");
        });

        it("should revert with error PledgePool.createPool: _autoLiquidateThreshold is le 0", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        0,
                    ),
            ).to.revertedWith(
                "PledgePool.createPool: _autoLiquidateThreshold is le 0",
            );
        });

        it("should emit CreatePool event correctly", async () => {
            await expect(
                poolContract
                    .connect(userA)
                    .createPool(
                        _settleTime,
                        _endTime,
                        _maxSupply,
                        _lendToken,
                        _borrowToken,
                        _mortgageRate,
                        _interestRate,
                        _spToken,
                        _jpToken,
                        _autoLiquidateThreshold,
                    ),
            )
                .to.emit(poolContract, "CreatePool")
                .withArgs(
                    _settleTime,
                    _endTime,
                    _maxSupply,
                    _lendToken,
                    _borrowToken,
                    _mortgageRate,
                    _interestRate,
                    _spToken,
                    _jpToken,
                    _autoLiquidateThreshold,
                );
        });

        it("should create pool correctly", async () => {
            await poolContract
                .connect(userA)
                .createPool(
                    _settleTime,
                    _endTime,
                    _maxSupply,
                    _lendToken,
                    _borrowToken,
                    _mortgageRate,
                    _interestRate,
                    _spToken,
                    _jpToken,
                    _autoLiquidateThreshold,
                );
            const poolLength = await poolContract.getPoolLength();
            assert.equal(poolLength, 1);
        });
    });
});
