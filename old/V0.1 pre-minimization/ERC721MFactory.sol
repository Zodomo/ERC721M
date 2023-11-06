// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./ERC721M.sol";

// This is a WIP contract
// Author: Zodomo // Zodomo.eth // X: @0xZodomo // T: @zodomo // zodomo@proton.me
// https://github.com/Zodomo/ERC721M
contract ERC721MFactory is Ownable {

    event Deployed(address indexed deployer, address indexed collection);

    constructor(address _owner) payable {
        _initializeOwner(_owner);
    }

    mapping(address => address) public contractDeployers;

    // Deploy MiyaMints flavored ERC721M collection
    function deploy(
        uint16 _allocation, // Percentage in basis points (500 - 10000) of mint funds allocated to aligned collection
        uint16 _royaltyFee, // Percentage in basis points (0 - 10000) for royalty fee
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _fundsRecipient, // Recipient of non-aligned mint funds
        address _owner, // Contract owner, manually specified for clarity
        string memory __name, // NFT collection name
        string memory __symbol, // NFT collection symbol/ticker
        string memory __baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory __contractURI, // Full Contract URI for NFT collection information
        uint256 _maxSupply, // Max mint supply
        uint256 _price // Standard mint price
    ) public returns (address addr) {
        ERC721M deployment = new ERC721M(
            _allocation,
            _royaltyFee,
            _alignedNFT,
            _fundsRecipient,
            _owner,
            __name,
            __symbol,
            __baseURI,
            __contractURI,
            _maxSupply,
            _price
        );
        contractDeployers[address(deployment)] = msg.sender;
        
        emit Deployed(msg.sender, address(deployment));
        return address(deployment);
    }
}