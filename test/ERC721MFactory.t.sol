// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "solady/utils/SSTORE2.sol";
import "../src/ERC721M.sol";
import "../src/ERC721MFactory.sol";

contract FactoryTest is DSTestPlus {

    ERC721MFactory public factory;

    function setUp() public {
        factory = new ERC721MFactory(address(this));
    }

    function _concatenate(bytes memory _a, bytes memory _b) internal pure returns (bytes memory result) {
        result = new bytes(_a.length + _b.length);
        for (uint256 i; i < _a.length;) {
            result[i] = _a[i];
            unchecked { ++i; }
        }
        for (uint256 i; i < _b.length;) {
            result[_a.length + i] = _b[i];
            unchecked { ++i; }
        }
    }

    function getCreationCode() public returns (bytes memory) {
        return hevm.getCode("ERC721M.sol:ERC721M");
    }

    function testSaveCreationCode() public {
        factory.writeCreationCode(getCreationCode());
        require(keccak256(abi.encode(getCreationCode())) == 
            keccak256(abi.encode(factory.getCreationCode())), "creationCode mismatch");
    }
}