// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AddressList {
    function add(address[] storage addressList, address _address) internal {
        if (!contains(addressList, _address)) {
            addressList.push(_address);
        }
    }

    function remove(address[] storage addressList, address _address) internal {
        uint256 listSize = addressList.length;
        uint256 index = 0;
        bool exists = false;
        for (; index < listSize; index++) {
            if (!exists) {
                address one = addressList[index];
                if (one == _address) {
                    exists = true;
                }
            }
            if (exists && index < listSize - 1) {
                addressList[index] = addressList[index + 1];
            }
        }

        if (exists) {
            addressList.pop();
        }
    }

    function contains(
        address[] memory addressList,
        address _address
    ) internal pure returns (bool) {
        uint256 listSize = addressList.length;
        for (uint i = 0; i < listSize; i++) {
            address one = addressList[i];
            if (one == _address) {
                return true;
            }
        }
        return false;
    }
}
