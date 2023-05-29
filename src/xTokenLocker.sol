// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "openzeppelin/interfaces/IERC20.sol";

interface INFTXLPStaking {
    function deposit(uint256 vaultId, uint256 amount) external;
    function claimRewards(uint256 vaultId) external;
}

contract xTokenLocker is Ownable {

    error ClaimRewardsFailed();
    error SendRewardsFailed();

    IERC20 constant internal _nftx_MILADY = IERC20(0x227c7DF69D3ed1ae7574A1a7685fDEd90292EB48);
    INFTXLPStaking internal _nftxLPStaking = INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);

    constructor() payable {
        _initializeOwner(msg.sender);
    }

    // Change NFTX LP staking contract address
    function changeNFTXLPStakingContract(address _address) public onlyOwner {
        _nftxLPStaking = INFTXLPStaking(_address);
    }

    // Claim rewards
    function claimRewards() public onlyOwner {
        _nftxLPStaking.claimRewards(392);
        if (_nftx_MILADY.balanceOf(address(this)) == 0) { revert ClaimRewardsFailed(); }
        bool success = _nftx_MILADY.transfer(owner(), _nftx_MILADY.balanceOf(address(this)));
        if (!success) { revert SendRewardsFailed(); }
    }
}