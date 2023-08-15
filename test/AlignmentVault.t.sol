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
        alignmentVault = new TestingAlignmentVault(address(nft));
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        liquidityHelper = new UniswapV2LiquidityHelper(sushiFactory, address(sushiRouter), address(weth));
    }

    function test_WETH() public view {
        require(alignmentVault.view_WETH() == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }
    function test_SUSHI_V2_FACTORY() public view {
        require(alignmentVault.view_SUSHI_V2_FACTORY() == 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    }
    function test_SUSHI_V2_ROUTER() public view {
        require(alignmentVault.view_SUSHI_V2_ROUTER() == 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    }
    function test_liqHelper() public view {
        require(alignmentVault.view_liqHelper() == alignmentVault.view_liqHelper());
    }

    function test_NFTX_VAULT_FACTORY() public view {
        require(alignmentVault.view_NFTX_VAULT_FACTORY() == 0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    }
    function test_NFTX_INVENTORY_STAKING() public view {
        require(alignmentVault.view_NFTX_INVENTORY_STAKING() == 0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);
    }
    function test_NFTX_LIQUIDITY_STAKING() public view {
        require(alignmentVault.view_NFTX_LIQUIDITY_STAKING() == 0x688c3E4658B5367da06fd629E41879beaB538E37);
    }
    function test_NFTX_STAKING_ZAP() public view {
        require(alignmentVault.view_NFTX_STAKING_ZAP() == 0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    }

    function test_erc721() public view {
        require(alignmentVault.view_erc721() == 0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    }
    function test_nftxInventory() public view {
        require(alignmentVault.view_nftxInventory() == 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY
    }
    function test_nftxLiquidity() public view {
        require(alignmentVault.view_nftxLiquidity() == 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // NFTX MILADYWETH SLP
    }
    function test_vaultId() public view {
        require(alignmentVault.view_vaultId() == 392); // NFTX Milady Vault ID
    }

    function testCheckBalanceNFT() public {
        hevm.startPrank(nft.ownerOf(420));
        nft.approve(address(this), 420);
        nft.transferFrom(nft.ownerOf(420), address(alignmentVault), 420);
        hevm.stopPrank();
        require(alignmentVault.checkBalanceNFT() == 1);
    }
    function testCheckBalanceETH() public {
        (bool success, ) = payable(address(alignmentVault)).call{ value: 69 ether }("");
        require(success);
        require(alignmentVault.checkBalanceETH() == 69 ether);
    }
    function testCheckBalanceWETH() public {
        bool success = wethToken.transfer(address(alignmentVault), 69 ether);
        require(success);
        require(alignmentVault.checkBalanceWETH() == 69 ether);
    }
    // TODO: Finish NFTX inventory unstaking
    // function testCheckBalanceNFTXInventory() public { }
    function testCheckBalanceNFTXLiquidity() public {
        (bool success, ) = payable(address(alignmentVault)).call{ value: 25 ether }("");
        require(success);
        success = wethToken.transfer(address(alignmentVault), 52 ether);
        require(success);
        uint256 liquidity = alignmentVault.deepenLiquidity(25 ether, 52 ether, 0);
        require(alignmentVault.checkBalanceNFTXLiquidity() == liquidity);
    }

    function test_sortTokens(address _tokenA, address _tokenB) public {
        hevm.assume(_tokenA != _tokenB);
        hevm.assume(_tokenA != address(0));
        hevm.assume(_tokenB != address(0));
        (address token0, address token1) = alignmentVault.call_sortTokens(_tokenA, _tokenB);
        if (_tokenA < _tokenB) {
            require(_tokenA == token0);
            require(_tokenB == token1);
            require(token0 < token1);
        }
        if (_tokenA > _tokenB) {
            require(_tokenA == token1);
            require(_tokenB == token0);
            require(token0 < token1);
        }
    }
    function test_sortTokens_IdenticalAddresses() public {
        hevm.expectRevert(AlignmentVault.IdenticalAddresses.selector);
        alignmentVault.call_sortTokens(address(1), address(1));
    }
    function test_sortTokens_ZeroAddress_tokenA() public {
        hevm.expectRevert(AlignmentVault.ZeroAddress.selector);
        alignmentVault.call_sortTokens(address(0), address(1));
    }
    function test_sortTokens_ZeroAddress_tokenB() public {
        hevm.expectRevert(AlignmentVault.ZeroAddress.selector);
        alignmentVault.call_sortTokens(address(1), address(0));
    }

    function test_pairFor() public view {
        require(alignmentVault.call_pairFor(
            alignmentVault.view_WETH(),
            0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48 // NFTX MILADY token
        ) == 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // MILADYWETH SLP
    }

    function test_estimateFloor() public view {
        require(alignmentVault.call_estimateFloor() > 0);
    }
    function test_estimateFloorReversedValues() public {
        address sproto = 0xEeca64ea9fCf99A22806Cd99b3d29cf6e8D54925;
        TestingAlignmentVault vaultBelowWeth = new TestingAlignmentVault(address(sproto));
        require(vaultBelowWeth.call_estimateFloor() > 0);
    }
    
    function test_wrap(uint256 _amount) public {
        hevm.assume(_amount < 420 ether);
        hevm.deal(address(alignmentVault), _amount);
        alignmentVault.execute_wrap(_amount);
        require(wethToken.balanceOf(address(alignmentVault)) == _amount);
    }
    function test_wrap_InsufficientBalance() public {
        hevm.expectRevert(bytes(""));
        alignmentVault.execute_wrap(1 ether);
    }

    function test_decodeReservoirCalldata() public view {
        bytes memory data = hex"760f2a0b000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000f645877ab54e5856f39dc90425ae21748f52b5d400000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000006c1ba3ba104b00000000000000000000000000000000000000000000000000000000000000000c8480b102ff00000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000069789fbbc4f800000000000000000000000000000000000000000000000000000000000000000c20000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000560000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000034bc4fdde27c000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000046000000000000000000000000000000000000000000000000000000000000004c00000000000000000000000000374fec1e9db3348c95f8d9154fa25ef8e352892000000000000000000000000004c00500000ad104d7dbd00e3ae0a5c00560c0000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000649820400000000000000000000000000000000000000000000000000000000064bfad400000000000000000000000000000000000000000000000000000000000000000360c6ebe0000000000000000000000000000000000000000be7e3f98a9ef1f560000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f00000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000005af0d9827e0c53e4799bb226655a1de152a425a50000000000000000000000000000000000000000000000000000000000002152000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000336acddebcd28000000000000000000000000000000000000000000000000000336acddebcd280000000000000000000000000000374fec1e9db3348c95f8d9154fa25ef8e352892000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015181ff25a98000000000000000000000000000000000000000000000000000015181ff25a980000000000000000000000000000000a26b00c1f0df003000390027140000faa7190000000000000000000000000000000000000000000000000000000000000040e0c5f5e9f51668f3017113d98c40fd7ace5e093a97eb42abfa7a57961013e03cf380ac0b1a82bd65c06422ccb6cb1e7d58e050b6d373236de06592b1d379287d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000034bc4fdde27c000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000520000000000000000000000000000000000000000000000000000000000000058000000000000000000000000095bba6ac145f6b34433671800403752ae401c530000000000000000000000000004c00500000ad104d7dbd00e3ae0a5c00560c0000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000649c1e430000000000000000000000000000000000000000000000000000000064c3ab430000000000000000000000000000000000000000000000000000000000000000360c6ebe00000000000000000000000000000000000000006840985e04d11bc50000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f00000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000020000000000000000000000005af0d9827e0c53e4799bb226655a1de152a425a500000000000000000000000000000000000000000000000000000000000023b200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030c7c9e0717f800000000000000000000000000000000000000000000000000030c7c9e0717f800000000000000000000000000095bba6ac145f6b34433671800403752ae401c530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015181ff25a98000000000000000000000000000000000000000000000000000015181ff25a980000000000000000000000000000000a26b00c1f0df003000390027140000faa71900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a303fe4b53000000000000000000000000000000000000000000000000000002a303fe4b530000000000000000000000000000cf3e932f72e5f15411d125ad80579a3ef205b9b40000000000000000000000000000000000000000000000000000000000000040cd07c5f16fb9a93ca5a0c976e77ec5e3b098aff0a6eb5cb8c893810d9c686a542a96fd13363fdecd1f8c8e2cef9d0032cac8178602fb11576740eee3f80d15ce00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b520f068a908a1782a543aacc3847adb77a0477800000000000000000000000000000000000000000000000002a303fe4b530000000000000000000000000000000000000000000000000000000000001d4da48b5c926e10";
        OrderStructs.ExecutionInfo memory info = alignmentVault.decodeReservoirCalldata(data);
        console2.logBytes(info.data);
    }
    
    function test_addInventory() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        alignmentVault.execute_addInventory(tokenId);
    }
    function test_addInventoryBatch() public {
        uint[] memory tokenIds = new uint256[](10);
        for (uint256 i; i < 10; i++) { tokenIds[i] = i + 1; }
        for (uint256 i; i < tokenIds.length; i++) {
            hevm.startPrank(nft.ownerOf(tokenIds[i]));
            nft.approve(address(this), tokenIds[i]);
            nft.transferFrom(nft.ownerOf(tokenIds[i]), address(alignmentVault), tokenIds[i]);
            hevm.stopPrank();
        }
        alignmentVault.execute_addInventory(tokenIds);
    }

    function test_addLiquidity() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.deal(nft.ownerOf(42), 100 ether);
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        weth.deposit{ value: 50 ether }();
        IERC20(address(weth)).approve(address(this), 50 ether);
        IERC20(address(weth)).transfer(address(alignmentVault), 50 ether);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        alignmentVault.execute_addLiquidity(tokenId);
    }
    function test_addLiquidityBatch() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.assume(nft.ownerOf(69) > address(0));
        hevm.deal(nft.ownerOf(42), 100 ether);
        hevm.deal(nft.ownerOf(69), 100 ether);
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        weth.deposit{ value: 50 ether }();
        IERC20(address(weth)).approve(address(this), 50 ether);
        IERC20(address(weth)).transfer(address(alignmentVault), 50 ether);
        hevm.stopPrank();
        hevm.startPrank(nft.ownerOf(69));
        nft.approve(address(this), 69);
        nft.transferFrom(nft.ownerOf(69), address(alignmentVault), 69);
        weth.deposit{ value: 50 ether }();
        IERC20(address(weth)).approve(address(this), 50 ether);
        IERC20(address(weth)).transfer(address(alignmentVault), 50 ether);
        hevm.stopPrank();
        require(nft.balanceOf(address(alignmentVault)) == 2);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 42;
        tokenIds[1] = 69;
        alignmentVault.execute_addLiquidity(tokenIds);
    }
    function test_addLiquidityBatch(uint256 _amount) public {
        hevm.assume(_amount != 0);
        hevm.assume(_amount >= 5);
        hevm.assume(_amount <= 100);
        uint256[] memory tokenIds = new uint256[](_amount);
        uint256 ethAmount = _amount * 42 ether;
        hevm.deal(address(this), ethAmount);
        for (uint256 i = 1; i < _amount + 1; i++) {
            address miladyOwner = nft.ownerOf(i);
            hevm.startPrank(miladyOwner);
            nft.approve(address(this), i);
            nft.transferFrom(miladyOwner, address(alignmentVault), i);
            hevm.stopPrank();
            tokenIds[i - 1] = i;
        }
        weth.deposit{ value: ethAmount }();
        IERC20(address(weth)).transfer(address(alignmentVault), ethAmount);
        alignmentVault.execute_addLiquidity(tokenIds);
    }
    function test_addLiquidity_InsufficientBalance_Ether() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.deal(nft.ownerOf(42), 1 ether);
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        hevm.expectRevert(AlignmentVault.InsufficientBalance.selector);
        alignmentVault.execute_addLiquidity(tokenId);
    }
    function test_addLiquidity_wrapNecessaryETH() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.deal(nft.ownerOf(42), 1 ether);
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        (bool success, ) = payable(address(alignmentVault)).call{ value: 50 ether }("");
        require(success);
        alignmentVault.execute_addLiquidity(tokenId);
    }

    function test_deepenLiquidity_ETH() public {
        (bool success, ) = payable(address(alignmentVault)).call{ value: 10 ether }("");
        require(success);
        uint256 liquidity = alignmentVault.execute_deepenLiquidity(10 ether, 0, 0);
        require(liquidity > 0);
    }
    function test_deepenLiquidity_WETH() public {
        wethToken.transfer(address(alignmentVault), 10 ether);
        uint256 liquidity = alignmentVault.execute_deepenLiquidity(0, 10 ether, 0);
        require(liquidity > 0);
    }
    function test_deepenLiquidity_NFTX() public {
        wethToken.approve(address(sushiRouter), 100 ether);
        address[] memory path = new address[](2);
        (path[1], path[0]) = alignmentVault.call_sortTokens(address(weth), address(nftxInv));
        sushiRouter.swapTokensForExactTokens(10 ether, 100 ether, path, address(alignmentVault), block.timestamp + 60 seconds);
        alignmentVault.execute_deepenLiquidity(0, 0, 10 ether);
    }
    function test_deepenLiquidity_InsufficientBalance_ETH() public {
        hevm.expectRevert(AlignmentVault.InsufficientBalance.selector);
        alignmentVault.execute_deepenLiquidity(10 ether, 0, 0);
    }
    function test_deepenLiquidity_InsufficientBalance_WETH() public {
        hevm.expectRevert(AlignmentVault.InsufficientBalance.selector);
        alignmentVault.execute_deepenLiquidity(0, 10 ether, 0);
    }
    function test_deepenLiquidity_InsufficientBalance_NFTX() public {
        hevm.expectRevert(AlignmentVault.InsufficientBalance.selector);
        alignmentVault.execute_deepenLiquidity(0, 0, 10 ether);
    }

    function test_stakeLiquidity() public {
        wethToken.transfer(address(alignmentVault), 10 ether);
        uint256 liquidity = alignmentVault.execute_deepenLiquidity(0, 10 ether, 0);
        require(liquidity > 0);
        uint256 stakedLiquidity = alignmentVault.execute_stakeLiquidity();
        require(stakedLiquidity > 0);
    }

    function test_claimRewards() public {
        wethToken.transfer(address(alignmentVault), 10 ether);
        uint256 liquidity = alignmentVault.execute_deepenLiquidity(0, 10 ether, 0);
        require(liquidity > 0);
        uint256 stakedLiquidity = alignmentVault.execute_stakeLiquidity();
        require(stakedLiquidity > 0);
        alignmentVault.execute_claimRewards(address(this));
    }
    
    function test_compoundRewards_ETHWETH() public {
        (bool success, ) = payable(address(alignmentVault)).call{ value: 2 ether }("");
        require(success);
        alignmentVault.execute_wrap(1 ether);
        alignmentVault.execute_compoundRewards(1 ether, 1 ether);
    }
    function test_compoundRewards_ZeroValues() public {
        hevm.expectRevert(AlignmentVault.ZeroValues.selector);
        alignmentVault.execute_compoundRewards(0, 0);
    }

    function test_rescueERC20_ETH() public {
        address liqHelper = alignmentVault.view_liqHelper();
        (bool success, ) = payable(liqHelper).call{ value: 1 ether }("");
        require(success);
        uint256 ethBal = address(alignmentVault).balance;
        uint256 recoveredETH = alignmentVault.execute_rescueERC20(address(0), address(this));
        require(recoveredETH > 0);
        uint256 ethBalDiff = address(alignmentVault).balance - ethBal;
        require(ethBalDiff > 0);
    }
    function test_rescueERC20_WETH() public {
        address liqHelper = alignmentVault.view_liqHelper();
        wethToken.transfer(liqHelper, 1 ether);
        uint256 wethBal = wethToken.balanceOf(address(alignmentVault));
        uint256 recoveredWETH = alignmentVault.execute_rescueERC20(address(weth), address(this));
        require(recoveredWETH > 0);
        uint256 wethBalDiff = wethToken.balanceOf(address(alignmentVault)) - wethBal;
        require(wethBalDiff > 0);
    }
    function test_rescueERC20_NFTX() public {
        address liqHelper = alignmentVault.view_liqHelper();
        wethToken.approve(address(sushiRouter), 100 ether);
        address[] memory path = new address[](2);
        (path[1], path[0]) = alignmentVault.call_sortTokens(address(weth), address(nftxInv));
        sushiRouter.swapTokensForExactTokens(1 ether, 100 ether, path, address(liqHelper), block.timestamp + 60 seconds);
        uint256 nftxBal = nftxInv.balanceOf(address(alignmentVault));
        uint256 recoveredNFTX = alignmentVault.execute_rescueERC20(address(nftxInv), address(this));
        require(recoveredNFTX > 0);
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
        alignmentVault.execute_rescueERC20(address(nftWeth), address(this));
        uint256 liqBalDiff = nftWeth.balanceOf(address(alignmentVault)) - liqBal;
        require(liqBalDiff > 0);
    }
    function test_rescueERC20_ETC() public {
        address liqHelper = alignmentVault.view_liqHelper();
        testToken.transfer(address(alignmentVault), 1 ether);
        testToken.transfer(address(liqHelper), 1 ether);
        uint256 recoveredTEST = alignmentVault.execute_rescueERC20(address(testToken), address(42));
        require(recoveredTEST == 2 ether);
        require(testToken.balanceOf(address(42)) == recoveredTEST);
    }

    function test_rescueERC721() public {
        testNFT.safeTransferFrom(address(this), address(alignmentVault), 1);
        require(testNFT.ownerOf(1) == address(alignmentVault));
        alignmentVault.execute_rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }
    function test_rescueERC721_AlignedAsset() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(alignmentVault), 42);
        hevm.stopPrank();
        hevm.expectRevert(AlignmentVault.AlignedAsset.selector);
        alignmentVault.execute_rescueERC721(address(nft), address(42), 42);
    }

    function testReceive() public {
        address liqHelper = alignmentVault.view_liqHelper();
        (bool success, ) = payable(liqHelper).call{ value: 1 ether }("");
        require(success);
    }
    function testFallback() public {
        IFallback(address(alignmentVault)).doesntExist{ value: 1 ether }(420);
        require(address(alignmentVault).balance == 1 ether);
    }
}