// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./IMultiSignature.sol";

/**
 * @title 多签客户端，提供validCall修饰符
 * @author Carl Fu
 * @notice
 */
contract MultiSignatureClient is Initializable, UUPSUpgradeable {
    uint256 private constant multiSignaturePosition =
        uint256(keccak256("org.multiSignature.store"));
    uint256 private constant DEFAULT_INDEX = 0;

    function __MultiSignatureClient_init(
        address multiSignature
    ) internal onlyInitializing {
        require(
            multiSignature != address(0),
            "MultiSignatureClient: Zero address!"
        );
        saveAddress(multiSignaturePosition, uint256(uint160(multiSignature)));
    }

    modifier validCall() {
        checkMultiSignature();
        _;
    }

    /**
     * 验证msg.sender对当前合约账号的交易是否有效
     */
    function checkMultiSignature() internal view {
        // 计算msg.sender对当前合约账号的交易哈希
        bytes32 msgHash = keccak256(
            abi.encodePacked(msg.sender, address(this))
        );
        // 获得多签合约地址
        address multiSignature = getAddress();

        bool approved = IMultiSignature(multiSignature).hasValidSignature(
            msgHash
        );
        require(approved, "MultiSignatureClient: the tx is not approved");
    }

    function getAddress() internal view returns (address) {
        return address(uint160(getAddress(multiSignaturePosition)));
    }

    function getAddress(
        uint256 position
    ) internal view returns (uint256 value) {
        assembly {
            value := sload(position)
        }
    }

    function saveAddress(uint256 position, uint256 value) internal {
        assembly {
            sstore(position, value)
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override validCall {}
}
