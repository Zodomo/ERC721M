// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

contract RevertingReceiver {
    constructor() {}

    receive() external payable {
        revert("");
    }
}
