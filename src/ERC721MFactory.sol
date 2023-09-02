// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./ERC721M.sol";
import "solady/utils/SSTORE2.sol";

contract ERC721MFactory {

    error NotDeployed();
    event Deployed(address indexed deployer, address indexed collection);
    event OwnershipChanged(address indexed collection, address indexed owner);

    constructor() payable {}

    struct ConstructorArgs {
        uint16 allocation;
        uint16 royaltyFee;
        address alignedNFT;
        address fundsRecipient;
        address owner;
        string name;
        string symbol;
        string baseURI;
        string contractURI;
        uint256 maxSupply;
        uint256 price;
    }
    mapping(address => ConstructorArgs) public contractArgs;
    mapping(address => address) public contractDeployers;

    address public creationCode;

    modifier onlyCollection(address _collection) {
        if (contractDeployers[_collection] == address(0)) { revert NotDeployed(); }
        _:
    }

    function ownershipUpdate(address _newOwner) external onlyCollection(msg.sender) {
        emit OwnershipChanged(msg.sender, _newOwner);
    }

    function writeCreationCode(bytes memory _creationCode) public {
        creationCode = SSTORE2.write(_creationCode);
    }
    
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
        // Encode creation code and constructor arguments
        bytes memory bytecode = abi.encodePacked(SSTORE2.read(creationCode), abi.encode(
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
        ));

        // Deploy contract
        assembly { addr := create(callvalue(), add(bytecode, 0x20), mload(bytecode)) }
        
        ConstructorArgs memory args;
        args.allocation = _allocation;
        args.royaltyFee = _royaltyFee;
        args.alignedNFT = _alignedNFT;
        args.fundsRecipient = _fundsRecipient;
        args.owner = _owner;
        args.name = __name;
        args.symbol = __symbol;
        args.baseURI = __baseURI;
        args.contractURI = __contractURI;
        args.maxSupply = _maxSupply;
        args.price = _price;
        contractArgs[addr] = args;
        contractDeployers[addr] = msg.sender;
        emit Deployed(msg.sender, addr);
    }
}
