// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/tokens/ERC721.sol";
import "solady/utils/FixedPointMathLib.sol";
import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "./AlignmentVault.sol";

abstract contract AlignedNFT is ERC721 {

    error NotAligned();
    error TransferFailed();
    error Overdraft();
    error ZeroAddress();

    event VaultDeployed(address indexed vault);
    event AllocationSet(uint256 indexed allocation);

    AlignmentVault public immutable vault;
    address public immutable alignment;
    uint256 public immutable allocation;
    uint256 public pooledAllocation;
    uint256 public titheBalance;
    address internal immutable allocationRecipient;
    bool public pushStatus;

    constructor(
        uint256 _allocation,
        address _nft,
        address _allocationRecipient,
        bool _pushStatus
    ) payable {
        if (_allocation > 500) { revert NotAligned(); }
        allocation = _allocation;
        emit AllocationSet(_allocation);
        alignment = _nft;
        vault = new AlignmentVault(_nft);
        emit VaultDeployed(address(vault));
        allocationRecipient = _allocationRecipient;
        pushStatus = _pushStatus;
    }

    function _mint(address _to, uint256 _tokenId) internal override {
        // Calculate allocation
        uint256 mintAlloc = FixedPointMathLib.fullMulDiv(allocation, msg.value, 1000);
        // Calculate tithe (remainder)
        uint256 tithe = msg.value - mintAlloc;

        // If in push mode, pay allocation recipient with every mint, else pool it for pull withdraw
        if (pushStatus) {
            (bool pushSuccess, ) = payable(allocationRecipient).call{ value: mintAlloc }("");
            if (!pushSuccess) { revert TransferFailed(); }
        } 
        else { pooledAllocation += mintAlloc; }

        // Send tithe to AlignmentVault
        (bool titheSuccess, ) = payable(vault).call{ value: tithe }("");
        if (!titheSuccess) { revert TransferFailed(); }
        titheBalance += tithe;

        // Process ERC721 mint logic
        super._mint(_to, _tokenId);
    }

    function _withdrawAllocation(address _to, uint256 _amount) internal {
        // Confirm inputs are good
        if (_to == address(0)) { revert ZeroAddress(); }
        if (_amount > pooledAllocation) { revert Overdraft(); }

        // Process withdrawal
        (bool success, ) = payable(allocationRecipient).call{ value: _amount }("");
        if (!success) { revert TransferFailed(); }
    }
}