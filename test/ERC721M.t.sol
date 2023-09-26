// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "manual-tests/UnburnableERC20.sol";
import "manual-tests/FakeSendERC20.sol";
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
    UnburnableERC20 public testUnburnableToken;
    FakeSendERC20 public testFakeSendToken;
    MockERC721 public testNFT;
    IERC20 wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        template = new ERC721M();
        template.initialize(
            2000,
            500,
            address(nft),
            address(this),
            0
        );
        template.initializeMetadata(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            0.01 ether
        );
        template.changeFundsRecipient(address(42));
        hevm.deal(address(this), 1000 ether);
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testUnburnableToken = new UnburnableERC20("Unburnable Token", "UBTEST", 18);
        testUnburnableToken.mint(address(this), 100 ether);
        testFakeSendToken = new FakeSendERC20("Fake Send Token", "FSTEST", 18);
        testFakeSendToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        testNFT.safeMint(address(this), 2);
        testNFT.safeMint(address(this), 3);
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

    function testTransferOwnership(address _newOwner) public {
        hevm.assume(_newOwner != address(0));
        template.transferOwnership(_newOwner);
        require(template.owner() == _newOwner, "ownership transfer error");
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

    function configureMintDiscountERC20() public {
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
    function configureMintDiscountERC721() public {
        address[] memory assets = new address[](1);
        bool[] memory status = new bool[](1);
        int64[] memory allocations = new int64[](1);
        uint256[] memory tokenBalances = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        assets[0] = address(testNFT);
        status[0] = true;
        allocations[0] = 10;
        tokenBalances[0] = 2;
        prices[0] = 0.025 ether;
        template.configureMintDiscount(assets, status, allocations, tokenBalances, prices);
    }
    function testConfigureMintDiscountERC20() public {
        configureMintDiscountERC20();
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testToken));
        require(supply == 10, "supply error");
        require(allocated == 10, "allocated error");
        require(active == true, "active error");
        require(tokenBalance == 2 ether, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testConfigureMintDiscountERC721() public {
        configureMintDiscountERC721();
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testNFT));
        require(supply == 10, "supply error");
        require(allocated == 10, "allocated error");
        require(active == true, "active error");
        require(tokenBalance == 2, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testConfigureMintDiscount_ArrayLengthMismatch() public {
        address[] memory assets = new address[](1);
        bool[] memory status = new bool[](2);
        int64[] memory allocations = new int64[](1);
        uint256[] memory tokenBalances = new uint256[](1);
        uint256[] memory prices = new uint256[](1);
        assets[0] = address(testToken);
        status[0] = true;
        status[1] = false;
        allocations[0] = 10;
        tokenBalances[0] = 2 ether;
        prices[0] = 0.025 ether;
        hevm.expectRevert(LockRegistry.ArrayLengthMismatch.selector);
        template.configureMintDiscount(assets, status, allocations, tokenBalances, prices);
    }
    function testConfigureMintDiscount_Underflow() public {
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
        allocations[0] = -11;
        hevm.expectRevert(ERC721M.Underflow.selector);
        template.configureMintDiscount(assets, status, allocations, tokenBalances, prices);
    }
    function testConfigureMintDiscountReduceToZero() public {
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
        allocations[0] = -10;
        template.configureMintDiscount(assets, status, allocations, tokenBalances, prices);
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testToken));
        require(supply == 0, "supply error");
        require(allocated == 0, "allocated error");
        require(active == false, "active error");
        require(tokenBalance == 2 ether, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testMintDiscountERC20() public {
        configureMintDiscountERC20();
        template.openMint();
        address asset = address(testToken);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.05 ether;
        template.mintDiscount{ value: payment }(asset, to, amount);
        require(template.balanceOf(address(this)) == 2, "balance error");
        require(template.ownerOf(1) == address(this), "owner/tokenId error");
        require(template.ownerOf(2) == address(this), "owner/tokenId error");
        require(wethToken.balanceOf(address(template.vault())) == 0.01 ether, "vault balance error");
        require(address(template).balance == 0.04 ether, "contract balance error");
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testToken));
        require(supply == 8, "supply error");
        require(allocated == 10, "allocated error");
        require(active == true, "active error");
        require(tokenBalance == 2 ether, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testMintDiscountERC721() public {
        configureMintDiscountERC721();
        template.openMint();
        address asset = address(testNFT);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.05 ether;
        template.mintDiscount{ value: payment }(asset, to, amount);
        require(template.balanceOf(address(this)) == 2, "balance error");
        require(template.ownerOf(1) == address(this), "owner/tokenId error");
        require(template.ownerOf(2) == address(this), "owner/tokenId error");
        require(wethToken.balanceOf(address(template.vault())) == 0.01 ether, "vault balance error");
        require(address(template).balance == 0.04 ether, "contract balance error");
        (
            int64 supply,
            int64 allocated,
            bool active,
            uint256 tokenBalance,
            uint256 mintPrice
        ) = template.mintDiscountInfo(address(testNFT));
        require(supply == 8, "supply error");
        require(allocated == 10, "allocated error");
        require(active == true, "active error");
        require(tokenBalance == 2, "tokenBalance error");
        require(mintPrice == 0.025 ether, "mintPrice error");
    }
    function testMintDiscount_NotActive() public {
        template.openMint();
        address asset = address(testNFT);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.05 ether;
        hevm.expectRevert(ERC721M.NotActive.selector);
        template.mintDiscount{ value: payment }(asset, to, amount);
    }
    function testMintDiscount_SpecialExceeded() public {
        configureMintDiscountERC721();
        template.openMint();
        address asset = address(testNFT);
        address to = address(this);
        uint64 amount = 11;
        uint256 payment = 0.275 ether;
        hevm.expectRevert(ERC721M.SpecialExceeded.selector);
        template.mintDiscount{ value: payment }(asset, to, amount);
    }
    function testMintDiscount_InsufficientBalance() public {
        configureMintDiscountERC721();
        template.openMint();
        address asset = address(testNFT);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.05 ether;
        hevm.deal(address(420), 10 ether);
        hevm.expectRevert(ERC721M.InsufficientBalance.selector);
        hevm.prank(address(420));
        template.mintDiscount{ value: payment }(asset, to, amount);
    }
    function testMintDiscount_InsufficientPayment() public {
        configureMintDiscountERC721();
        template.openMint();
        address asset = address(testNFT);
        address to = address(this);
        uint64 amount = 2;
        uint256 payment = 0.04 ether;
        hevm.expectRevert(ERC721M.InsufficientPayment.selector);
        template.mintDiscount{ value: payment }(asset, to, amount);
    }
    function testMintDiscountAll() public {
        configureMintDiscountERC20();
        template.openMint();
        address asset = address(testToken);
        address to = address(this);
        uint64 amount = 10;
        uint256 payment = 0.25 ether;
        template.mintDiscount{ value: payment }(asset, to, amount);
    }

    function testRescueERC20() public {
        testToken.transfer(address(template.vault()), 1 ether);
        template.rescueERC20(address(testToken), address(42));
        require(testToken.balanceOf(address(42)) >= 1 ether);
    }
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
        require(wethToken.balanceOf(address(template.vault())) == 1 ether);
    }
    function testFallback() public {
        IFallback(address(template)).doesntExist{ value: 1 ether }(420);
        require(wethToken.balanceOf(address(template.vault())) == 1 ether);
    }
    function test_processPayment() public {
        template.openMint();
        IFallback(address(template)).doesntExist{ value: 1 ether }(420);
        require(template.balanceOf(address(this)) > 0);
    }
}