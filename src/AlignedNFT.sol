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

    AlignmentVault public immutable vault; // Smart contract wallet for tithe funds
    address public immutable alignedNft; // Aligned NFT collection
    address internal pushRecipient; // Recipient of pushed mint funds
    uint256 public immutable allocation; // 0 - 500, 150 = 15.0%
    uint256 public totalAllocated; // Total amount of ETH allocated
    uint256 public totalTithed; // Total amount of ETH sent to vault
    bool public pushStatus; // Push sends funds to allocation recipient each mint

    constructor(
        uint256 _allocation,
        address _nft,
        address _pushRecipient,
        bool _pushStatus
    ) payable {
        if (_allocation > 500) { revert NotAligned(); } // Require allocation be 50% or less
        allocation = _allocation; // Store it in contract
        emit AllocationSet(_allocation);
        alignedNft = _nft; // Store aligned NFT collection address in contract
        vault = new AlignmentVault(_nft); // Create vault focused on aligned NFT
        emit VaultDeployed(address(vault));
        pushRecipient = _pushRecipient; // Set recipient of allocated funds
        // Toggle sending mint funds to pushRecipient with each mint instead of pooling
        pushStatus = _pushStatus;
    }

    // View AlignmentVault address
    function vaultAddress() public view returns (address) {
        return (address(vault));
    }

    // Change push allocation recipient address
    function _changePushRecipient(address _to) internal {
        if (_to == address(0)) { revert ZeroAddress(); }
        pushRecipient = _to;
    }

    // Toggle push status
    function _setPushStatus(bool _pushStatus) internal {
        pushStatus = _pushStatus;
    }

    // Solady ERC721 _mint override to implement mint funds management
    function _mint(address _to, uint256 _tokenId) internal override {
        // Calculate allocation
        uint256 mintAlloc = FixedPointMathLib.fullMulDiv(allocation, msg.value, 1000);
        // Calculate tithe (remainder)
        uint256 tithe = msg.value - mintAlloc;

        // If in push mode, pay allocation recipient with every mint, else store in contract
        if (pushStatus) {
            (bool pushSuccess, ) = payable(pushRecipient).call{ value: mintAlloc }("");
            if (!pushSuccess) { revert TransferFailed(); }
        }
        // Count allocation
        totalAllocated += mintAlloc;

        // Send tithe to AlignmentVault
        (bool titheSuccess, ) = payable(vault).call{ value: tithe }("");
        if (!titheSuccess) { revert TransferFailed(); }

        // Process ERC721 mint logic
        super._mint(_to, _tokenId);
    }

    // "Pull" withdrawal method to send amount of pooled allocation to an address
    function _withdrawAllocation(address _to, uint256 _amount) internal {
        // Confirm inputs are good
        if (_to == address(0)) { revert ZeroAddress(); }
        if (_amount > address(this).balance) { revert Overdraft(); }

        // Process withdrawal
        (bool success, ) = payable(_to).call{ value: _amount }("");
        if (!success) { revert TransferFailed(); }
    }
}