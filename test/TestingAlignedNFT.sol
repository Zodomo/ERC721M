// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "../src/AlignedNFT.sol";
import "solady/utils/LibString.sol";

contract TestingAlignedNFT is AlignedNFT {

    using LibString for uint256;

    constructor(
        uint256 _allocation,
        address _nft,
        address _pushRecipient,
        bool _pushStatus
    ) AlignedNFT(_allocation, _nft, _pushRecipient, _pushStatus) { }

    function name() public pure override returns (string memory) { return ("AlignedNFT Test"); }
    function symbol() public pure override returns (string memory) { return ("ANFTTest"); }
    function tokenURI(uint256 _tokenId) public pure override returns (string memory) { return (_tokenId.toString()); }

    function execute_changePushRecipient(address _to) public { _changePushRecipient(_to); }
    function execute_setPushStatus(bool _pushStatus) public { _setPushStatus(_pushStatus); }

    function execute_mint(address _to, uint256 _tokenId) public payable { _mint(_to, _tokenId); }
    function execute_withdrawAllocation(address _to, uint256 _amount) public { _withdrawAllocation(_to, _amount); }
}