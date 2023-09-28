// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/utils/LibClone.sol";
import "solady/auth/Ownable.sol";

interface IInitialize {
    function initialize(address _erc721, address _owner, uint256 _vaultId) external;
    function disableInitializers() external;
}

/**
 * @title AlignmentVaultFactory
 * @notice This can be used by any EOA or contract to deploy an AlignmentVault owned by the deployer.
 * @dev deploy() will perform a normal deployment. deployDeterministic() allows you to mine a deployment address.
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, GitHub: Zodomo, Email: zodomo@proton.me)
 */
contract AlignmentVaultFactory is Ownable {
    event Deployed(address indexed deployer, address indexed collection);

    address public implementation;
    // Vault address => deployer address
    mapping(address => address) public vaultDeployers;

    constructor(address _owner, address _implementation) payable {
        _initializeOwner(_owner);
        implementation = _implementation;
    }

    // Update implementation address for new clones
    // NOTE: Does not update implementation of prior clones
    function updateImplementation(address _implementation) external virtual onlyOwner {
        if (_implementation == implementation) revert();
        implementation = _implementation;
    }

    // Deploy AlignmentVault and fully initialize it
    function deploy(address _erc721, uint256 _vaultId) external virtual returns (address deployment) {
        deployment = LibClone.clone(implementation);
        vaultDeployers[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        IInitialize(deployment).initialize(_erc721, msg.sender, _vaultId);
        IInitialize(deployment).disableInitializers();
    }

    // Deploy AlignmentVault to deterministic address
    function deployDeterministic(address _erc721, uint256 _vaultId, bytes32 _salt)
        external
        virtual
        returns (address deployment)
    {
        deployment = LibClone.cloneDeterministic(implementation, _salt);
        vaultDeployers[deployment] = msg.sender;
        emit Deployed(msg.sender, deployment);

        IInitialize(deployment).initialize(_erc721, msg.sender, _vaultId);
        IInitialize(deployment).disableInitializers();
    }

    /// @dev Returns the initialization code hash of the clone of `implementation`.
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash() external view returns (bytes32) {
        return LibClone.initCodeHash(implementation);
    }

    /// @dev Returns the address of the deterministic clone with `salt`
    function predictDeterministicAddress(bytes32 _salt) external view returns (address) {
        return LibClone.predictDeterministicAddress(implementation, _salt, address(this));
    }
}
