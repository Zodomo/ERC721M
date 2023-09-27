// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "../src/IERC721M.sol";
import "../src/ERC721MFactory.sol";

contract FactoryTest is DSTestPlus {
/*
    ERC721MFactory public factory;

    function setUp() public {
        factory = new ERC721MFactory(address(this));
    }

    function deployContract() public returns (address) {
        uint16 allocation = 5000; // 50%
        uint16 royaltyFee = 500; // 5%
        address alignedNFT = 0x5Af0D9827E0c53E4799BB226655A1de152A425a5; // Milady Maker
        address fundsRecipient = address(this);
        address owner = address(this);
        string memory name = "ERC721M Test";
        string memory symbol = "ERC721MTEST";
        string memory baseURI = "https://miyamaker.com/api/";
        string memory contractURI = "https://miyamaker.com/api/contract.json";
        uint256 maxSupply = 420;
        uint256 price = 0.01 ether;
        address collection = factory.deploy(
            allocation, 
            royaltyFee, 
            alignedNFT, 
            fundsRecipient, 
            owner, 
            name, 
            symbol, 
            baseURI, 
            contractURI, 
            maxSupply, 
            price
        );
        require(factory.contractDeployers(collection) == address(this), "deployer mapping error");
        return collection;
    }

    function testDeploy() public {
        address collection = deployContract();
        require(collection != address(0), "deployment failure");
    }
    function testFailDeploy_BadAddress() public {
        uint16 allocation = 5000; // 50%
        uint16 royaltyFee = 500; // 5%
        address alignedNFT = 0x5af0D9826E0C53E4799BB226655a1dE152a425a5; // Bad Address
        address fundsRecipient = address(this);
        address owner = address(this);
        string memory name = "ERC721M Test";
        string memory symbol = "ERC721MTEST";
        string memory baseURI = "https://miyamaker.com/api/";
        string memory contractURI = "https://miyamaker.com/api/contract.json";
        uint256 maxSupply = 420;
        uint256 price = 0.01 ether;
        address collection = factory.deploy(
            allocation, 
            royaltyFee, 
            alignedNFT, 
            fundsRecipient, 
            owner, 
            name, 
            symbol, 
            baseURI, 
            contractURI, 
            maxSupply, 
            price
        );
        require(collection == address(0), "deployment went through in error");
    }
    
    function testPostDeployInteractions() public {
        address collection = deployContract();
        require(collection != address(0), "deployment failure");
        require(IERC721M(collection).maxSupply() == 420, "maxSupply read error");
    }*/
}