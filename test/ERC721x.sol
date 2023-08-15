// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import "../src/ERC721M.sol";

contract ERC721MTest is DSTestPlus, ERC721Holder {

    using LibString for uint256;

    ERC721M public template;
    IERC721 public nft = IERC721(0x5Af0D9827E0c53E4799BB226655A1de152A425a5); // Milady NFT

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
    }

    function testTransferFromUnlocked() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
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
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);
        hevm.expectRevert(ERC721x.TokenLock.selector);
        template.transferFrom(address(this), address(42), 1);
    }

    function testSafeTransferFromUnlocked() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
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
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);
        hevm.expectRevert(ERC721x.TokenLock.selector);
        template.safeTransferFrom(address(this), address(42), 1, bytes("milady"));
    }

    function testLockId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);
        require(!template.isUnlocked(1));
    }
    function testLockId_TokenDoesNotExist() public {
        hevm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.lockId(1);
    }
    function testLockId_NotApprovedLocker() public {
        address[] memory approved = new address[](1);
        approved[0] = address(42);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        hevm.expectRevert(LockRegistry.NotApprovedLocker.selector);
        template.lockId(1);
    }
    function testLockId_AlreadyLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);
        hevm.expectRevert(LockRegistry.AlreadyLocked.selector);
        template.lockId(1);
    }

    function testUnlockId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
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
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);

        hevm.prank(address(333));
        template.lockId(1);
        
        template.unlockId(1);
        require(!template.isUnlocked(1));
    }
    function testUnlockId_TokenDoesNotExist() public {
        hevm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.unlockId(1);
    }
    function testUnlockId_NotApprovedLocker() public {
        address[] memory approved = new address[](1);
        approved[0] = address(42);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        hevm.expectRevert(LockRegistry.NotApprovedLocker.selector);
        template.unlockId(1);
    }
    function testUnlockId_TokenNotLocked() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        hevm.expectRevert(LockRegistry.TokenNotLocked.selector);
        template.unlockId(1);
    }

    function testFreeId() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
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
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);

        hevm.prank(address(333));
        template.lockId(1);
        
        approved = new address[](1);
        approved[0] = address(this);
        status = new bool[](1);
        status[0] = false;
        template.updateApprovedContracts(approved, status);
        
        template.freeId(1, address(this));
        require(!template.isUnlocked(1));
    }
    function testFreeId_TokenDoesNotExist() public {
        hevm.expectRevert(ERC721.TokenDoesNotExist.selector);
        template.freeId(1, address(this));
    }
    function testFreeId_LockerStillApproved() public {
        address[] memory approved = new address[](1);
        approved[0] = address(this);
        bool[] memory status = new bool[](1);
        status[0] = true;
        template.updateApprovedContracts(approved, status);

        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        template.lockId(1);
        hevm.expectRevert(LockRegistry.LockerStillApproved.selector);
        template.freeId(1, address(this));
    }
    function testFreeId_TokenNotLocked() public {
        template.openMint();
        template.mint{ value: 0.01 ether }(address(this), 1);
        hevm.expectRevert(LockRegistry.TokenNotLocked.selector);
        template.freeId(1, address(this));
    }

    function testUpdateApprovedContracts_ArrayLengthMismatch() public {
        address[] memory contracts = new address[](2);
        contracts[0] = address(1);
        contracts[1] = address(2);
        bool[] memory values = new bool[](1);
        values[0] = true;

        hevm.expectRevert(LockRegistry.ArrayLengthMismatch.selector);
        template.updateApprovedContracts(contracts, values);
    }
}