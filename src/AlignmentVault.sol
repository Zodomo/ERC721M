// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "./NFTXIntegration.sol";
import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";


contract AlignmentVault is Ownable, NFTXIntegration {

    error ClaimRewardsFailed();
    error SendRewardsFailed();

    constructor(address _nftAddress) NFTXIntegration(_nftAddress) payable {
        _initializeOwner(msg.sender);
    }

    /* Claim rewards
    // TODO: Reimplement after total refactor
    function claimRewards() public onlyOwner {
        _nftxLPStaking.claimRewards(392);
        if (_nftx_MILADY.balanceOf(address(this)) == 0) { revert ClaimRewardsFailed(); }
        bool success = _nftx_MILADY.transfer(owner(), _nftx_MILADY.balanceOf(address(this)));
        if (!success) { revert SendRewardsFailed(); }
    } */
}