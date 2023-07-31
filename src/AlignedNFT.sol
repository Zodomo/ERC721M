// SPDX-License-Identifier: AGPL-3.0
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
    error ZeroQuantity();
    error BadInput();

    event VaultDeployed(address indexed vault);
    event AllocationSet(uint256 indexed allocation);

    AlignmentVault public immutable vault; // Smart contract wallet for allocated funds
    address public immutable alignedNft; // Aligned NFT collection
    address public fundsRecipient; // Recipient of remaining non-aligned mint funds
    uint256 public totalAllocated; // Total amount of ETH sent to devs
    uint256 public totalTithed; // Total amount of ETH sent to vault 
    uint32 public totalSupply; // Current number of tokens minted
    uint16 public immutable allocation; // Percentage of mint funds to align 500 - 10000, 1500 = 15.00%

    constructor(
        address _nft,
        address _fundsRecipient,
        uint16 _allocation
    ) payable {
        if (_allocation < 500) { revert NotAligned(); } // Require allocation be >= 5%
        if (_allocation > 10000) { revert BadInput(); } // Require allocation be <= 100%
        allocation = _allocation; // Store it in contract
        emit AllocationSet(_allocation);
        alignedNft = _nft; // Store aligned NFT collection address in contract
        vault = new AlignmentVault(_nft); // Create vault focused on aligned NFT
        emit VaultDeployed(address(vault));
        fundsRecipient = _fundsRecipient; // Set recipient of allocated funds
    }

    // View AlignmentVault balance
    function vaultBalance() public view returns (uint256) {
        return (address(vault).balance);
    }

    // Change recipient address for non-aligned mint funds
    function _changeFundsRecipient(address _to) internal {
        if (_to == address(0)) { revert ZeroAddress(); }
        fundsRecipient = _to;
    }

    // Solady ERC721 _mint override to implement mint funds management
    function _mint(address _to, uint256 _amount) internal override {
        // Prevent minting zero NFTs
        if (_amount == 0) { revert ZeroQuantity(); }
        // Calculate allocation
        uint256 mintAlloc = FixedPointMathLib.fullMulDivUp(allocation, msg.value, 10000);
        // Calculate tithe (remainder)
        uint256 tithe = msg.value - mintAlloc;
        // Count allocation
        totalAllocated += mintAlloc;

        // Send tithe to AlignmentVault
        (bool titheSuccess, ) = payable(address(vault)).call{ value: tithe }("");
        // Count tithe
        totalTithed += tithe;
        if (!titheSuccess) { revert TransferFailed(); }

        // Process ERC721 mints
        for (uint256 i; i < _amount;) {
            super._mint(_to, ++totalSupply);
            unchecked { ++i; }
        }
    }

    // Withdraw non-aligned mint funds to recipient
    function _withdrawFunds(address _to, uint256 _amount) internal {
        // Confirm inputs are good
        if (_to == address(0)) { revert ZeroAddress(); }
        if (_amount > address(this).balance && _amount != type(uint256).max) { revert Overdraft(); }
        if (_amount == type(uint256).max) { _amount = address(this).balance; }

        // Process withdrawal
        (bool success, ) = payable(_to).call{ value: _amount }("");
        if (!success) { revert TransferFailed(); }
    }
}