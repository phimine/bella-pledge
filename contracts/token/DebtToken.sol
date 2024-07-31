// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./AddressPrivilege.sol";

contract DebtToken is ERC20Upgradeable, AddressPrivilege {
    function initialize(
        string memory _name,
        string memory _symbol,
        address multiSignature
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __AddressPrivilege_init(multiSignature);
    }

    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyMinter {
        _burn(from, amount);
    }
}
