// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "solady/utils/LibString.sol";
import "../src/ERC721M.sol";

interface IFallback {
    function doesntExist(uint256 _unusedVar) external payable;
}

contract ERC721MTest is DSTestPlus, ERC721Holder {

    using LibString for uint256;

    event CollectionDiscount(
        address indexed asset,
        uint256 indexed discount,
        uint256 indexed requiredBal,
        uint256 quantity
    );
    event DiscountDeleted(address indexed asset);
    event DiscountOverwritten(
        address indexed asset,
        uint256 indexed discount,
        uint256 indexed requiredBal,
        uint256 remainingQty
    );
    event MintLockDiscount(
        address indexed token,
        uint256 indexed discount,
        uint256 indexed amount,
        uint256 timestamp,
        uint256 quantity
    );
    event MintLockDiscountDeleted(address indexed token);
    event MintLockDiscountOverwritten(
        address indexed token,
        uint256 indexed discount,
        uint256 indexed amount,
        uint256 timestamp,
        uint256 remainingQty
    );

    struct MintInfo {
        int64 supply;
        int64 allocated;
        bool active;
        uint40 timelock;
        uint256 tokenBalance;
        uint256 mintPrice;
    }
    struct MinterInfo {
        uint256 amount;
        uint256[] amounts;
        uint40[] timelocks;
    }

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
            address(this),
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
        require(keccak256(abi.encodePacked(template.baseURI())) == keccak256(abi.encodePacked("https://miya.wtf/api/")));
    }
    function testContractURI() public view {
        require(keccak256(abi.encodePacked(template.contractURI())) == keccak256(abi.encodePacked("https://miya.wtf/contract.json")));
    }

    function testTokenURI() public {
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
        template.changeFundsRecipient(_to);
        require(template.fundsRecipient() == _to);
    }
    function testSetPrice(uint256 _price) public {
        hevm.assume(_price >= 10 gwei);
        hevm.assume(_price <= 1 ether);
        template.setPrice(_price);
        require(template.price() == _price);
    }
    function testOpenMint() public {
        require(template.mintOpen() == false);
        template.openMint();
        require(template.mintOpen() == true);
    }

    function testUpdateBaseURI() public {
        template.updateBaseURI("ipfs://miyahash/");
        require(keccak256(abi.encodePacked(template.baseURI())) == keccak256(abi.encodePacked("ipfs://miyahash/")));
    }
    function testUpdateBaseURI_URILocked() public {
        template.lockURI();
        hevm.expectRevert(ERC721M.URILocked.selector);
        template.updateBaseURI("ipfs://miyahash/");
    }
    function testLockURI() public {
        template.lockURI();
        require(template.uriLocked() == true);
    }

    function testMint(address _to, uint64 _amount) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount <= 100);
        hevm.assume(_to != address(0));
        template.openMint();
        template.mint{ value: 0.01 ether * _amount }(_to, _amount);
    }
    function testMint_InsufficientPayment() public {
        template.openMint();
        hevm.expectRevert(ERC721M.InsufficientPayment.selector);
        template.mint{ value: 0.001 ether }(address(this), 1);
    }
    function testMint_MintClosed() public {
        hevm.expectRevert(ERC721M.MintClosed.selector);
        template.mint{ value: 0.01 ether }(address(this), 1);
    }
    function testMint_CapReached() public {
        template.openMint();
        template.mint{ value: 0.01 ether * 100 }(address(this), 100);
        hevm.expectRevert(ERC721M.CapReached.selector);
        template.mint{ value: 0.01 ether }(address(this), 1);
    }
    function testMint_CapExceeded() public {
        template.openMint();
        hevm.expectRevert(ERC721M.CapExceeded.selector);
        template.mint{ value: 0.01 ether * 101 }(address(this), 101);
    }

    function configureMintDiscount() public {
        address[] memory assets = new address[](1);
        bool[] memory status = new bool[](1);
        int64[] memory allocations = new int64[](1);
        uint256[] memory tokenBalances = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        assets[0] = address(testToken);
        status[0] = true;
        allocations[0] = 10;
        tokenBalances[0] = 2 ether;
        prices[0] = 0.025 ether;
        template.configureMintDiscount(assets, status, allocations, tokenBalances, prices);
    }
    function testConfigureMintDiscount() public {
        configureMintDiscount();
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint40 timelock,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testToken));
        require(supply == 10, "supply error");
        require(allocated == 10, "allocated error");
        require(active == true, "active error");
        require(timelock == 0, "timelock error");
        require(tokenBalance == 2 ether, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testMintDiscount() public {
        configureMintDiscount();
        template.openMint();
        address asset = address(testToken);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.05 ether;
        template.mintDiscount{ value: payment }(asset, to, amount);
        require(template.balanceOf(address(this)) == 2, "balance error");
        require(template.ownerOf(1) == address(this), "owner/tokenId error");
        require(template.ownerOf(2) == address(this), "owner/tokenId error");
    }
    
    function testWrap(uint256 _amount) public {
        hevm.assume(_amount < 10 ether);
        (bool success, ) = payable(address(template.vault())).call{ value: _amount }("");
        require(success);
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
        template.wrap(50 ether);
        template.addLiquidity(tokenId);
    }
    function testDeepenLiquidity() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        template.wrap(1 ether);
        template.deepenLiquidity(1 ether, 1 ether, 0);
    }
    function testStakeLiquidity() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        template.wrap(1 ether);
        template.deepenLiquidity(1 ether, 1 ether, 0);
        template.stakeLiquidity();
    }
    function testClaimRewardsCallable() public {
        template.claimRewards(address(this));
    }
    function testCompoundRewards() public {
        (bool success, ) = payable(address(template.vault())).call{ value: 2 ether }("");
        require(success);
        template.wrap(1 ether);
        template.compoundRewards(1 ether, 1 ether);
    }

    function testRescueERC20() public {
        testToken.transfer(address(template.vault()), 1 ether);
        template.rescueERC20(address(testToken), address(42));
        require(testToken.balanceOf(address(42)) >= 1 ether);
    }
    // TODO: Implement tests for token locking
    // function testRescueERC20_LockedToken() public { }
    function testRescueERC721() public {
        testNFT.transferFrom(address(this), address(template.vault()), 1);
        template.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }

    function testWithdrawFunds() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(42), 1);
        uint256 dust = address(42).balance;
        template.withdrawFunds(address(42), 0.002 ether);
        require((address(42).balance - dust) == 0.002 ether);
    }
    function testWithdrawFundsRenounced() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(42), 1);
        template.renounceOwnership();
        uint256 dust = address(42).balance;
        template.withdrawFunds(address(69), 0.002 ether);
        require((address(42).balance - dust) == 0.002 ether);
    }
    function testWithdrawFunds_Unauthorized() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(42), 1);
        hevm.prank(address(42));
        hevm.expectRevert(Ownable.Unauthorized.selector);
        template.withdrawFunds(address(42), 0.002 ether);
    }

    function testReceive() public {
        (bool success, ) = payable(address(template)).call{ value: 1 ether }("");
        require(success);
        require(address(template.vault()).balance == 1 ether);
    }
    function testFallback() public {
        IFallback(address(template)).doesntExist{ value: 1 ether }(420);
        require(address(template.vault()).balance == 1 ether);
    }
    function test_processPayment() public {
        template.openMint();
        IFallback(address(template)).doesntExist{ value: 1 ether }(420);
        require(template.balanceOf(address(this)) > 0);
    }
}