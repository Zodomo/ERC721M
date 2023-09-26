// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "forge-std/console2.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "liquidity-helper/UniswapV2LiquidityHelper.sol";
import "./TestingAlignmentVault.sol";

interface IFallback {
    function doesntExist(uint256 _unusedVar) external payable;
}

contract AlignmentVaultTest is DSTestPlus, ERC721Holder  {

    error Unauthorized();
    
    TestingAlignmentVault alignmentVault;
    TestingAlignmentVault alignmentVaultManual;
    TestingAlignmentVault alignmentVaultInvalid;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC721 nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address sushiFactory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IERC20 nftxInv = IERC20(0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY token
    IUniswapV2Pair nftWeth = IUniswapV2Pair(0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // MILADYWETH SLP
    MockERC20 testToken;
    MockERC721 testNFT;
    UniswapV2LiquidityHelper liquidityHelper;

    function setUp() public {
        hevm.deal(address(this), 200 ether);
        weth.deposit{ value: 100 ether }();
        alignmentVault = new TestingAlignmentVault();
        alignmentVault.initialize(address(nft), 0);
        alignmentVault.disableInitializers();
        alignmentVaultManual = new TestingAlignmentVault();
        alignmentVaultManual.initialize(address(nft), 392);
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        liquidityHelper = new UniswapV2LiquidityHelper(sushiFactory, address(sushiRouter), address(weth));
    }

    function testManualVaultIdInitialization() public {
        require(alignmentVaultManual.vaultId() == 392, "vaultId error");
    }
    function testInvalidVaultId() public {
        alignmentVaultInvalid = new TestingAlignmentVault();
        hevm.expectRevert(AlignmentVault.InvalidVaultId.selector);
        alignmentVaultInvalid.initialize(address(nft), 420);
    }
    function testMissingNFTXVault() public {
        alignmentVaultInvalid = new TestingAlignmentVault();
        hevm.expectRevert(AlignmentVault.NoNFTXVault.selector);
        alignmentVaultInvalid.initialize(address(testNFT), 420);
    }

    function test_nftxInventory() public view {
        require(address(alignmentVault.nftxInventory()) == 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY
    }
    function test_nftxLiquidity() public view {
        require(address(alignmentVault.nftxLiquidity()) == 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // NFTX MILADYWETH SLP
    }
    function test_vaultId() public view {
        require(alignmentVault.vaultId() == 392); // NFTX Milady Vault ID
    }

    function test_estimateFloor() public view {
        require(alignmentVault.call_estimateFloor() > 0);
    }
    function test_estimateFloorReversedValues() public {
        address sproto = 0xEeca64ea9fCf99A22806Cd99b3d29cf6e8D54925;
        TestingAlignmentVault vaultBelowWeth = new TestingAlignmentVault();
        vaultBelowWeth.initialize(sproto, 0);
        require(vaultBelowWeth.call_estimateFloor() > 0);
    }
    
    function test_rescueERC20_ETH() public {
        address liqHelper = alignmentVault.view_liqHelper();
        (bool success, ) = payable(liqHelper).call{ value: 1 ether }("");
        require(success);
        uint256 recoveredETH = alignmentVault.rescueERC20(address(0), address(this));
        require(recoveredETH == 0);
        require(wethToken.balanceOf(address(alignmentVault)) == 1 ether);
    }
    function test_rescueERC20_WETH() public {
        address liqHelper = alignmentVault.view_liqHelper();
        wethToken.transfer(liqHelper, 1 ether);
        uint256 wethBal = wethToken.balanceOf(address(alignmentVault));
        uint256 recoveredWETH = alignmentVault.rescueERC20(address(weth), address(this));
        require(recoveredWETH == 0);
        uint256 wethBalDiff = wethToken.balanceOf(address(alignmentVault)) - wethBal;
        require(wethBalDiff > 0);
    }
    function test_rescueERC20_NFTX() public {
        address liqHelper = alignmentVault.view_liqHelper();
        wethToken.approve(address(sushiRouter), 100 ether);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(nftxInv);
        sushiRouter.swapTokensForExactTokens(1 ether, 100 ether, path, address(liqHelper), block.timestamp + 60 seconds);
        uint256 nftxBal = nftxInv.balanceOf(address(alignmentVault));
        uint256 recoveredNFTX = alignmentVault.rescueERC20(address(nftxInv), address(this));
        require(recoveredNFTX == 0);
        uint256 nftxBalDiff = nftxInv.balanceOf(address(alignmentVault)) - nftxBal;
        require(nftxBalDiff > 0);
    }
    function test_rescueERC20_NFTWETH() public {
        address liqHelper = alignmentVault.view_liqHelper();
        wethToken.approve(address(liquidityHelper), type(uint256).max);
        nftxInv.approve(address(liquidityHelper), type(uint256).max);
        uint256 liqBal = nftWeth.balanceOf(address(alignmentVault));
        uint256 liquidity = liquidityHelper.swapAndAddLiquidityTokenAndToken(address(weth), address(nftxInv), 1 ether, 0, 1, liqHelper);
        require(liquidity > 0);
        uint256 recoveredNFTXLiq = alignmentVault.rescueERC20(address(nftWeth), address(this));
        require(recoveredNFTXLiq == 0);
        uint256 liqBalDiff = nftWeth.balanceOf(address(alignmentVault)) - liqBal;
        require(liqBalDiff > 0);
    }
    function test_rescueERC20_ETC() public {
        address liqHelper = alignmentVault.view_liqHelper();
        testToken.transfer(address(alignmentVault), 1 ether);
        testToken.transfer(address(liqHelper), 1 ether);
        uint256 recoveredTEST = alignmentVault.rescueERC20(address(testToken), address(42));
        require(recoveredTEST == 2 ether);
        require(testToken.balanceOf(address(42)) == recoveredTEST);
    }

    function test_rescueERC721() public {
        testNFT.safeTransferFrom(address(this), address(alignmentVault), 1);
        require(testNFT.ownerOf(1) == address(alignmentVault));
        alignmentVault.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }
    function test_rescueERC721_AlignedAsset() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        hevm.stopPrank();
        hevm.expectRevert(AlignmentVault.AlignedAsset.selector);
        alignmentVault.rescueERC721(address(nft), address(42), 42);
    }

    function testReceive() public {
        address liqHelper = alignmentVault.view_liqHelper();
        (bool success, ) = payable(liqHelper).call{ value: 1 ether }("");
        require(success);
        require(address(liqHelper).balance == 1 ether);
        success = false;
        (success, ) = payable(address(alignmentVault)).call{ value: 1 ether }("");
        require(success);
        require(wethToken.balanceOf(address(alignmentVault)) == 1 ether);
    }
}