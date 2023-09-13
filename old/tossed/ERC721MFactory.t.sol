// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import "solady/utils/SSTORE2.sol";
import "../src/IERC721M.sol";
import "../src/ERC721MFactory.sol";

contract FactoryTest is DSTestPlus {

    ERC721MFactory public factory;

    function setUp() public {
        factory = new ERC721MFactory(address(this));
    }

    function getCreationCode() public returns (bytes[] memory) {
        bytes memory _creationCode = hevm.getCode("ERC721M.sol:ERC721M");
        uint256 length = (_creationCode.length + 24576 - 1) / 24576;
        bytes[] memory creationCode = new bytes[](length);
        for (uint256 i; i < length;) {
            uint256 start = i * 24576;
            uint256 end = (start + 24576 > _creationCode.length) ? _creationCode.length : start + 24576;
            bytes memory segment = new bytes(end - start);
            for (uint256 j; j < end - start;) {
                segment[j] = _creationCode[start + j];
                unchecked { ++j; }
            }
            creationCode[i] = segment;
            unchecked { ++i; }
        }
        return creationCode;
    }

    function testWriteCreationCode() public {
        factory.writeCreationCode(getCreationCode());
        bytes[] memory array = getCreationCode();
        bytes memory creationCode;
        for (uint256 i; i < array.length;) {
            creationCode = abi.encodePacked(creationCode, array[i]);
            unchecked { ++i; }
        }
        require(keccak256(abi.encode(creationCode)) == 
            keccak256(abi.encode(factory.getCreationCode())), "creationCode mismatch");
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
    
    function testPostDeployInteractions() public {
        address collection = deployContract();
        require(collection != address(0), "deployment failure");
        require(IERC721M(collection).maxSupply() == 420, "maxSupply read error");
    }
}