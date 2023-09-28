// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/AlignmentVault.sol";
import "../src/AlignmentVaultFactory.sol";

contract FactoryTest is DSTestPlus {
    AlignmentVault public implementation;
    AlignmentVault public implementation2;
    AlignmentVaultFactory public factory;

    function setUp() public {
        implementation = new AlignmentVault();
        implementation2 = new AlignmentVault();
        factory = new AlignmentVaultFactory(address(this), address(implementation));
    }

    function testUpdateImplementation() public {
        factory.updateImplementation(address(implementation2));
        require(factory.implementation() == address(implementation2));
    }

    function testUpdateImplementationNoChange() public {
        hevm.expectRevert(bytes(""));
        factory.updateImplementation(address(implementation));
    }

    function deployContract() public returns (address) {
        address erc721 = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        uint256 vaultId = 392;

        address deployment = factory.deploy(erc721, vaultId);
        return deployment;
    }

    function deployDeterministicContract() public returns (address) {
        address erc721 = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        uint256 vaultId = 392;
        bytes32 salt = bytes32("42069");

        address deployment = factory.deployDeterministic(erc721, vaultId, salt);
        return deployment;
    }

    function testDeploy() public {
        address collection = deployContract();
        require(collection != address(0), "deployment failure");
    }

    function testDeployDeterministic() public {
        address collection = deployDeterministicContract();
        require(collection != address(0), "deployment failure");
    }

    function testMultipleDeployments() public {
        address deploy0 = deployContract();
        address deploy1 = deployContract();
        address deploy2 = deployContract();
        address deploy3 = deployContract();
        require(deploy0 != deploy1);
        require(deploy1 != deploy2);
        require(deploy2 != deploy3);
        require(deploy3 != deploy0);
    }

    function testInitCodeHash() public view {
        require(factory.initCodeHash() != bytes32(0));
    }

    function testPredictDeterministicAddress(bytes32 _salt) public {
        address erc721 = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        address predicted = factory.predictDeterministicAddress(_salt);
        address deployed = factory.deployDeterministic(erc721, 392, _salt);
        require(predicted == deployed);
    }
}
