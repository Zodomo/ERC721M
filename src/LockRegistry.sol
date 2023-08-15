// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "./IERC721x.sol";

// Sourced from / inspired by https://github.com/OwlOfMoistness/ERC721x/blob/master/contracts/LockRegistry.sol

abstract contract LockRegistry is Ownable, IERC721x {

	error ArrayLengthMismatch();
	error LockerStillApproved();
	error NotApprovedLocker();
	error TokenNotLocked();
	error AlreadyLocked();

	event TokenLocked(uint256 indexed tokenId, address indexed approvedContract);
	event TokenUnlocked(uint256 indexed tokenId, address indexed approvedContract);

    mapping(address => bool) public override approvedContract;
	mapping(uint256 => uint256) public override lockCount;
	mapping(uint256 => mapping(uint256 => address)) public override lockMap;
	mapping(uint256 => mapping(address => uint256)) public override lockMapIndex;

	function isUnlocked(uint256 _id) public view override returns(bool) {
		return lockCount[_id] == 0;
	}

	function updateApprovedContracts(address[] calldata _contracts, bool[] calldata _values) external onlyOwner {
		if (_contracts.length != _values.length) { revert ArrayLengthMismatch(); }
		for (uint256 i = 0; i < _contracts.length;) {
			approvedContract[_contracts[i]] = _values[i];
			unchecked {
				++i;
			}
		}
	}

	function _lockId(uint256 _id) internal {
		if (!approvedContract[msg.sender]) { revert NotApprovedLocker(); }
		if (lockMapIndex[_id][msg.sender] != 0) { revert AlreadyLocked(); }

		unchecked {
			uint256 count = lockCount[_id] + 1;
			lockMap[_id][count] = msg.sender;
			lockMapIndex[_id][msg.sender] = count;
			lockCount[_id] = count;
		}
		
		emit TokenLocked(_id, msg.sender);
	}

	function _unlockId(uint256 _id) internal {
		if (!approvedContract[msg.sender]) { revert NotApprovedLocker(); }
		uint256 index = lockMapIndex[_id][msg.sender];
		if (index == 0) { revert TokenNotLocked(); }
		
		uint256 last = lockCount[_id];
		if (index != last) {
			address lastContract = lockMap[_id][last];
			lockMap[_id][index] = lastContract;
			lockMap[_id][last] = address(0);
			lockMapIndex[_id][lastContract] = index;
		} else {
			lockMap[_id][index] = address(0);
		}

		lockMapIndex[_id][msg.sender] = 0;
		unchecked {
			lockCount[_id]--;
		}
		
		emit TokenUnlocked(_id, msg.sender);
	}

	function _freeId(uint256 _id, address _contract) internal {
		if (approvedContract[msg.sender]) { revert LockerStillApproved(); }
		uint256 index = lockMapIndex[_id][_contract];
		if (index == 0) { revert TokenNotLocked(); }

		uint256 last = lockCount[_id];
		if (index != last) {
			address lastContract = lockMap[_id][last];
			lockMap[_id][index] = lastContract;
			lockMap[_id][last] = address(0);
			lockMapIndex[_id][lastContract] = index;
		}
		else {
			lockMap[_id][index] = address(0);
		}

		lockMapIndex[_id][_contract] = 0;
		unchecked {
			lockCount[_id]--;
		}
		emit TokenUnlocked(_id, _contract);
	}
}