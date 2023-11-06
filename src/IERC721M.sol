// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "./IERC721x.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol";

/**
 * @title IERC721M
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, Email: zodomo@proton.me)
 */
interface IERC721M is IERC721, IERC721x, IERC2981 {
    error Invalid();
    error MintCap();
    error Overdraft();
    error URILocked();
    error NotMinted();
    error NotAligned();
    error MintClosed();
    error Blacklisted();
    error TransferFailed();
    error RoyaltiesDisabled();
    error InsufficientPayment();

    event URILock();
    event PriceUpdate(uint80 indexed price);
    event BlacklistUpdate(address[] indexed blacklist);
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event RoyaltyUpdate(uint256 indexed tokenId, address indexed receiver, uint96 indexed royaltyFee);
    event RoyaltyDisabled();

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function baseURI() external view returns (string memory);
    function contractURI() external view returns (string memory);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function maxSupply() external view returns (uint40);
    function totalSupply() external view returns (uint256);
    function price() external view returns (uint256);

    function vaultFactory() external view returns (address);
    function uriLocked() external view returns (bool);
    function mintOpen() external view returns (bool);
    function alignedNft() external view returns (address);
    function allocation() external view returns (uint16);
    function blacklist(uint256 _index) external view returns (address);

    function setBaseURI(string memory _baseURI) external;
    function lockURI() external;
    function setPrice(uint256 _price) external;
    function setRoyalties(address _recipient, uint96 _royaltyFee) external;
    function setRoyaltiesForId(uint256 _tokenId, address _recipient, uint96 _royaltyFee) external;
    function disableRoyalties() external;
    function setBlacklist(address[] memory _blacklist) external;
    function openMint() external;
    function updateApprovedContracts(address[] calldata _contracts, bool[] calldata _values) external;

    function transferOwnership(address _newOwner) external payable;
    function renounceOwnership(address _newOwner) external payable;

    function mint(address _to, uint256 _amount) external payable;

    function fixInventory(uint256[] memory _tokenIds) external;
    function checkInventory(uint256[] memory _tokenIds) external;
    function alignMaxLiquidity() external;
    function claimYield(address _to) external;
    function rescueERC20(address _asset, address _to) external;
    function rescueERC721(address _asset, address _to, uint256 _tokenId) external;
    function withdrawFunds(address _to, uint256 _amount) external;
}
