// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IMultiSignature.sol";
import "./MultiSignatureClient.sol";
import "../library/AddressList.sol";

/**
 * @title 多签合约，拥有多个owners和最少签名阈值，必须有足够的签名才是有效的交易
 * @author Carl Fu
 * @notice
 */
contract MultiSignature is IMultiSignature, MultiSignatureClient {
    // Type Declarations
    using AddressList for address[];
    struct SignatureInfo {
        address sender;
        address[] signatures;
    }
    // State Variables
    mapping(address => bool) internal isOwner;
    uint256 internal ownersCount;
    uint256 internal threshold;
    //// msgHash => signatures
    mapping(bytes32 => SignatureInfo) private txSignMaps;
    mapping(bytes32 => bool) private txSignExists;

    // Events: 转移owner、创建交易、签名交易、撤销签名
    event TransferOwner(
        address indexed sender,
        address indexed oldOwner,
        address indexed newOwner
    );
    event CreateTransaction(
        address indexed from,
        address indexed to,
        bytes32 indexed msgHash
    );
    event SignTransaction(address indexed signer, bytes32 indexed msgHash);
    event RevokeSignature(address indexed revoker, bytes32 indexed msgHash);

    // Modifiers
    modifier onlyOwner() {
        require(isOwner[msg.sender], "MultiSignature: Not owner");
        _;
    }

    modifier validHash(bytes32 msgHash) {
        require(txSignExists[msgHash], "MultiSignature: tx not exists");
        _;
    }

    // Functions
    //// constructor
    function initialize(
        address[] memory _owners,
        uint256 _threshold
    ) public initializer {
        __MultiSignatureClient_init(address(this));
        require(
            _owners.length >= _threshold,
            "MultiSignature: threshold is greater than owners length"
        );
        for (uint256 i = 0; i < _owners.length; i++) {
            address _owner = _owners[i];
            require(_owner != address(0), "MultiSignature: Zero address");
            if (!isOwner[_owner]) {
                isOwner[_owner] = true;
                ownersCount++;
            }
        }
        threshold = _threshold;
    }

    //// external
    function transferOwner(
        address oldOwner,
        address newOwner
    ) external onlyOwner {
        // Check: 必须是owner、oldOwner必须是owner、newOwner不是零地址
        require(isOwner[oldOwner], "MultiSignature.transferOwner: Not owner");
        require(
            newOwner != address(0),
            "MultiSignature.transferOwner: Zero address"
        );
        require(
            !isOwner[newOwner],
            "MultiSignature.transferOwner: Already owner"
        );

        // Effect：取消oldOwner，增加newOwner
        isOwner[oldOwner] = false;
        isOwner[newOwner] = true;

        // Interactions
        emit TransferOwner(msg.sender, oldOwner, newOwner);
    }

    function createTransaction(address to) external returns (bytes32) {
        // Check: msgHash是否已经存在
        bytes32 msgHash = getTransactionHash(msg.sender, to);
        require(
            !txSignExists[msgHash],
            "MultiSignature.createTransaction: tx exists"
        );

        // Effect: txSignMaps、txSignExists
        txSignMaps[msgHash] = SignatureInfo({
            sender: msg.sender,
            signatures: new address[](0)
        });
        txSignExists[msgHash] = true;

        // Interactions
        emit CreateTransaction(msg.sender, to, msgHash);
        return msgHash;
    }

    function signTransaction(
        bytes32 msgHash
    ) external onlyOwner validHash(msgHash) {
        // Check: 必须是owner、交易哈希必须存在
        // Effect：txSignMaps增加signature
        txSignMaps[msgHash].signatures.add(msg.sender);
        // Interactions
        emit SignTransaction(msg.sender, msgHash);
    }

    function revokeSignature(
        bytes32 msgHash
    ) external onlyOwner validHash(msgHash) {
        // Check: 必须是owner、交易哈希必须存在、msg.sender必须签过名
        require(
            txSignMaps[msgHash].signatures.contains(msg.sender),
            "MultiSignature.revokeSignature: not signed tx"
        );
        // Effect：txSignMaps删除signature
        txSignMaps[msgHash].signatures.remove(msg.sender);
        // Interactions
        emit RevokeSignature(msg.sender, msgHash);
    }

    function hasValidSignature(
        bytes32 msgHash
    ) external view override returns (bool) {
        return txSignMaps[msgHash].signatures.length >= threshold;
    }

    //// view/pure
    function getTransactionHash(
        address from,
        address to
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(from, to));
    }

    function getThreshold() public view returns (uint256) {
        return threshold;
    }

    function getOwnerCount() public view returns (uint256) {
        return ownersCount;
    }

    function ifOwner(address account) public view returns (bool) {
        return isOwner[account];
    }
}
