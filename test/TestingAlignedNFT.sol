// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../src/AlignedNFT.sol";
import "../src/AlignmentVault.sol";

contract TestingAlignedNFT is AlignedNFT {

    using LibString for uint256;

    constructor(
        address _nft,
        address _fundsRecipient,
        uint16 _allocation
    ) { 
        _initializeOwner(msg.sender);
        alignedNft = _nft;
        fundsRecipient = _fundsRecipient;
        allocation = _allocation;
        vault = IAlignmentVault(address(new AlignmentVault()));
        vault.initialize(_nft, msg.sender, 0);
    }

    function name() public pure override returns (string memory) { return ("AlignedNFT Test"); }
    function symbol() public pure override returns (string memory) { return ("ANFTTest"); }
    function tokenURI(uint256 _tokenId) public pure override returns (string memory) { return (_tokenId.toString()); }

    function execute_changeFundsRecipient(address _to) public { _changeFundsRecipient(_to); }

    function execute_mint(address _to, uint256 _amount) public payable { _mint(_to, _amount); }
    function execute_withdrawFunds(address _to, uint256 _amount) public { _withdrawFunds(_to, _amount); }

    function execute_setTokenRoyalty() public { _setTokenRoyalty(0, msg.sender, 420); }
}