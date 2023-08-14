// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";
import "solady/utils/FixedPointMathLib.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "./RevertingReceiver.sol";
import "./TestingAlignedNFT.sol";

contract AlignedNFTTest is DSTestPlus {

    TestingAlignedNFT alignedNFT_HA;
    TestingAlignedNFT alignedNFT_LA;

    function setUp() public {
        // High alignment / low dev cut
        alignedNFT_HA = new TestingAlignedNFT(
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5, // Milady NFT
            address(42), // Non-aligned funds recipient
            4200 // 42.00% allocated
        );
        // Low alignment / high dev cut
        alignedNFT_LA = new TestingAlignedNFT(
            0x5Af0D9827E0c53E4799BB226655A1de152A425a5, // Milady NFT
            address(42), // Non-aligned funds recipient
            1500 // 15.00% allocated
        );
        hevm.deal(address(this), 100 ether);
    }

    // Generic tests for coverage
    function testName() public view {
        require(keccak256(abi.encodePacked(alignedNFT_LA.name())) == 
            keccak256(abi.encodePacked("AlignedNFT Test")));
    }
    function testSymbol() public view {
        require(keccak256(abi.encodePacked(alignedNFT_LA.symbol())) == 
            keccak256(abi.encodePacked("ANFTTest")));
    }
    function testTokenURI(uint256 _tokenId) public view {
        bytes memory tokenIdString = bytes(alignedNFT_LA.tokenURI(_tokenId));
        uint tokenId = 0;
        for (uint256 i = 0; i < tokenIdString.length; i++) {
            uint256 c = uint256(uint8(tokenIdString[i]));
            if (c >= 48 && c <= 57) {
                tokenId = tokenId * 10 + (c - 48);
            }
        }
        require(_tokenId == tokenId);
    }

    function testVaultBalance(uint256 _amount, uint256 _payment) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        hevm.assume(_payment > 1 gwei);
        hevm.assume(_payment < 0.01 ether);
        alignedNFT_LA.execute_mint{ value: _payment }(address(this), _amount);
        uint256 total = FixedPointMathLib.fullMulDivUp(_payment, 1500, 10000);
        require(alignedNFT_LA.vaultBalance() == total);
    }

    function test_changeFundsRecipient(address _to) public {
        hevm.assume(_to != address(0));
        alignedNFT_LA.execute_changeFundsRecipient(_to);
        require(alignedNFT_LA.fundsRecipient() == _to);
    }
    function test_changeFundsRecipient_ZeroAddress() public {
        hevm.expectRevert(AlignedNFT.ZeroAddress.selector);
        alignedNFT_LA.execute_changeFundsRecipient(address(0));
    }

    function test_mint_ownership(address _to, uint256 _amount) public {
        hevm.assume(_to != address(0));
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        alignedNFT_LA.execute_mint(_to, _amount);
        for (uint256 i; i < _amount; ++i) {
            require(IERC721(address(alignedNFT_LA)).ownerOf(i + 1) == _to);
        }
    }
    function test_mint_alignedAllocation(uint256 _amount, uint256 _payment) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        hevm.assume(_payment > 1 gwei);
        hevm.assume(_payment < 0.01 ether);
        alignedNFT_HA.execute_mint{ value: _payment }(address(this), _amount);
        uint256 allocation = FixedPointMathLib.fullMulDivUp(4200, _payment, 10000);
        require(alignedNFT_HA.vaultBalance() == allocation);
    }
    function test_mint_teamAllocation(uint256 _amount, uint256 _payment) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        hevm.assume(_payment > 1 gwei);
        hevm.assume(_payment < 0.01 ether);
        alignedNFT_LA.execute_mint{ value: _payment }(address(this), _amount);
        uint256 amount = FixedPointMathLib.fullMulDiv(8500, _payment, 10000);
        require (amount == address(alignedNFT_LA).balance);
    }
    function test_mint_ZeroQuantity() public {
        hevm.expectRevert(AlignedNFT.ZeroQuantity.selector);
        alignedNFT_HA.execute_mint{ value: 0.01 ether }(address(this), 0);
    }

    function test_withdrawFunds_max(uint256 _amount, uint256 _payment) public {
        uint256 dust = address(42).balance;
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        hevm.assume(_payment > 1 gwei);
        hevm.assume(_payment < 0.01 ether);
        alignedNFT_LA.execute_mint{ value: _payment }(address(this), _amount);
        uint256 withdraw = FixedPointMathLib.fullMulDiv(8500, _payment, 10000);
        require(withdraw == address(alignedNFT_LA).balance);
        alignedNFT_LA.execute_withdrawFunds(address(42), type(uint256).max);
        require((address(42).balance - dust) == withdraw);
    }
    function test_withdrawFunds_exact(uint256 _amount, uint256 _payment) public {
        uint256 dust = address(42).balance;
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 10000);
        hevm.assume(_payment > 1 gwei);
        hevm.assume(_payment < 0.01 ether);
        alignedNFT_LA.execute_mint{ value: _payment }(address(this), _amount);
        alignedNFT_LA.execute_withdrawFunds(address(42), 100000);
        require((address(42).balance - dust) == 100000);
    }
    function test_withdrawFunds_ZeroAddress() public {
        alignedNFT_LA.execute_mint{ value: 100 gwei }(address(this), 1);
        hevm.expectRevert(AlignedNFT.ZeroAddress.selector);
        alignedNFT_LA.execute_withdrawFunds(address(0), 100000);
    }
    function test_withdrawFunds_Overdraft() public {
        alignedNFT_LA.execute_mint{ value: 100 gwei }(address(this), 1);
        hevm.expectRevert(AlignedNFT.Overdraft.selector);
        alignedNFT_LA.execute_withdrawFunds(address(42), 101 gwei);
    }
    function test_withdrawFunds_TransferFailed() public {
        RevertingReceiver rr = new RevertingReceiver();
        alignedNFT_LA.execute_mint{ value: 100 gwei }(address(this), 1);
        hevm.expectRevert(AlignedNFT.TransferFailed.selector);
        alignedNFT_LA.execute_withdrawFunds(address(rr), 15 gwei);
    }

    function testRoyaltyInfoUnconfigured() public {}
}