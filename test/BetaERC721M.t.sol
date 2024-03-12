// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../lib/forge-std/src/Test.sol";
import "../lib/liquidity-helper/UniswapV2LiquidityHelper.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../lib/solady/test/utils/mocks/MockERC20.sol";
import "../lib/solady/test/utils/mocks/MockERC721.sol";
import "../lib/solady/src/utils/FixedPointMathLib.sol";
import "../src/ERC721M.sol";
import "../src/IERC721M.sol";
import "../lib/AlignmentVault/src/IAlignmentVault.sol";

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

    function _bytesToAddress(bytes32 fuzzedBytes) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode(fuzzedBytes)))));
    }

    function setUp() public {
        template = new ERC721M();
        manualInit = new ERC721M();
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
        template.disableInitializers();
        vm.deal(address(this), 1000 ether);
        testToken = new MockERC20("Test Token", "TEST", 18);
        testToken.mint(address(this), 100 ether);
        testNFT = new MockERC721();
        testNFT.safeMint(address(this), 1);
        testNFT.safeMint(address(this), 2);
        testNFT.safeMint(address(this), 3);
    }

    function testInitialize(
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        uint40 maxSupply,
        uint16 royalty,
        uint16 allocation,
        bytes32 ownerSeed,
        uint80 price,
        bool vaultId
    ) public {
        vm.assume(bytes(name).length > 0 && bytes(symbol).length > 0 && bytes(baseURI).length > 0 && bytes(contractURI).length > 0);
        address owner = _bytesToAddress(ownerSeed);
        uint256 _vaultId;
        if (vaultId) _vaultId = 392;

        if (allocation < 500) {
            vm.expectRevert(IERC721M.NotAligned.selector);
            manualInit.initialize(name, symbol, baseURI, contractURI, maxSupply, royalty, allocation, owner, address(nft), price, _vaultId);
            return;
        }
        else if (allocation > 10000 || royalty > 10000) {
            vm.expectRevert(IERC721M.Invalid.selector);
            manualInit.initialize(name, symbol, baseURI, contractURI, maxSupply, royalty, allocation, owner, address(nft), price, _vaultId);
            return;
        }
        manualInit.initialize(name, symbol, baseURI, contractURI, maxSupply, royalty, allocation, owner, address(nft), price, _vaultId);
        manualInit.disableInitializers();

        assertEq(abi.encode(name), abi.encode(manualInit.name()), "name error");
        assertEq(abi.encode(symbol), abi.encode(manualInit.symbol()), "symbol error");
        assertEq(abi.encode(baseURI), abi.encode(manualInit.baseURI()), "baseURI error");
        assertEq(abi.encode(contractURI), abi.encode(manualInit.contractURI()), "contractURI error");
        assertEq(maxSupply, manualInit.maxSupply(), "maxSupply error");
        (, uint256 _royalty) = manualInit.royaltyInfo(0, 1 ether);
        assertEq(royalty, (_royalty * 10000) / 1 ether, "royalty error");
        assertEq(allocation, manualInit.minAllocation(), "allocation error");
        assertEq(owner, manualInit.owner(), "owner error");
        assertEq(392, IAlignmentVault(manualInit.vault()).vaultId(), "vaultId error");
    }

    function testSupportsInterface(bytes4 interfaceId) public view {
        if (
            interfaceId == type(IERC2981).interfaceId || // ERC2981
            interfaceId == 0x706e8489 || // ERC721x
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f || // ERC721Metadata
            interfaceId == 0x01ffc9a7 // ERC165
        ) assertEq(template.supportsInterface(interfaceId), true, "supportsInterface error");
        else assertEq(template.supportsInterface(interfaceId), false, "supportsInterface error");
    }

    function testMint(bytes32 callerSalt, uint256 amount) public {
        vm.assume(callerSalt != bytes32(""));
        address caller = _bytesToAddress(callerSalt);
        amount = bound(amount, 0, 100);
        vm.deal(caller, (amount * 0.01 ether) + 0.01 ether);
        
        template.openMint();

        vm.prank(caller);
        if (amount == 0) {
            template.mint{value: 0.01 ether}();
            assertEq(template.balanceOf(caller), 1, "balanceOf error");
            assertEq(template.totalSupply(), 1, "totalSupply error");
            assertEq(address(template).balance, 0.008 ether, "template balance error");
            assertEq(wethToken.balanceOf(template.vault()), 0.002 ether, "vault balance error");
        } else {
            template.mint{value: 0.01 ether * amount}(amount);
            assertEq(template.balanceOf(caller), amount, "balanceOf error");
            assertEq(template.totalSupply(), amount, "totalSupply error");
            assertEq(address(template).balance, 0.008 ether * amount, "template balance error");
            assertEq(wethToken.balanceOf(template.vault()), 0.002 ether * amount, "vault balance error");
        }
    }

    function testMint(bytes32 callerSalt, bytes32 recipientSalt, uint256 amount) public {
        vm.assume(callerSalt != bytes32(""));
        vm.assume(recipientSalt != bytes32(""));
        vm.assume(callerSalt != recipientSalt);
        address caller = _bytesToAddress(callerSalt);
        address recipient = _bytesToAddress(recipientSalt);
        amount = bound(amount, 0, 100);
        vm.deal(caller, (amount * 0.01 ether) + 0.01 ether);
        
        template.openMint();

        vm.prank(caller);
        if (amount == 0) {
            template.mint{value: 0.01 ether}(recipient, 1, 2000);
            assertEq(template.balanceOf(recipient), 1, "balanceOf error");
            assertEq(template.totalSupply(), 1, "totalSupply error");
            assertEq(address(template).balance, 0.008 ether, "template balance error");
            assertEq(wethToken.balanceOf(template.vault()), 0.002 ether, "vault balance error");
        } else {
            template.mint{value: 0.01 ether * amount}(recipient, amount, 2000);
            assertEq(template.balanceOf(recipient), amount, "balanceOf error");
            assertEq(template.totalSupply(), amount, "totalSupply error");
            assertEq(address(template).balance, 0.008 ether * amount, "template balance error");
            assertEq(wethToken.balanceOf(template.vault()), 0.002 ether * amount, "vault balance error");
        }
    }

    function testMint(
        bytes32 callerSalt,
        bytes32 referrerSalt,
        bytes32 recipientSalt,
        uint16 referralFee,
        uint256 amount
    ) public {
        vm.assume(callerSalt != referrerSalt && callerSalt != recipientSalt && referrerSalt != recipientSalt);
        vm.assume(callerSalt != bytes32(""));
        vm.assume(referrerSalt != bytes32(""));
        vm.assume(recipientSalt != bytes32(""));
        address caller = _bytesToAddress(callerSalt);
        address referrer = _bytesToAddress(referrerSalt);
        address recipient = _bytesToAddress(recipientSalt);
        referralFee = uint16(bound(referralFee, 1, 8000));
        amount = bound(amount, 1, 100);
        vm.deal(caller, amount * 0.01 ether);

        template.setReferralFee(referralFee);
        template.openMint();
        
        uint256 refFee = FixedPointMathLib.mulDivUp(referralFee * amount, 0.01 ether, 10000);
        vm.prank(caller);
        template.mint{value: 0.01 ether * amount}(recipient, amount, referrer, 2000);
        assertEq(template.balanceOf(recipient), amount, "balanceOf error");
        assertEq(template.totalSupply(), amount, "totalSupply error");
        assertEq(address(referrer).balance, refFee, "referrer balance error");
        assertEq(address(template).balance, (0.008 ether * amount) - refFee, "template balance error");
        assertEq(wethToken.balanceOf(template.vault()), 0.002 ether * amount, "vault balance error");
    }

    function testSetReferralFee(uint16 referralFee, uint16 invalidFee) public {
        referralFee = uint16(bound(referralFee, 1, 8000));
        invalidFee = uint16(bound(invalidFee, 8001, type(uint16).max));

        template.setReferralFee(referralFee);

        assertEq(template.referralFee(), referralFee, "referralFee error");

        vm.expectRevert(IERC721M.Invalid.selector);
        template.setReferralFee(invalidFee);
    }

    function testSetBaseURI(string memory baseURI) public {
        vm.assume(bytes(baseURI).length > 0);

        template.setBaseURI(baseURI);

        assertEq(template.baseURI(), baseURI, "baseURI error");

        template.lockURI();
        vm.expectRevert(IERC721M.URILocked.selector);
        template.setBaseURI(baseURI);
    }

    function testSetContractURI(string memory contractURI) public {
        vm.assume(bytes(contractURI).length > 0);

        template.setContractURI(contractURI);

        assertEq(template.contractURI(), contractURI, "contractURI error");

        template.lockURI();
        vm.expectRevert(IERC721M.URILocked.selector);
        template.setContractURI(contractURI);
    }

    function testLockURI() public {
        template.lockURI();
        assertEq(template.uriLocked(), true, "uriLocked error");
    }

    function testSetPrice(uint80 price) public {
        template.setPrice(price);
        assertEq(template.price(), price, "price error");
    }

    function testSetRoyalties(bytes32 recipientSalt, uint96 royaltyFee, uint96 invalidFee) public {
        vm.assume(recipientSalt != bytes32(""));
        address recipient = _bytesToAddress(recipientSalt);
        royaltyFee = uint96(bound(royaltyFee, 0, 10000));
        invalidFee = uint96(bound(invalidFee, 10001, type(uint96).max));

        template.setRoyalties(recipient, royaltyFee);

        (, uint256 royalty) = template.royaltyInfo(1, 1 ether);
        assertEq(royaltyFee, (royalty * 10000) / 1 ether, "royalty error");

        vm.expectRevert(IERC721M.Invalid.selector);
        template.setRoyalties(recipient, invalidFee);

        template.disableRoyalties();
        vm.expectRevert(IERC721M.RoyaltiesDisabled.selector);
        template.setRoyalties(recipient, royaltyFee);
    }

    function testSetRoyaltiesForId(uint256 tokenId, bytes32 recipientSalt, uint96 royaltyFee, uint96 invalidFee) public {
        tokenId = bound(tokenId, 1, type(uint40).max);
        vm.assume(recipientSalt != bytes32(""));
        address recipient = _bytesToAddress(recipientSalt);
        royaltyFee = uint96(bound(royaltyFee, 1, 10000));
        invalidFee = uint96(bound(invalidFee, 10001, type(uint96).max));

        template.setRoyaltiesForId(tokenId, recipient, royaltyFee);

        (, uint256 royalty) = template.royaltyInfo(tokenId, 1 ether);
        assertEq(royaltyFee, (royalty * 10000) / 1 ether, "royalty error");

        vm.expectRevert(IERC721M.Invalid.selector);
        template.setRoyaltiesForId(tokenId, recipient, invalidFee);
        vm.expectRevert(IERC721M.Invalid.selector);
        template.setRoyaltiesForId(0, recipient, invalidFee);

        template.disableRoyalties();
        vm.expectRevert(IERC721M.RoyaltiesDisabled.selector);
        template.setRoyaltiesForId(tokenId, recipient, royaltyFee);
    }

    function testDisableRoyalties(uint256 tokenId) public {
        tokenId = bound(tokenId, 0, type(uint40).max);
        template.disableRoyalties();
        (address recipient, uint256 royalty) = manualInit.royaltyInfo(tokenId, 1 ether);
        assertEq(recipient, address(0), "royalty recipient error");
        assertEq(royalty, 0, "royalty fee error");
    }

    function testSetBlacklist(address[] memory blacklist) public {
        template.setBlacklist(blacklist);
        address[] memory storedBlacklist = template.getBlacklist();
        assertEq(abi.encode(blacklist), abi.encode(storedBlacklist), "blacklist error");
    }

    function testOpenMint() public {
        template.openMint();
        assertEq(template.mintOpen(), true, "mintOpen error");
    }

    function testIncreaseAlignment(uint16 minAllocation,  uint16 maxAllocation, uint16 invalidMinAllocation, uint16 invalidMaxAllocation) public {
        minAllocation = uint16(bound(minAllocation, 2001, 10000));
        maxAllocation = uint16(bound(maxAllocation, minAllocation, 10000));
        invalidMinAllocation = uint16(bound(invalidMinAllocation, 10001, type(uint16).max));
        invalidMaxAllocation = uint16(bound(invalidMaxAllocation, 10001, type(uint16).max));

        template.increaseAlignment(minAllocation, maxAllocation);
        assertEq(template.minAllocation(), minAllocation, "allocation error");
        assertEq(template.maxAllocation(), maxAllocation, "allocation error");

        vm.expectRevert(IERC721M.Invalid.selector);
        template.increaseAlignment(invalidMinAllocation, maxAllocation);

        vm.expectRevert(IERC721M.Invalid.selector);
        template.increaseAlignment(minAllocation, invalidMaxAllocation);
    }

    function testDecreaseSupply(uint256 amount, uint40 newSupply, uint40 invalidSupply) public {
        amount = bound(amount, 1, 99);
        newSupply = uint40(bound(newSupply, amount, 99));
        invalidSupply = uint40(bound(invalidSupply, newSupply + 1, type(uint40).max));

        template.openMint();
        template.mint{value: 0.01 ether * amount}(amount);
        template.decreaseSupply(newSupply);
        assertEq(template.maxSupply(), newSupply, "newSupply error");

        vm.expectRevert(IERC721M.Invalid.selector);
        template.decreaseSupply(invalidSupply);
    }

    function testUpdateApprovedContracts(address[] memory contracts) public {
        bool[] memory status = new bool[](contracts.length);
        for (uint256 i; i < contracts.length;) {
            status[i] = true;
            unchecked { ++i; }
        }

        template.updateApprovedContracts(contracts, status);
        for (uint256 i; i < contracts.length;) {
            assertEq(template.approvedContract(contracts[i]), true, "approvedContract error");
            unchecked { ++i; }
        }
    }

    function testWithdrawFunds(bytes32 callerSalt, bytes32 recipientSalt, uint256 amount) public {
        vm.assume(callerSalt != recipientSalt);
        vm.assume(callerSalt != bytes32(""));
        vm.assume(recipientSalt != bytes32(""));
        address caller = _bytesToAddress(callerSalt);
        address recipient = _bytesToAddress(recipientSalt);
        amount = bound(amount, 1, 100);
        vm.deal(caller, 0.01 ether * amount);

        template.openMint();

        vm.prank(caller);
        template.mint{value: 0.01 ether * amount}(recipient, amount, 2000);

        vm.expectRevert(IERC721M.Invalid.selector);
        template.withdrawFunds(address(0), type(uint256).max);

        vm.prank(recipient);
        vm.expectRevert(Ownable.Unauthorized.selector);
        template.withdrawFunds(caller, type(uint256).max);

        template.withdrawFunds(recipient, 0.001 ether);
        assertEq(address(recipient).balance, 0.001 ether, "partial recipient balance error");
        template.withdrawFunds(recipient, type(uint256).max);
        assertEq(address(recipient).balance, 0.008 ether * amount, "full recipient balance error");
    }
}