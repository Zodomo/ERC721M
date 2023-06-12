// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "./AssetManager.sol";

contract AlignmentVault is AssetManager, Ownable {

    constructor(address _nft) AssetManager(_nft) payable {
        // Initialize contract ownership
        _initializeOwner(msg.sender);
    }

    // Check token balances
    function checkBalanceNFT() public view returns (uint256) { return (_erc721.balanceOf(address(this))); }
    function checkBalanceETH() public view returns (uint256) { return (_checkBalance(IERC20(address(0)))); }
    function checkBalanceWETH() public view returns (uint256) { return (_checkBalance(IERC20(address(_WETH)))); }
    function checkBalanceNFTXInventory() public view returns (uint256) { return (_checkBalance(IERC20(address(_nftxInventory)))); }
    function checkBalanceNFTXLiquidity() public view returns (uint256) { return (_checkBalance(IERC20(address(_nftxLiquidity)))); }

    // Wrap ETH into WETH
    function wrap(uint256 _amount) public onlyOwner { _wrap(_amount); }

    // Add NFTs to NFTX Vault Inventory in exchange for vault/inventory tokens
    function addInventory(uint256[] calldata _tokenIds) public onlyOwner { _addInventory(_tokenIds); }

    // Add NFTs and WETH to NFTX NFTWETH SLP
    function addLiquidity(uint256[] calldata _tokenIds) public onlyOwner { _addLiquidity(_tokenIds); }

    // Add any amount of ETH, WETH, and NFTX Inventory tokens to NFTWETH SLP
    function deepenLiquidity(
        uint112 _eth, 
        uint112 _weth, 
        uint112 _nftxInv
    ) public onlyOwner { _deepenLiquidity(_eth, _weth, _nftxInv); }

    // Stake NFTWETH SLP in NFTX
    function stakeLiquidity() public onlyOwner { _stakeLiquidity(); }

    // Claim NFTWETH SLP rewards
    function claimRewards() public onlyOwner { _claimRewards(); }
}