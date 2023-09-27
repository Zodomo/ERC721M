// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "manual-library/ProjectLibrary.sol";
import "./IAlignmentVault.sol";
import "./ERC721x.sol";
import "./ERC2981.sol";

interface IAsset {
    function burn(uint256 tokens) external;
    function balanceOf(address holder) external returns (uint256);
    function approve(address spender, uint256 tokens) external returns (bool);
    function transferFrom(address from, address to, uint256 tokens) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IFactory {
    function deploy(address _erc721, uint256 _vaultId) external returns (address);
}

abstract contract AlignedNFT is ERC721x, ERC2981, Initializable {

    error BadInput();
    error Overdraft();
    error Blacklisted();
    error ZeroAddress();
    error ZeroQuantity();
    error TransferFailed();
    error RoyaltiesDisabled();

    event RoyaltyDisabled();
    event VaultDeployed(address indexed vault);
    event AllocationSet(uint256 indexed allocation);
    event BlacklistConfigured(address[] indexed blacklist);

    address public constant vaultFactory = address(7777777);
    IAlignmentVault public vault; // Smart contract wallet for allocated funds
    address public alignedNft; // Aligned NFT collection
    address public fundsRecipient; // Recipient of remaining non-aligned mint funds
    uint256 public totalAllocated; // Total amount of ETH allocated to aligned collection
    uint32 public totalSupply; // Current number of tokens minted
    uint16 public allocation; // Percentage of mint funds to align 500 - 10000, 1500 = 15.00%
    address[] public blacklistedAssets; // Tokens and NFTs that are blacklisted

    // ERC165 override to include ERC2981
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721x) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    // Configure royalty receiver and royalty fee
    function configureRoyalties(address _recipient, uint96 _royaltyFee) public onlyOwner {
        // Revert if royalties are disabled
        (address receiver, ) = royaltyInfo(0, 0);
        if (receiver == address(0)) { revert RoyaltiesDisabled(); }

        _setDefaultRoyalty(_recipient, _royaltyFee);
        _setTokenRoyalty(0, receiver, _royaltyFee);
        // Event is emitted in _setDefaultRoyalty()
    }

    // Configure royalty receiver and royalty fee for a specific tokenId
    function configureRoyaltiesForId(
        uint256 _tokenId,
        address _recipient,
        uint96 _feeNumerator
    ) public onlyOwner {
        // Revert if royalties are disabled
        (address receiver, ) = royaltyInfo(0, 0);
        if (receiver == address(0)) { revert RoyaltiesDisabled(); }
        // Revert if resetting tokenId 0 as it is treated as royalties enablement status
        if (_tokenId == 0) { revert BadInput(); }
        
        // Reset token royalty if fee is 0, else set it
        if (_feeNumerator == 0) { _resetTokenRoyalty(_tokenId); }
        else { _setTokenRoyalty(_tokenId, _recipient, _feeNumerator); }
        // Event is emitted in _setDefaultRoyalty()
    }

    // Irreversibly isable royalties by resetting tokenId 0 royalty to (address(0), 0)
    function disableRoyalties() public onlyOwner {
        _deleteDefaultRoyalty();
        _resetTokenRoyalty(0);
        emit RoyaltyDisabled();
    }

    // Configure which assets are blacklisted
    // No differentiation needed between coins and NFTs as a generalized balanceOf interface is utilized
    function configureBlacklist(address[] memory blacklist) public onlyOwner {
        blacklistedAssets = blacklist;
        emit BlacklistConfigured(blacklist);
    }

    // Blacklist function to prevent mints to holders of prohibited collections
    function _enforceBlacklist(address _minter, address _recipient) internal {
        address[] memory blacklist = blacklistedAssets;
        uint256 count;
        for (uint256 i; i < blacklist.length;) {
            unchecked {
                count += IAsset(blacklist[i]).balanceOf(_minter);
                count += IAsset(blacklist[i]).balanceOf(_recipient);
                ++i;
            }
        }
        if (count > 0) { revert Blacklisted(); }
    }

    // Change recipient address for non-aligned mint funds
    function _changeFundsRecipient(address _to) internal {
        if (_to == address(0)) { revert ZeroAddress(); }
        fundsRecipient = _to;
    }

    // Solady ERC721 _mint override to implement mint funds management
    function _mint(address _to, uint256 _amount) internal override {
        // Ensure minter and recipient don't hold blacklisted collections
        _enforceBlacklist(msg.sender, _to);
        // Prevent minting zero NFTs
        if (_amount == 0) { revert ZeroQuantity(); }
        // Calculate allocation
        uint256 mintAlloc = FixedPointMathLib.fullMulDivUp(allocation, msg.value, 10000);
        // Count allocation
        totalAllocated += mintAlloc;

        // Send tithe to AlignmentVault
        payable(address(vault)).call{ value: mintAlloc }("");

        // Process ERC721 mints
        // totalSupply is read once externally from loop to reduce SLOADs to save gas
        uint256 supply = totalSupply;
        for (uint256 i; i < _amount;) {
            super._mint(_to, ++supply);
            unchecked { ++i; }
        }
        totalSupply += uint32(_amount);
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