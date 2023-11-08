// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./ERC721M.sol";
import "../lib/solady/src/utils/LibClone.sol";

interface IERC721MInitialize {
    function initialize(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId // NFTX vault ID
    ) external;
    function disableInitializers() external;
}

/**
 * @title ERC721MFactory
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, Email: zodomo@proton.me)
 */
contract ERC721MFactory is Ownable {
    event Implementation(address indexed implementation);
    event Deployed(address indexed deployer, address indexed collection, address indexed aligned, bytes32 salt);

    address public implementation;
    // Contract address => deployer address
    mapping(address => address) public contractOwners;

    constructor(address _owner, address _implementation) payable {
        _initializeOwner(_owner);
        implementation = _implementation;
        emit Implementation(_implementation);
    }

    // Update implementation address for new clones
    // NOTE: Does not update implementation of prior clones
    function updateImplementation(address _implementation) external virtual onlyOwner {
        if (_implementation == implementation) revert();
        implementation = _implementation;
        emit Implementation(_implementation);
    }

    // Deploy ERC721M collection and fully initialize it
    function deploy(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId // NFTX vault ID
    ) external virtual returns (address deployment) {
        deployment = LibClone.clone(implementation);
        contractOwners[deployment] = msg.sender;
        IERC721MInitialize(deployment).initialize(
            _name,
            _symbol,
            _baseURI,
            _contractURI,
            _maxSupply,
            _royalty,
            _allocation,
            _owner,
            _alignedNft,
            _price,
            _vaultId
        );
        IERC721MInitialize(deployment).disableInitializers();
        emit Deployed(msg.sender, deployment, _alignedNft, 0);
    }

    // Deploy ERC721M collection to deterministic address
    function deployDeterministic(
        string memory _name, // NFT collection name
        string memory _symbol, // NFT collection symbol/ticker
        string memory _baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory _contractURI, // Full Contract URI for NFT collection information
        uint40 _maxSupply, // Max mint supply
        uint16 _royalty, // Percentage of royalty fees in basis points (0 - 10000)
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        address _owner, // Collection owner
        address _alignedNft, // Address of aligned NFT collection mint funds are being dedicated to
        uint80 _price, // Standard mint price
        uint256 _vaultId, // NFTX vault ID
        bytes32 _salt // Used to deterministically deploy to an address of choice
    ) external virtual returns (address deployment) {
        deployment = LibClone.cloneDeterministic(implementation, _salt);
        contractOwners[deployment] = msg.sender;
        IERC721MInitialize(deployment).initialize(
            _name,
            _symbol,
            _baseURI,
            _contractURI,
            _maxSupply,
            _royalty,
            _allocation,
            _owner,
            _alignedNft,
            _price,
            _vaultId
        );
        IERC721MInitialize(deployment).disableInitializers();
        emit Deployed(msg.sender, deployment, _alignedNft, _salt);
    }

    // Return initialization code hash of a clone of the current implementation
    function initCodeHash() external view returns (bytes32 hash) {
        hash = LibClone.initCodeHash(implementation);
    }

    // Predict address of deterministic clone of the current implementation
    function predictDeterministicAddress(bytes32 _salt) external view returns (address predicted) {
        predicted = LibClone.predictDeterministicAddress(implementation, _salt, address(this));
    }
}
