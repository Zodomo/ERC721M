// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "./RevertingReceiver.sol";
import "./TestingAlignedNFT.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";

contract AlignedNFTTest is DSTestPlus, ERC721Holder  {

    AlignmentVault public vaultImplementation = new AlignmentVault();
    TestingAlignedNFT alignedNFT_HA;
    TestingAlignedNFT alignedNFT_LA;
    MockERC20 testToken;
    MockERC721 testNFT;
    IERC20 wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function setUp() public {
        bytes memory creationCode = hevm.getCode("AlignmentVaultFactory.sol");
        hevm.etch(address(7777777), abi.encodePacked(creationCode, abi.encode(address(this), address(vaultImplementation))));
        (bool success, bytes memory runtimeBytecode) = address(7777777).call{value: 0}("");
        require(success, "StdCheats deployCodeTo(string,bytes,uint256,address): Failed to create runtime bytecode.");
        hevm.etch(address(7777777), runtimeBytecode);

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
        alignedNFT_HA.execute_setTokenRoyalty();
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        testNFT.safeMint(address(this), 2);
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
        hevm.assume(_payment < 1 ether);
        alignedNFT_HA.execute_mint{ value: _payment }(address(this), _amount);
        uint256 allocation = FixedPointMathLib.fullMulDivUp(4200, _payment, 10000);
        require(wethToken.balanceOf(address(alignedNFT_HA.vault())) == allocation);
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

    function testRoyaltyInfoUnconfigured() public view {
        (address receiver, uint256 royalty) = alignedNFT_LA.royaltyInfo(0, 1 ether);
        require(receiver == address(0) && royalty == 0);
    }
    function testRoyaltyInitialization() public {
        (address receiver, ) = alignedNFT_HA.royaltyInfo(0, 0);
        require(receiver == address(this));
        (receiver, ) = alignedNFT_LA.royaltyInfo(0, 0);
        require(receiver == address(0));
        alignedNFT_LA.execute_setTokenRoyalty();
        (receiver, ) = alignedNFT_LA.royaltyInfo(0, 0);
        require(receiver == address(this));
    }
    function testDisableRoyalties() public {
        alignedNFT_HA.disableRoyalties();
        (address receiver, uint256 royaltyFee) = alignedNFT_HA.royaltyInfo(0, 1 ether);
        require(receiver == address(0) && royaltyFee == 0);
    }

    function testConfigureRoyalties(address _recipient, uint96 _royaltyFee) public {
        hevm.assume(_recipient != address(0));
        hevm.assume(_royaltyFee > 0);
        hevm.assume(_royaltyFee <= 10000);
        alignedNFT_HA.configureRoyalties(_recipient, _royaltyFee);
        (address receiver, uint256 royalty) = alignedNFT_HA.royaltyInfo(1, 1 ether);
        require(receiver == _recipient && royalty > 0);
    }
    function testConfigureRoyalties_ExceedsDenominator(address _recipient, uint96 _feeNumerator) public {
        hevm.assume(_recipient != address(0));
        hevm.assume(_feeNumerator > 10000);
        hevm.expectRevert(ERC2981.ExceedsDenominator.selector);
        alignedNFT_HA.configureRoyalties(address(420), _feeNumerator);
    }
    function testConfigureRoyalties_InvalidReceiver(uint96 _feeNumerator) public {
        hevm.assume(_feeNumerator <= 10000);
        hevm.expectRevert(ERC2981.InvalidReceiver.selector);
        alignedNFT_HA.configureRoyalties(address(0), _feeNumerator);
    }
    function testConfigureRoyalties_RoyaltiesDisabled(address _recipient, uint96 _feeNumerator) public {
        hevm.assume(_feeNumerator <= 10000);
        hevm.assume(_recipient != address(0));
        alignedNFT_HA.disableRoyalties();
        hevm.expectRevert(AlignedNFT.RoyaltiesDisabled.selector);
        alignedNFT_HA.configureRoyalties(address(420), 420);
    }

    function testConfigureRoyaltiesForId(
        uint256 _tokenId,
        address _recipient,
        uint96 _feeNumerator
    ) public {
        hevm.assume(_tokenId != 0);
        hevm.assume(_recipient != address(0));
        hevm.assume(_feeNumerator > 0);
        hevm.assume(_feeNumerator <= 10000);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, _recipient, _feeNumerator);
        (address recipient, uint256 royaltyFee) = alignedNFT_HA.royaltyInfo(_tokenId, 1 ether);
        require(recipient == _recipient && royaltyFee > 0);
    }
    function testConfigureRoyaltiesForIdResetRoyalty(
        uint256 _tokenId,
        address _recipient,
        uint96 _feeNumerator
    ) public {
        hevm.assume(_tokenId != 0);
        hevm.assume(_recipient != address(0));
        hevm.assume(_feeNumerator > 0);
        hevm.assume(_feeNumerator <= 10000);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, _recipient, _feeNumerator);
        (address recipient, uint256 royaltyFee) = alignedNFT_HA.royaltyInfo(_tokenId, 1 ether);
        require(recipient == _recipient && royaltyFee > 0);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, _recipient, 0);
        (recipient, royaltyFee) = alignedNFT_HA.royaltyInfo(_tokenId, 1 ether);
        require(recipient == address(0) && royaltyFee == 0);
    }
    function testConfigureRoyaltiesForId_ExceedsDenominator(
        uint256 _tokenId,
        address _recipient,
        uint96 _feeNumerator
    ) public {
        hevm.assume(_tokenId != 0);
        hevm.assume(_recipient != address(0));
        hevm.assume(_feeNumerator > 10000);
        hevm.expectRevert(ERC2981.ExceedsDenominator.selector);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, _recipient, _feeNumerator);
    }
    function testConfigureRoyaltiesForId_InvalidReceiver(uint256 _tokenId, uint96 _feeNumerator) public {
        hevm.assume(_tokenId != 0);
        hevm.assume(_feeNumerator > 0);
        hevm.assume(_feeNumerator <= 10000);
        hevm.expectRevert(ERC2981.InvalidReceiver.selector);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, address(0), _feeNumerator);
    }
    function testConfigureRoyaltiesForId_BadInput(address _recipient, uint96 _feeNumerator) public {
        hevm.assume(_recipient != address(0));
        hevm.expectRevert(AlignedNFT.BadInput.selector);
        alignedNFT_HA.configureRoyaltiesForId(0, _recipient, _feeNumerator);
    }
    function testConfigureRoyaltiesForId_RoyaltiesDisabled(
        uint256 _tokenId,
        address _recipient,
        uint96 _feeNumerator
    ) public {
        hevm.assume(_tokenId != 0);
        hevm.assume(_feeNumerator <= 10000);
        hevm.assume(_recipient != address(0));
        alignedNFT_HA.disableRoyalties();
        hevm.expectRevert(AlignedNFT.RoyaltiesDisabled.selector);
        alignedNFT_HA.configureRoyaltiesForId(_tokenId, _recipient, _feeNumerator);
    }

    function testConfigureBlacklist(address[] memory blacklist) public {
        alignedNFT_HA.configureBlacklist(blacklist);
        for (uint256 i; i < blacklist.length; ++i) {
            require(blacklist[i] == alignedNFT_HA.blacklistedAssets(i));
        }
    }
    function testConfigureBlacklist() public {
        address[] memory blacklist = new address[](3);
        blacklist[0] = address(1);
        blacklist[1] = address(42);
        blacklist[2] = address(710);
        alignedNFT_HA.configureBlacklist(blacklist);
        for (uint256 i; i < blacklist.length; ++i) {
            require(blacklist[i] == alignedNFT_HA.blacklistedAssets(i));
        }
    }

    function test_enforceBlacklistERC20SelfMint() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testToken);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(420), 5);
    }
    function test_enforceBlacklistERC721SelfMint() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testNFT.transferFrom(address(this), address(420), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(420), 5);
    }
    function test_enforceBlacklistTokenAndNFTSelfMint() public {
        address[] memory blacklist = new address[](2);
        blacklist[0] = address(testToken);
        blacklist[1] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        testNFT.transferFrom(address(this), address(420), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(420), 5);
    }
    function test_enforceBlacklistERC20Minter() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testToken);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistERC721Minter() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testNFT.transferFrom(address(this), address(420), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistTokenAndNFTMinter() public {
        address[] memory blacklist = new address[](2);
        blacklist[0] = address(testToken);
        blacklist[1] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        testNFT.transferFrom(address(this), address(420), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistERC20Recipient() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testToken);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(710), 10 ether);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistERC721Recipient() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testNFT.transferFrom(address(this), address(710), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistTokenAndNFTRecipient() public {
        address[] memory blacklist = new address[](2);
        blacklist[0] = address(testToken);
        blacklist[1] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(710), 10 ether);
        testNFT.transferFrom(address(this), address(710), 1);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistERC20MinterAndRecipient() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testToken);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        testToken.transfer(address(710), 10 ether);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistERC721MinterAndRecipient() public {
        address[] memory blacklist = new address[](1);
        blacklist[0] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testNFT.transferFrom(address(this), address(420), 1);
        testNFT.transferFrom(address(this), address(710), 2);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }
    function test_enforceBlacklistTokenAndNFTMinterAndRecipient() public {
        address[] memory blacklist = new address[](2);
        blacklist[0] = address(testToken);
        blacklist[1] = address(testNFT);
        alignedNFT_HA.configureBlacklist(blacklist);
        testToken.transfer(address(420), 10 ether);
        testToken.transfer(address(710), 10 ether);
        testNFT.transferFrom(address(this), address(420), 1);
        testNFT.transferFrom(address(this), address(710), 2);
        hevm.prank(address(420));
        hevm.expectRevert(AlignedNFT.Blacklisted.selector);
        alignedNFT_HA.execute_mint(address(710), 5);
    }

    function testSupportsInterface() public view {
        require(alignedNFT_HA.supportsInterface(type(IERC2981).interfaceId));
        require(alignedNFT_HA.supportsInterface(0x706e8489));
        require(alignedNFT_HA.supportsInterface(0x01ffc9a7));
        require(alignedNFT_HA.supportsInterface(0x80ac58cd));
        require(alignedNFT_HA.supportsInterface(0x5b5e139f));
        require(!alignedNFT_HA.supportsInterface(0xdeadbeef));
    }
}