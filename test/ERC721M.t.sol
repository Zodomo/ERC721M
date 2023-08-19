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
        require(keccak256(abi.encodePacked(template.baseUri())) == keccak256(abi.encodePacked("ipfs://miyahash/")));
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

    function testMint(address _to, uint256 _amount) public {
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

    function testConfigureMintDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);
        require(template.collectionDiscount(token, 0) == price[0], "price error");
        require(template.collectionDiscount(token, 1) == required[0], "required error");
        require(template.collectionDiscount(token, 2) == quantity[0], "quantity error");
    }
    function testConfigureMintDiscountOverwriteDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        template.mintDiscount{ value: 0.001 ether }(token, address(this), 1);

        price[0] = 0.002 ether;
        required[0] = 2 ether;
        quantity[0] = 9;
        hevm.expectEmit(true, true, true, true);
        emit DiscountOverwritten(address(testToken), 0.001 ether, 1 ether, 9);
        template.configureMintDiscount(asset, price, required, quantity);
    }
    function testConfigureMintDiscountEraseDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);

        price[0] = 100 ether;
        required[0] = 69 ether;
        quantity[0] = 0;
        template.configureMintDiscount(asset, price, required, quantity);
        hevm.expectEmit(true, true, true, true);
        emit DiscountDeleted(token);
        template.configureMintDiscount(asset, price, required, quantity);
    }
    function testConfigureMintDiscount_ArrayLengthMismatch() public {
        address token = address(testToken);
        address[] memory asset = new address[](2);
        asset[0] = token;
        asset[1] = address(this);
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        hevm.expectRevert(LockRegistry.ArrayLengthMismatch.selector);
        template.configureMintDiscount(asset, price, required, quantity);
    }

    function testMintDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        template.mintDiscount{ value: 0.001 ether }(token, address(this), 1);
        require(template.balanceOf(address(this)) == 1);
        require(address(template.vault()).balance == 0.0002 ether);
        require(address(template).balance == 0.0008 ether);
        quantity[0] = 9;
        require(template.collectionDiscount(token, 2) == quantity[0], "quantity error");
    }
    function testMintDiscountBatchMint() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        template.mintDiscount{ value: 0.003 ether }(token, address(this), 3);
        require(template.balanceOf(address(this)) == 3);
        require(address(template.vault()).balance == 0.0006 ether);
        require(address(template).balance == 0.0024 ether);
        quantity[0] = 7;
        require(template.collectionDiscount(token, 2) == quantity[0], "quantity error");
    }
    function testMintDiscountUnconfigured_NoDiscount() public {
        address token = address(testToken);
        template.openMint();
        hevm.expectRevert(ERC721M.NoDiscount.selector);
        template.mintDiscount{ value: 0.003 ether }(token, address(this), 3);
    }
    function testMintDiscountErased_NoDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 10;
        template.configureMintDiscount(asset, price, required, quantity);

        price[0] = 100 ether;
        required[0] = 69 ether;
        quantity[0] = 0;
        template.configureMintDiscount(asset, price, required, quantity);
        hevm.expectEmit(true, true, true, true);
        emit DiscountDeleted(token);
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        hevm.expectRevert(ERC721M.NoDiscount.selector);
        template.mintDiscount{ value: 0.003 ether }(token, address(this), 3);
    }
    function testMintDiscountExhausted_NoDiscount() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 2;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        template.mintDiscount{ value: 0.01 ether }(token, address(this), 2);
        require(template.balanceOf(address(this)) == 2);
        require(address(template.vault()).balance == 0.002 ether);
        require(address(template).balance == 0.008 ether);

        hevm.expectRevert(ERC721M.NoDiscount.selector);
        template.mintDiscount{ value: 0.0042 ether }(token, address(this), 1);
    }
    function testMintDiscount_DiscountExceeded() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 2;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        hevm.expectRevert(ERC721M.DiscountExceeded.selector);
        template.mintDiscount{ value: 0.01 ether }(token, address(this), 3);
    }
    function testMintDiscount_InsufficientAssetBalance() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 0.001 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 42069 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 2;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        hevm.expectRevert(ERC721M.InsufficientAssetBalance.selector);
        template.mintDiscount{ value: 0.01 ether }(token, address(this), 2);
    }
    function testMintDiscount_InsufficientPayment() public {
        address token = address(testToken);
        address[] memory asset = new address[](1);
        asset[0] = token;
        uint256[] memory price = new uint256[](1);
        price[0] = 1 ether;
        uint256[] memory required = new uint256[](1);
        required[0] = 1 ether;
        uint256[] memory quantity = new uint256[](1);
        quantity[0] = 2;
        template.configureMintDiscount(asset, price, required, quantity);

        template.openMint();
        hevm.expectRevert(ERC721M.InsufficientPayment.selector);
        template.mintDiscount{ value: 0.01 ether }(token, address(this), 2);
    }

    function testConfigureMintLockTokens() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        quantity[0] = 10;

        hevm.expectEmit(true, true, true, true);
        emit MintLockDiscount(address(testToken), 0.0042 ether, 1 ether, block.timestamp + 1000, 10);
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
    }
    function testConfigureMintLockTokensMultiple() public {
        address[] memory tokens = new address[](2);
        uint256[] memory discounts = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory timestamps = new uint256[](2);
        uint256[] memory quantity = new uint256[](2);
        tokens[0] = address(testToken);
        tokens[1] = address(42069);
        discounts[0] = 0.0042 ether;
        discounts[1] = 0.0069 ether;
        amounts[0] = 1 ether;
        amounts[1] = 2 ether;
        timestamps[0] = block.timestamp + 1000;
        timestamps[1] = block.timestamp + 2000;
        quantity[0] = 10;
        quantity[1] = 20;

        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
        require(template.lockableTokens(tokens[1], 0) == 0.0069 ether);
        require(template.lockableTokens(tokens[1], 1) == 2 ether);
        require(template.lockableTokens(tokens[1], 2) == block.timestamp + 2000);
        require(template.lockableTokens(tokens[1], 3) == 20);
    }
    function testConfigureMintLockTokensEraseDiscount() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        quantity[0] = 10;

        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
        quantity[0] = 0;
        hevm.expectEmit(true, true, true, true);
        emit MintLockDiscountDeleted(tokens[0]);
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
    }
    function testConfigureMintLockTokensOverwriteDiscount() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        quantity[0] = 10;

        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
        discounts[0] = 1 ether;
        amounts[0] = 2 ether;
        timestamps[0] = block.timestamp + 100000;
        quantity[0] = 20;
        hevm.expectEmit(true, true, true, true);
        emit MintLockDiscountOverwritten(address(testToken), 0.0042 ether, 1 ether, block.timestamp + 1000, 10);
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
    }
    function testConfigureMintLockTokens_ArrayLengthMismatch() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](2);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        timestamps[1] = 42069;
        quantity[0] = 10;
        hevm.expectRevert(LockRegistry.ArrayLengthMismatch.selector);
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
    }

    function testMintLockTokens() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        quantity[0] = 10;
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
        template.openMint();
        testToken.approve(address(template), type(uint256).max);
        template.mintLockTokens{ value: 0.0042 ether }(address(this), tokens, amounts);
        require(template.balanceOf(address(this)) == 1);
    }
    function testMintLockTokensMultiple() public {
        address[] memory tokens = new address[](1);
        uint256[] memory discounts = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory timestamps = new uint256[](1);
        uint256[] memory quantity = new uint256[](1);
        tokens[0] = address(testToken);
        discounts[0] = 0.0042 ether;
        amounts[0] = 1 ether;
        timestamps[0] = block.timestamp + 1000;
        quantity[0] = 10;
        template.configureMintLockTokens(tokens, discounts, amounts, timestamps, quantity);
        template.openMint();
        testToken.approve(address(template), type(uint256).max);
        template.mintLockTokens{ value: 0.0042 ether }(address(this), tokens, amounts);
        template.mintLockTokens{ value: 0.0042 ether }(address(this), tokens, amounts);
        require(template.balanceOf(address(this)) == 2);
    }
    function testMintLockTokens_MintClosed() public {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        hevm.expectRevert(ERC721M.MintClosed.selector);
        template.mintLockTokens(address(this), tokens, amounts);
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