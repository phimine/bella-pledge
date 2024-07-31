// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title 多签验证
 * @author Carl Fu
 * @notice
 */
interface IMultiSignature {
    /**
     * 验证msg.sender对当前合约账户的交易是否有足够数量的签名
     * @param msgHash 哈希消息
     */
    function hasValidSignature(bytes32 msgHash) external view returns (bool);
}
