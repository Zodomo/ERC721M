// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/utils/LibClone.sol";
import "solady/auth/Ownable.sol";

interface IInitialize {
    function initialize(address _erc721, address _owner, uint256 _vaultId) external;
    function disableInitializers() external;
}

// This is a WIP contract
// Author: Zodomo // Zodomo.eth // X: @0xZodomo // T: @zodomo // zodomo@proton.me
// https://github.com/Zodomo/ERC721M
contract AlignmentVaultFactory is Ownable {

    event Deployed(address indexed deployer, address indexed collection);

    address public implementation;
    // Vault address => deployer address
    mapping(address => address) public vaultOwners;

    constructor(address _owner, address _implementation) payable {
        _initializeOwner(_owner);
        implementation = _implementation;
    }

    function updateImplementation(address _implementation) external virtual onlyOwner {
        if (_implementation == implementation) { revert(); }
        implementation = _implementation;
    }

    // Deploy MiyaMints flavored ERC721M collection
    function deploy(address _erc721, uint256 _vaultId) external virtual returns (address deployment) {
        deployment = LibClone.clone(implementation);
        vaultOwners[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        IInitialize(deployment).initialize(_erc721, msg.sender, _vaultId);
        IInitialize(deployment).disableInitializers();
    }

    function deployDeterministic(
        address _erc721,
        uint256 _vaultId,
        bytes32 _salt
    ) external virtual returns (address deployment) {
        deployment = LibClone.cloneDeterministic(implementation, _salt);
        vaultOwners[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        IInitialize(deployment).initialize(_erc721, msg.sender, _vaultId);
        IInitialize(deployment).disableInitializers();
    }
}