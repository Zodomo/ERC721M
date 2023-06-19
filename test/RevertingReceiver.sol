// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

contract RevertingReceiver {
    constructor() { }
    receive() external payable { revert(""); }
}