// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../lib/liquidity-helper/UniswapV2LiquidityHelper.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../../lib/solady/test/utils/mocks/MockERC20.sol";
import "../../lib/solady/test/utils/mocks/MockERC721.sol";
import "../../src/ERC721M-cyoa.sol";
import "../../src/IERC721M-cyoa.sol";

interface IFallback {
    function doesntExist(uint256 _unusedVar) external payable;
}

contract ERC721MTest is Test, ERC721Holder {
    using LibString for uint256;

    ERC721M public template;
    ERC721M public manualInit;
    IERC721 public nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT
    MockERC20 public testToken;
    MockERC721 public testNFT;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 wethToken = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router02 sushiRouter = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IERC20 nftxInv = IERC20(0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48); // NFTX MILADY token
    IUniswapV2Pair nftWeth = IUniswapV2Pair(0x15A8E38942F9e353BEc8812763fb3C104c89eCf4); // MILADYWETH SLP

    function setUp() public {
        template = new ERC721M();
        template.initialize(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            500,
            2000,
            address(this),
            address(nft),
            0.01 ether,
            392
        );
        vm.deal(address(this), 1000 ether);
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        testNFT.safeMint(address(this), 2);
        testNFT.safeMint(address(this), 3);
    }

    function testInitialize() public {
        manualInit = new ERC721M();
        manualInit.initialize(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            500,
            2000,
            address(this),
            address(nft),
            0.01 ether,
            392
        );
        manualInit.disableInitializers();
        require(manualInit.minAllocation() == 2000);
        (address recipient, uint256 royalty) = manualInit.royaltyInfo(0, 1 ether);
        require(recipient == address(this));
        require(royalty == 0.05 ether);
        require(manualInit.alignedNft() == address(nft));
        require(manualInit.owner() == address(this));
        require(keccak256(abi.encodePacked(manualInit.name())) == keccak256(abi.encodePacked("ERC721M Test")));
        require(keccak256(abi.encodePacked(manualInit.symbol())) == keccak256(abi.encodePacked("ERC721M")));
        require(
            keccak256(abi.encodePacked(manualInit.baseURI())) == keccak256(abi.encodePacked("https://miya.wtf/api/"))
        );
        require(
            keccak256(abi.encodePacked(manualInit.contractURI()))
                == keccak256(abi.encodePacked("https://miya.wtf/contract.json"))
        );
        require(manualInit.maxSupply() == 100);
        require(manualInit.price() == 0.01 ether);
    }

    function testInitializeRevertNotAligned() public {
        manualInit = new ERC721M();
        vm.expectRevert(ERC721M.NotAligned.selector);
        manualInit.initialize(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            500,
            250,
            address(this),
            address(nft),
            0.01 ether,
            392
        );
    }

    function testInitializeRevertInvalid() public {
        manualInit = new ERC721M();
        vm.expectRevert(ERC721M.Invalid.selector);
        manualInit.initialize(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            500,
            10001,
            address(this),
            address(nft),
            0.01 ether,
            392
        );
        vm.expectRevert(ERC721M.Invalid.selector);
        manualInit.initialize(
            "ERC721M Test",
            "ERC721M",
            "https://miya.wtf/api/",
            "https://miya.wtf/contract.json",
            100,
            10001,
            2000,
            address(this),
            address(nft),
            0.01 ether,
            392
        );
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
        require(
            keccak256(abi.encodePacked(template.contractURI()))
                == keccak256(abi.encodePacked("https://miya.wtf/contract.json"))
        );
    }

    function testTokenURI() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        require(
            keccak256(abi.encodePacked(template.tokenURI(1)))
                == keccak256(
                    abi.encodePacked(string.concat("https://miya.wtf/api/", uint256(template.totalSupply()).toString()))
                )
        );
    }

    function testTokenURIRevertNotMinted() public {
        vm.expectRevert(ERC721M.NotMinted.selector);
        template.tokenURI(1);
    }

    function testSetPrice(uint80 _price) public {
        vm.assume(_price >= 10 gwei);
        vm.assume(_price <= 1 ether);
        template.setPrice(_price);
        require(template.price() == _price);
    }

    function testOpenMint() public {
        require(template.mintOpen() == false);
        template.openMint();
        require(template.mintOpen() == true);
    }

    function testSetBaseURI() public {
        template.setBaseURI("ipfs://miyahash/");
        require(keccak256(abi.encodePacked(template.baseURI())) == keccak256(abi.encodePacked("ipfs://miyahash/")));
    }

    function testSetBaseURIRevertURILocked() public {
        template.lockURI();
        vm.expectRevert(ERC721M.URILocked.selector);
        template.setBaseURI("ipfs://miyahash/");
    }

    function testLockURI() public {
        template.lockURI();
        require(template.uriLocked() == true);
    }

    function testTransferOwnership(address _newOwner) public {
        vm.assume(_newOwner != address(0));
        template.transferOwnership(_newOwner);
        require(template.owner() == _newOwner, "ownership transfer error");
    }

    function testMint(address _to, uint64 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_amount <= 100);
        vm.assume(_to != address(0));
        template.openMint();
        template.mint{value: 0.01 ether * _amount}(_to, _amount, 2000);
    }

    function testMintRevertInsufficientPayment() public {
        template.openMint();
        vm.expectRevert(ERC721M.InsufficientPayment.selector);
        template.mint{value: 0.001 ether}(address(this), 1, 2000);
    }

    function testMintRevertMintClosed() public {
        vm.expectRevert(ERC721M.MintClosed.selector);
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
    }

    function testMintRevertMintCapReached() public {
        template.openMint();
        template.mint{value: 0.01 ether * 100}(address(this), 100, 2000);
        vm.expectRevert(ERC721M.MintCap.selector);
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
    }

    function testMintRevertMintCapExceeded() public {
        template.openMint();
        vm.expectRevert(ERC721M.MintCap.selector);
        template.mint{value: 0.01 ether * 101}(address(this), 101, 2000);
    }

    function testFixInventory() public {
        vm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(template), 42);
        vm.stopPrank();
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 42;
        template.fixInventory(tokenIds);
        require(nft.balanceOf(address(template)) == 0);
        require(nft.balanceOf(address(template.vault())) == 1);
    }

    function testCheckInventory() public {
        vm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(template.vault()), 42);
        vm.stopPrank();
        vm.deal(address(template.vault()), 10 ether);
        template.alignMaxLiquidity();
        require(nft.balanceOf(address(template.vault())) == 1);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 42;
        template.checkInventory(tokenIds);
        vm.deal(address(template.vault()), 10 ether);
        template.alignMaxLiquidity();
        require(nft.balanceOf(address(template.vault())) == 0);
    }

    function testAlignMaxLiquidityNoLiquidity() public {
        template.alignMaxLiquidity();
    }

    function testAlignMaxLiquidityETH() public {
        address vault = address(template.vault());
        vm.deal(vault, 1 ether);
        require(address(vault).balance == 1 ether);
        template.alignMaxLiquidity();
        require(address(vault).balance == 0, "eth balance error");
    }

    function testClaimYieldNone() public {
        template.claimYield(address(this));
    }

    function testCompoundYieldNone() public {
        template.claimYield(address(0));
    }

    function testClaimYieldNoneRenounced() public {
        template.renounceOwnership();
        template.claimYield(address(this));
    }

    function testCompoundYieldNoneRenounced() public {
        template.renounceOwnership();
        template.claimYield(address(0));
    }

    function testClaimYieldRevertUnauthorized() public {
        vm.prank(address(1));
        vm.expectRevert(Ownable.Unauthorized.selector);
        template.claimYield(address(1));
    }

    function testClaimYieldGenerated() public {
        vm.deal(address(template.vault()), 100 ether);
        template.alignMaxLiquidity();
        weth.deposit{value: 100 ether}();
        wethToken.approve(address(sushiRouter), type(uint256).max);
        nftxInv.approve(address(sushiRouter), type(uint256).max);
        address[] memory path = new address[](2);
        uint256 balance;
        for (uint256 i; i < 10; ++i) {
            balance = wethToken.balanceOf(address(this));
            path[0] = address(weth);
            path[1] = address(nftxInv);
            sushiRouter.swapExactTokensForTokens(balance, 1, path, address(this), block.timestamp);
            uint256 nftxBal = nftxInv.balanceOf(address(this));
            path[0] = address(nftxInv);
            path[1] = address(weth);
            sushiRouter.swapExactTokensForTokens(nftxBal, 1, path, address(this), block.timestamp);
        }
        balance = wethToken.balanceOf(address(this));
        path[0] = address(weth);
        path[1] = address(nftxInv);
        sushiRouter.swapExactTokensForTokens(balance, 1, path, address(template.vault()), block.timestamp);
        template.claimYield(address(this));
        require(nftxInv.balanceOf(address(this)) > 0, "nftxInv claim balance error");
    }

    function testRescueERC20() public {
        testToken.transfer(address(template), 1 ether);
        template.rescueERC20(address(testToken), address(42));
        require(testToken.balanceOf(address(42)) >= 1 ether);
    }

    function testRescueERC721() public {
        testNFT.transferFrom(address(this), address(template), 1);
        template.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }

    function testRescueERC721Vault() public {
        testNFT.transferFrom(address(this), address(template.vault()), 1);
        template.rescueERC721(address(testNFT), address(42), 1);
        require(testNFT.ownerOf(1) == address(42));
    }

    function testRescueERC721AlignedAsset() public {
        vm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.transferFrom(nft.ownerOf(42), address(template), 42);
        vm.stopPrank();
        template.rescueERC721(address(nft), address(42), 42);
        require(nft.ownerOf(42) == address(template.vault()));
    }

    function testWithdrawFunds() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(42), 1, 2000);
        uint256 dust = address(42).balance;
        template.withdrawFunds(address(42), 0.002 ether);
        require((address(42).balance - dust) == 0.002 ether);
    }

    function testWithdrawFundsRenounced() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(42), 1, 2000);
        template.renounceOwnership();
        template.withdrawFunds(address(69), 0.0000001 ether);
        require(wethToken.balanceOf(template.vault()) == 0.01 ether);
    }

    function testWithdrawFundsRevertUnauthorized() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(42), 1, 2000);
        vm.prank(address(42));
        vm.expectRevert(Ownable.Unauthorized.selector);
        template.withdrawFunds(address(42), 0.002 ether);
    }

    function testReceive() public {
        (bool success,) = payable(address(template)).call{value: 1 ether}("");
        require(success);
        require(wethToken.balanceOf(address(template.vault())) == 1 ether);
    }

    function testFallback() public {
        IFallback(address(template)).doesntExist{value: 1 ether}(420);
        require(wethToken.balanceOf(address(template.vault())) == 1 ether);
    }

    function testOnERC721Received() public {
        vm.startPrank(nft.ownerOf(42));
        nft.approve(address(this), 42);
        nft.safeTransferFrom(nft.ownerOf(42), address(template), 42);
        vm.stopPrank();
        require(nft.ownerOf(42) == address(template.vault()), "NFT redirection failed");
    }

    function testOnERC721ReceivedRevertNotAligned() public {
        vm.expectRevert(ERC721M.NotAligned.selector);
        testNFT.safeTransferFrom(address(this), address(template), 1);
    }

    function testProcessPayment() public {
        template.openMint();
        IFallback(address(template)).doesntExist{value: 1 ether}(420);
        require(template.balanceOf(address(this)) > 0);
    }

    function testTransferFromUnlocked() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.transferFrom(address(this), address(42), 1);
        require(template.ownerOf(1) == address(42));
    }

    function testTransferFromLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        vm.expectRevert(IERC721x.TokenLock.selector);
        template.transferFrom(address(this), address(42), 1);
    }

    function testSafeTransferFromUnlocked() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.safeTransferFrom(address(this), address(42), 1, bytes("milady"));
        require(template.ownerOf(1) == address(42));
    }

    function testSafeTransferFromLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        vm.expectRevert(IERC721x.TokenLock.selector);
        template.safeTransferFrom(address(this), address(42), 1, bytes("milady"));
    }

    function testLockId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        require(!template.isUnlocked(1));
    }

    function testLockIdRevertTokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.lockId(1);
    }

    function testLockIdRevertNotApprovedLocker() public {
        address[] memory approved = new address[](1);
        approved[0] = address(42);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        vm.expectRevert(LockRegistry.NotApprovedLocker.selector);
        template.lockId(1);
    }

    function testLockIdRevertAlreadyLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        vm.expectRevert(LockRegistry.AlreadyLocked.selector);
        template.lockId(1);
    }

    function testUnlockId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        template.unlockId(1);
        require(template.isUnlocked(1));
    }

    function testUnlockIdNotLastLocker() public {
        address[] memory approved = new address[](2);
        approved[0] = address(this);
        approved[1] = address(333);
        bool[] memory status = new bool[](2);
        status[0] = true;
        status[1] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);

        vm.prank(address(333));
        template.lockId(1);

        template.unlockId(1);
        require(!template.isUnlocked(1));
    }

    function testUnlockIdRevertTokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.unlockId(1);
    }

    function testUnlockIdRevertNotApprovedLocker() public {
        address[] memory approved = new address[](1);
        approved[0] = address(42);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        vm.expectRevert(LockRegistry.NotApprovedLocker.selector);
        template.unlockId(1);
    }

    function testUnlockIdRevertTokenNotLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        vm.expectRevert(LockRegistry.TokenNotLocked.selector);
        template.unlockId(1);
    }

    function testFreeId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        status[0] = false;
        template.updateApprovedContracts(approved, status);
        template.freeId(1, address(this));
        require(template.isUnlocked(1));
    }

    function testFreeIdNotLastLocker() public {
        address[] memory approved = new address[](2);
        approved[0] = address(this);
        approved[1] = address(333);
        bool[] memory status = new bool[](2);
        status[0] = true;
        status[1] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);

        vm.prank(address(333));
        template.lockId(1);

        approved = new address[](1);
        approved[0] = address(this);
        status = new bool[](1);
        status[0] = false;
        template.updateApprovedContracts(approved, status);

        template.freeId(1, address(this));
        require(!template.isUnlocked(1));
    }

    function testFreeIdRevertTokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.freeId(1, address(this));
    }

    function testFreeIdRevertLockerStillApproved() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        template.lockId(1);
        vm.expectRevert(LockRegistry.LockerStillApproved.selector);
        template.freeId(1, address(this));
    }

    function testFreeIdRevertTokenNotLocked() public {
        template.openMint();
        template.mint{value: 0.01 ether}(address(this), 1, 2000);
        vm.expectRevert(LockRegistry.TokenNotLocked.selector);
        template.freeId(1, address(this));
    }

    function testUpdateApprovedContractsRevertArrayLengthMismatch() public {
        address[] memory contracts = new address[](2);
        contracts[0] = address(1);
        contracts[1] = address(2);
        bool[] memory values = new bool[](1);
        values[0] = true;

        vm.expectRevert(LockRegistry.ArrayLengthMismatch.selector);
        template.updateApprovedContracts(contracts, values);
    }
}