// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/AlignmentVault.sol";
import "../src/UniswapV2LiquidityHelper.sol";

contract AlignmentVaultTest is DSTestPlus {

    AlignmentVault vault;
    IERC721 nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT

    function setUp() public {
        vault = new AlignmentVault(address(nft));
    }

    function test_empty_checkBalanceNFT() public view { require(vault.checkBalanceNFT() == 0); }
    function test_empty_checkBalanceETH() public view { require(vault.checkBalanceETH() == 0); }
    function test_empty_checkBalanceWETH() public view { require(vault.checkBalanceWETH() == 0); }
    function test_empty_checkBalanceNFTXInventory() public view { require(vault.checkBalanceNFTXInventory() == 0); }
    function test_empty_checkBalanceNFTXLiquidity() public view { require(vault.checkBalanceNFTXLiquidity() == 0); }

    
}