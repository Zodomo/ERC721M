// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "../src/AlignmentVault.sol";

contract TestingAlignmentVault is AlignmentVault {
    constructor() {}

    function call_estimateFloor() public view returns (uint256) {
        return _estimateFloor();
    }

    function view_liqHelper() public view returns (address) {
        return (address(_liqHelper));
    }
}
