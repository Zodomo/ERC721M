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

}