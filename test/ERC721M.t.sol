// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "solady/utils/LibString.sol";
import "../src/ERC721M.sol";

contract ERC721MTest is DSTestPlus, ERC721Holder {

    using LibString for uint256;

    ERC721M public template;
    IERC721 public nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    MockERC20 public testToken;
    MockERC721 public testNFT;

    function setUp() public {
        template = new ERC721M(
            2000,
            500,
            address(nft),
            address(42),
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            0.01 ether
        );
        hevm.deal(address(this), 1000 ether);
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
    }

    function testName() public view {
        require(keccak256(abi.encodePacked(template.name())) == keccak256(abi.encodePacked("ERC721M Test")));
    }
    function testSymbol() public view {
        require(keccak256(abi.encodePacked(template.symbol())) == keccak256(abi.encodePacked("ERC721M")));
    }
    function testBaseUri() public view {
        require(keccak256(abi.encodePacked(template.baseUri())) == keccak256(abi.encodePacked("https://miya.wtf/api/")));
    }
    function testContractURI() public view {
        require(keccak256(abi.encodePacked(template.contractURI())) == keccak256(abi.encodePacked("https://miya.wtf/contract.json")));
    }

    function testTokenURI() public {
        hevm.prank(msg.sender);
        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        require(keccak256(abi.encodePacked(template.tokenURI(1))) == keccak256(abi.encodePacked(string.concat("https://miya.wtf/api/", uint256(template.totalSupply()).toString()))));
    }
    function testTokenURI_NotMinted() public {
        hevm.expectRevert(ERC721M.NotMinted.selector);
        template.tokenURI(1);
    }

    function testChangeFundsRecipient(address _to) public {
        hevm.assume(_to != address(0));
        hevm.prank(msg.sender);
        template.changeFundsRecipient(_to);
        require(template.fundsRecipient() == _to);
    }
    function testSetPrice(uint256 _price) public {
        hevm.assume(_price >= 10 gwei);
        hevm.assume(_price <= 1 ether);
        hevm.prank(msg.sender);
        template.setPrice(_price);
        require(template.price() == _price);
    }
    function testOpenMint() public {
        require(template.mintOpen() == false);
        hevm.prank(msg.sender);
        template.openMint();
        require(template.mintOpen() == true);
    }

    function testUpdateBaseURI() public {
        hevm.prank(msg.sender);
        template.updateBaseURI("ipfs://miyahash/");
        require(keccak256(abi.encodePacked(template.baseUri())) == keccak256(abi.encodePacked("ipfs://miyahash/")));
    }
    function testUpdateBaseURI_URILocked() public {
        hevm.startPrank(msg.sender);
        template.lockURI();
        hevm.expectRevert(ERC721M.URILocked.selector);
        template.updateBaseURI("ipfs://miyahash/");
        hevm.stopPrank();
    }
    function testLockURI() public {
        hevm.prank(msg.sender);
        template.lockURI();
        require(template.uriLocked() == true);
    }

    function testMint(address _to, uint256 _amount) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 100);
        hevm.assume(_to != address(0));
        hevm.prank(msg.sender);
        template.openMint();
        template.mint{ value: 0.01 ether * _amount }(_to, _amount);
    }
    function testMint_InsufficientPayment() public {
        hevm.prank(msg.sender);
        template.openMint();
        hevm.expectRevert(ERC721M.InsufficientPayment.selector);
        template.mint{ value: 0.001 ether }(address(this), 1);
    }
    function testMint_MintClosed() public {
        hevm.expectRevert(ERC721M.MintClosed.selector);
        template.mint{ value: 0.01 ether }(address(this), 1);
    }
    function testMint_CapReached() public {
        hevm.prank(msg.sender);
        template.openMint();
        template.mint{ value: 0.01 ether * 100 }(address(this), 100);
        hevm.expectRevert(ERC721M.CapReached.selector);
        template.mint{ value: 0.01 ether }(address(this), 1);
    }
    function testMint_CapExceeded() public {
        hevm.prank(msg.sender);
        template.openMint();
        hevm.expectRevert(ERC721M.CapExceeded.selector);
        template.mint{ value: 0.01 ether * 101 }(address(this), 101);
    }

    function testWrap(uint256 _amount) public {
        hevm.assume(_amount < 10 ether);
        (bool success, ) = payable(address(template.vault())).call{ value: _amount }("");
        require(success);
        hevm.prank(msg.sender);
        template.wrap(_amount);
    }
    function testAddInventory() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(template.vault()), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        hevm.prank(msg.sender);
        template.addInventory(tokenId);
    }
    function testAddLiquidity() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(template.vault()), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        (bool success, ) = payable(address(template.vault())).call{ value: 50 ether }("");
        require(success);
        hevm.startPrank(msg.sender);
        template.wrap(50 ether);
        template.addLiquidity(tokenId);
        hevm.stopPrank();
    }
    function testDeepenLiquidity() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        hevm.startPrank(msg.sender);
        template.wrap(1 ether);
        template.deepenLiquidity(1 ether, 1 ether, 0);
        hevm.stopPrank();
    }
    function testStakeLiquidity() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        hevm.startPrank(msg.sender);
        template.wrap(1 ether);
        template.deepenLiquidity(1 ether, 1 ether, 0);
        template.stakeLiquidity();
        hevm.stopPrank();
    }
    function testClaimRewardsCallable() public {
        hevm.prank(msg.sender);
        template.claimRewards(address(this));
    }
    function testCompoundRewards() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        hevm.startPrank(msg.sender);
        template.wrap(1 ether);
        template.compoundRewards(1 ether, 1 ether);
        hevm.stopPrank();
    }

    function testRescueERC20() public {
        testToken.transfer(address(template.vault()), 1 ether);
        hevm.prank(msg.sender);
        template.rescueERC20(address(testToken), address(42));
        require(testToken.balanceOf(address(42)) == 1 ether);
    }
    function testRescueERC721() public {
        testNFT.transferFrom(address(this), address(template.vault()), 1);
        hevm.prank(msg.sender);
        template.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }
    function testwithdrawFunds() public {
        hevm.prank(msg.sender);
        template.openMint();
        template.mint{ value: 0.01 ether }(address(42), 1);
        uint256 dust = address(42).balance;
        hevm.prank(msg.sender);
        template.withdrawFunds(address(42), 0.002 ether);
        require((address(42).balance - dust) == 0.002 ether);
    }

    function testReceive() public {
        (bool success, ) = payable(address(template)).call{ value: 1 ether }("");
        require(success);
        require(address(template.vault()).balance == 1 ether);
    }
    function testFallback() public {
        (bool success, ) = payable(address(template)).call{ value: 1 ether }(bytes("fallback"));
        require(success);
        require(address(template.vault()).balance == 1 ether);
    }
}