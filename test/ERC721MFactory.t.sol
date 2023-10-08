// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/ERC721M.sol";
import "../src/IERC721M.sol";
import "../src/ERC721MFactory.sol";
import "AlignmentVault/AlignmentVault.sol";

contract FactoryTest is DSTestPlus {
    AlignmentVault public vaultImplementation = new AlignmentVault();
    ERC721M public implementation;
    ERC721M public implementation2;
    ERC721MFactory public factory;

    function setUp() public {
        implementation = new ERC721M();
        implementation2 = new ERC721M();
        factory = new ERC721MFactory(address(this), address(implementation));
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
        uint16 allocation = 5000; // 50%
        uint16 royaltyFee = 500; // 5%
        address alignedNFT = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        address owner = address(this);
        string memory name = "ERC721M Test";
        string memory symbol = "ERC721MTEST";
        string memory baseURI = "https://miyamaker.com/api/";
        string memory contractURI = "https://miyamaker.com/api/contract.json";
        uint256 maxSupply = 420;
        uint256 price = 0.01 ether;
        uint256 vaultId = 392;

        factory.preconfigure(name, symbol, baseURI, contractURI, maxSupply, price);
        address deployment = factory.deploy(allocation, royaltyFee, alignedNFT, owner, vaultId);
        require(factory.contractOwners(deployment) == address(this), "deployer mapping error");
        return deployment;
    }

    function deployDeterministicContract() public returns (address) {
        uint16 allocation = 5000; // 50%
        uint16 royaltyFee = 500; // 5%
        address alignedNFT = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        address owner = address(this);
        string memory name = "ERC721M Test";
        string memory symbol = "ERC721MTEST";
        string memory baseURI = "https://miyamaker.com/api/";
        string memory contractURI = "https://miyamaker.com/api/contract.json";
        uint256 maxSupply = 420;
        uint256 price = 0.01 ether;
        uint256 vaultId = 392;
        bytes32 salt = bytes32("42069");

        factory.preconfigure(name, symbol, baseURI, contractURI, maxSupply, price);
        address deployment = factory.deployDeterministic(allocation, royaltyFee, alignedNFT, owner, vaultId, salt);
        require(factory.contractOwners(deployment) == address(this), "deployer mapping error");
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
}
