// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./ERC721M.sol";
import "solady/utils/LibClone.sol";

interface IInitialize {
    function initialize(
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        uint16 _royaltyFee, // Percentage of royalty fees in basis points (0 - 10000)
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _owner, // Collection owner
        uint256 _vaultId // NFTX vault ID
    ) external;
    function initializeMetadata(
        string memory __name, // NFT collection name
        string memory __symbol, // NFT collection symbol/ticker
        string memory __baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory __contractURI, // Full Contract URI for NFT collection information
        uint256 _maxSupply, // Max mint supply
        uint256 _price // Standard mint price
    ) external;
    function disableInitializers() external;
}

// This is a WIP contract
// Author: Zodomo // Zodomo.eth // X: @0xZodomo // T: @zodomo // zodomo@proton.me
// https://github.com/Zodomo/ERC721M
contract ERC721MFactory is Ownable {

    event Deployed(address indexed deployer, address indexed collection);

    struct Preconfiguration {
        string name;
        string symbol;
        string baseURI;
        string contractURI;
        uint256 maxSupply;
        uint256 price;
    }

    address public implementation;
    mapping(address => Preconfiguration) private _preconfigurations;
    mapping(address => address) public contractDeployers;

    constructor(address _owner, address _implementation) payable {
        _initializeOwner(_owner);
        implementation = _implementation;
    }

    function preconfigure(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint256 _maxSupply, // Max mint supply
        uint256 _price // Standard mint price
    ) public {
        Preconfiguration memory preconf;
        preconf.name = _name;
        preconf.symbol = _symbol;
        preconf.baseURI = _baseURI;
        preconf.contractURI = _contractURI;
        preconf.maxSupply = _maxSupply;
        preconf.price = _price;
        _preconfigurations[msg.sender] = preconf;
    }

    // Deploy MiyaMints flavored ERC721M collection
    function deploy(
        uint16 _allocation, // Percentage in basis points (500 - 10000) of mint funds allocated to aligned collection
        uint16 _royaltyFee, // Percentage in basis points (0 - 10000) for royalty fee
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _owner, // Contract owner, manually specified for clarity
        uint256 _vaultId // NFTX vault ID
    ) public returns (address deployment) {
        deployment = LibClone.clone(implementation);
        contractDeployers[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        Preconfiguration memory preconf = _preconfigurations[msg.sender];
        IInitialize(deployment).initialize(_allocation, _royaltyFee, _alignedNFT, _owner, _vaultId);
        IInitialize(deployment).initializeMetadata(preconf.name, preconf.symbol, preconf.baseURI, preconf.contractURI, preconf.maxSupply, preconf.price);
        IInitialize(deployment).disableInitializers();
    }

    function deployDeterministic(
        uint16 _allocation, // Percentage in basis points (500 - 10000) of mint funds allocated to aligned collection
        uint16 _royaltyFee, // Percentage in basis points (0 - 10000) for royalty fee
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _owner, // Contract owner, manually specified for clarity
        uint256 _vaultId, // NFTX vault ID
        bytes32 _salt // Used to deterministically deploy to an address of choice
    ) public returns (address deployment) {
        deployment = LibClone.cloneDeterministic(implementation, _salt);
        contractDeployers[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        Preconfiguration memory preconf = _preconfigurations[msg.sender];
        IInitialize(deployment).initialize(_allocation, _royaltyFee, _alignedNFT, _owner, _vaultId);
        IInitialize(deployment).initializeMetadata(preconf.name, preconf.symbol, preconf.baseURI, preconf.contractURI, preconf.maxSupply, preconf.price);
        IInitialize(deployment).disableInitializers();
    }
}