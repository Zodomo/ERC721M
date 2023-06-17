// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";

import "./TestingAssetManager.sol";

contract AssetManagerTest is DSTestPlus {
    
    TestingAssetManager assetManager;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC721 nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    IUniswapV2Router02  sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IERC20 nftxInv = IERC20(0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY token
    IUniswapV2Pair nftWeth = IUniswapV2Pair(0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // MILADYWETH SLP

    function setUp() public {
        hevm.deal(address(this), 200 ether);
        weth.deposit{ value: 100 ether }();
        assetManager = new TestingAssetManager(address(nft));
    }

    function test_WETH() public view {
        require(assetManager.view_WETH() == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }
    function test_SUSHI_V2_FACTORY() public view {
        require(assetManager.view_SUSHI_V2_FACTORY() == 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);
    }
    function test_SUSHI_V2_ROUTER() public view {
        require(assetManager.view_SUSHI_V2_ROUTER() == 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    }
    function test_liqHelper() public view {
        require(assetManager.view_liqHelper() == assetManager.view_liqHelper());
    }

    function test_NFTX_VAULT_FACTORY() public view {
        require(assetManager.view_NFTX_VAULT_FACTORY() == 0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    }
    function test_NFTX_INVENTORY_STAKING() public view {
        require(assetManager.view_NFTX_INVENTORY_STAKING() == 0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);
    }
    function test_NFTX_LIQUIDITY_STAKING() public view {
        require(assetManager.view_NFTX_LIQUIDITY_STAKING() == 0x688c3E4658B5367da06fd629E41879beaB538E37);
    }
    function test_NFTX_STAKING_ZAP() public view {
        require(assetManager.view_NFTX_STAKING_ZAP() == 0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    }

    function test_erc721() public view {
        require(assetManager.view_erc721() == 0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    }
    function test_nftxInventory() public view {
        require(assetManager.view_nftxInventory() == 0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY
    }
    function test_nftxLiquidity() public view {
        require(assetManager.view_nftxLiquidity() == 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // NFTX MILADYWETH SLP
    }
    function test_vaultId() public view {
        require(assetManager.view_vaultId() == 392); // NFTX Milady Vault ID
    }
    
    // TODO: function test_checkBalance() public view { }

    function test_sortTokens(address _tokenA, address _tokenB) public {
        hevm.assume(_tokenA != _tokenB);
        hevm.assume(_tokenA != address(0));
        hevm.assume(_tokenB != address(0));
        (address token0, address token1) = assetManager.call_sortTokens(_tokenA, _tokenB);
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
        hevm.expectRevert(AssetManager.IdenticalAddresses.selector);
        assetManager.call_sortTokens(address(1), address(1));
    }
    function test_sortTokens_ZeroAddress_tokenA() public {
        hevm.expectRevert(AssetManager.ZeroAddress.selector);
        assetManager.call_sortTokens(address(0), address(1));
    }
    function test_sortTokens_ZeroAddress_tokenB() public {
        hevm.expectRevert(AssetManager.ZeroAddress.selector);
        assetManager.call_sortTokens(address(1), address(0));
    }

    function test_pairFor() public view {
        require(assetManager.call_pairFor(
            assetManager.view_WETH(),
            0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48 // NFTX MILADY token
        ) == 0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // MILADYWETH SLP
    }
    
    function test_wrap(uint256 _amount) public {
        hevm.deal(address(assetManager), _amount);
        assetManager.execute_wrap(_amount);
        require(wethToken.balanceOf(address(assetManager)) == _amount);
    }
    function test_wrap_InsufficientBalance() public {
        hevm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.execute_wrap(1 ether);
    }
    
    function test_addInventory() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(assetManager), 42);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        assetManager.execute_addInventory(tokenId);
    }
    function test_addInventoryBatch() public {
        uint[] memory tokenIds = new uint256[](10);
        for (uint256 i; i < 10; i++) { tokenIds[i] = i + 1; }
        for (uint256 i; i < tokenIds.length; i++) {
            hevm.startPrank(nft.ownerOf(tokenIds[i]));
            nft.approve(address(this), tokenIds[i]);
            nft.transferFrom(nft.ownerOf(tokenIds[i]), address(assetManager), tokenIds[i]);
            hevm.stopPrank();
        }
        assetManager.execute_addInventory(tokenIds);
    }
    function test_addInventoryBatch_InsufficientBalance() public {
        uint[] memory tokenIds = new uint256[](2);
        for (uint256 i; i < 2; i++) { tokenIds[i] = i + 1; }
        hevm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.execute_addInventory(tokenIds);
    }
    function test_addInventoryBatch_IncorrectOwner() public {
        uint[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 42;
        hevm.startPrank(nft.ownerOf(69));
        nft.approve(address(this), 69);
        nft.transferFrom(nft.ownerOf(69), address(assetManager), 69);
        hevm.expectRevert(AssetManager.IncorrectOwner.selector);
        assetManager.execute_addInventory(tokenIds);
        hevm.stopPrank();
    }

    function test_addLiquidity() public {
        hevm.assume(nft.ownerOf(42) > address(0));
        hevm.deal(nft.ownerOf(42), 100 ether);
        hevm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(assetManager), 42);
        weth.deposit{ value: 10 ether }();
        IERC20(address(weth)).approve(address(this), 10 ether);
        IERC20(address(weth)).transfer(address(assetManager), 10 ether);
        hevm.stopPrank();
        uint256[] memory tokenId = new uint256[](1);
        tokenId[0] = 42;
        assetManager.execute_addLiquidity(tokenId);
    }

    function test_deepenLiquidity_ETH() public {
        (bool success, ) = payable(address(assetManager)).call{ value: 10 ether }("");
        require(success);
        uint256 liquidity = assetManager.execute_deepenLiquidity(10 ether, 0, 0);
        require(liquidity > 0);
    }
    function test_deepenLiquidity_WETH() public {
        wethToken.transfer(address(assetManager), 10 ether);
        uint256 liquidity = assetManager.execute_deepenLiquidity(0, 10 ether, 0);
        require(liquidity > 0);
    }
    function test_deepenLiquidity_NFTX() public {
        wethToken.approve(address(sushiRouter), 100 ether);
        address[] memory path = new address[](2);
        (path[1], path[0]) = assetManager.call_sortTokens(address(weth), address(nftxInv));
        sushiRouter.swapTokensForExactTokens(10 ether, 100 ether, path, address(assetManager), block.timestamp + 60 seconds);
        assetManager.execute_deepenLiquidity(0, 0, 10 ether);
    }
    function test_deepenLiquidity_InsufficientBalance_ETH() public {
        hevm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.execute_deepenLiquidity(10 ether, 0, 0);
    }
    function test_deepenLiquidity_InsufficientBalance_WETH() public {
        hevm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.execute_deepenLiquidity(0, 10 ether, 0);
    }
    function test_deepenLiquidity_InsufficientBalance_NFTX() public {
        hevm.expectRevert(AssetManager.InsufficientBalance.selector);
        assetManager.execute_deepenLiquidity(0, 0, 10 ether);
    }

    function test_stakeLiquidity() public {
        wethToken.transfer(address(assetManager), 10 ether);
        uint256 liquidity = assetManager.execute_deepenLiquidity(0, 10 ether, 0);
        require(liquidity > 0);
        uint256 stakedLiquidity = assetManager.execute_stakeLiquidity();
        require(stakedLiquidity > 0);
    }
}
