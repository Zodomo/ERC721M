// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/../test/utils/mocks/MockERC20.sol";

contract FakeSendERC20 is MockERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) MockERC20(_name, _symbol, _decimals) {}

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) { return true; }
}