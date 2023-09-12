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

    function getCreationCode() public returns (bytes[] memory) {
        bytes memory _creationCode = hevm.getCode("ERC721M.sol:ERC721M");
        uint256 length = (_creationCode.length + 24576 - 1) / 24576;
        bytes[] memory creationCode = new bytes[](length);
        for (uint256 i; i < length;) {
            uint256 start = i * 24576;
            uint256 end = (start + 24576 > _creationCode.length) ? _creationCode.length : start + 24576;
            bytes memory segment = new bytes(end - start);
            for (uint256 j; j < end - start;) {
                segment[j] = _creationCode[start + j];
                unchecked { ++j; }
            }
            creationCode[i] = segment;
            unchecked { ++i; }
        }
        return creationCode;
    }

    function testSaveCreationCode() public {
        factory.writeCreationCode(getCreationCode());
        bytes[] memory array = getCreationCode();
        bytes memory creationCode;
        for (uint256 i; i < array.length;) {
            creationCode = abi.encodePacked(creationCode, array[i]);
            unchecked { ++i; }
        }
        require(keccak256(abi.encode(creationCode)) == 
            keccak256(abi.encode(factory.getCreationCode())), "creationCode mismatch");
    }
}