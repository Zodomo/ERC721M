// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/../test/utils/mocks/MockERC20.sol";

contract UnburnableERC20 is MockERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) MockERC20(_name, _symbol, _decimals) {}

    function burn(address _from, uint256 _value) public override { }
}