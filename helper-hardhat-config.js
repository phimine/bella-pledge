const devChains = ["hardhat", "localhost"];

const networkConfig = {
    11155111: {
        signature_threshold: 2,
        multi_signers: ["0x2546BcD3c84621e976D8185a91A922aE77ECEc30"],
        sp_token_name: "",
        sp_token_symbol: "",
        jp_token_name: "",
        jp_token_symbol: "",
    },
    31337: {
        signature_threshold: 1,
        multi_signers: [
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
            "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
            "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
            "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
        ],
        sp_token_name: "Pledge SP Token",
        sp_token_symbol: "PSPT",
        jp_token_name: "Pledge JP Token",
        jp_token_symbol: "PJPT",
    },
};

const AGGREGATOR_DECIMALS = 8;
const AGGREGATOR_INITIAL_ANSWER_LEND = 200000000000;
const AGGREGATOR_INITIAL_ANSWER_BORROW = 100000000000;
const LEND_TOKEN = "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707";
const BORROW_TOKEN = "0x0165878A594ca255338adfa4d48449f69242Eb8F";

module.exports = {
    devChains,
    AGGREGATOR_DECIMALS,
    AGGREGATOR_INITIAL_ANSWER_LEND,
    AGGREGATOR_INITIAL_ANSWER_BORROW,
    LEND_TOKEN,
    BORROW_TOKEN,
    networkConfig,
};
