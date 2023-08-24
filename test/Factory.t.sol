// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "solady/utils/LibString.sol";
import "../src/ERC721M.sol";
import "../src/ERC721MFactory.sol";

contract FactoryTest is DSTestPlus, ERC721Holder {

    ERC721MFactory factory = new ERC721MFactory();

    function setUp() public {}

    function testCreationCode() public returns (bytes memory) {
        return hevm.getCode("ERC721M.sol:ERC721M");
    }
}