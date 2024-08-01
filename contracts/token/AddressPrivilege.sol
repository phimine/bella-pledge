// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../multisignature/MultiSignatureClient.sol";

contract AddressPrivilege is MultiSignatureClient {
    // Type Declarations
    using EnumerableSet for EnumerableSet.AddressSet;
    // State Variables
    EnumerableSet.AddressSet private _minters;

    // Events
    // Modifiers
    modifier onlyMinter() {
        require(isMinter(msg.sender), "AddressPrivilege: caller is not minter");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "AddressPrivilege: zero address");
        _;
    }

    // Functions
    //// constructor
    function __AddressPrivilege_init(
        address multiSignature
    ) internal onlyInitializing {
        __MultiSignatureClient_init(multiSignature);
    }

    //// externals
    function addMinter(
        address _minter
    ) public validCall validAddress(_minter) returns (bool) {
        return _minters.add(_minter);
    }

    function delMinter(
        address _minter
    ) public validCall validAddress(_minter) returns (bool) {
        return _minters.remove(_minter);
    }

    function getMinterLength() public view returns (uint256) {
        return _minters.length();
    }

    function getMinter(uint256 index) public view returns (address) {
        require(
            index < getMinterLength(),
            "AddressPrivilege: index out of bounds"
        );
        return _minters.at(index);
    }

    function isMinter(address _minter) public view returns (bool) {
        return _minters.contains(_minter);
    }
}
