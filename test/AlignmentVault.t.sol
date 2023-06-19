// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "liquidity-helper/UniswapV2LiquidityHelper.sol";
import "../src/AlignmentVault.sol";

contract AlignmentVaultTest is DSTestPlus, ERC721Holder {

    AlignmentVault vault;
    IERC721 nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    MockERC20 testToken;
    MockERC721 testNFT;

    function setUp() public {
        vault = new AlignmentVault(address(nft));
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
    }

    function testCheckBalanceNFT_empty() public view { require(vault.checkBalanceNFT() == 0); }
    function testCheckBalanceETH_empty() public view { require(vault.checkBalanceETH() == 0); }
    function testCheckBalanceWETH_empty() public view { require(vault.checkBalanceWETH() == 0); }
    function testCheckBalanceNFTXInventory_empty() public view { require(vault.checkBalanceNFTXInventory() == 0); }
    function testCheckBalanceNFTXLiquidity_empty() public view { require(vault.checkBalanceNFTXLiquidity() == 0); }

    function testWrap(uint256 _amount) public {
        hevm.assume(_amount < 1 ether);
        (bool success, ) = payable(address(vault)).call{ value: _amount }("");
        require(success);
        vault.wrap(_amount);
    }

    function testAddInventory() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(vault), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        vault.addInventory(tokenId);
    }
    
    function testAddLiquidity() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(vault), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        (bool success, ) = payable(address(vault)).call{ value: 50 ether }("");
        require(success);
        vault.wrap(50 ether);
        vault.addLiquidity(tokenId);
    }

    function testDeepenLiquidity_ETH() public {
        (bool success, ) = payable(address(vault)).call{ value: 50 ether }("");
        require(success);
        vault.deepenLiquidity(50 ether, 0, 0);
    }
    function testDeepenLiquidity_WETH() public {
        (bool success, ) = payable(address(vault)).call{ value: 50 ether }("");
        require(success);
        vault.wrap(50 ether);
        vault.deepenLiquidity(0, 50 ether, 0);
    }

    function testStakeLiquidity() public {
        (bool success, ) = payable(address(vault)).call{ value: 50 ether }("");
        require(success);
        vault.deepenLiquidity(50 ether, 0, 0);
        vault.stakeLiquidity();
    }

    function testClaimRewards() public {
        vault.claimRewards();
    }

    function testRescueERC20() public {
        testToken.transfer(address(vault), 1 ether);
        vault.rescueERC20(address(testToken), address(42));
        require(testToken.balanceOf(address(42)) == 1 ether);
    }
    function testRescueERC721() public {
        testNFT.transferFrom(address(this), address(vault), 1);
        vault.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }
}