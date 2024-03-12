// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.23;

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

    // >>>>>>>>>>>> [ EVENTS ] <<<<<<<<<<<<

    event URILock();
    event MintOpen();
    event Withdraw(address indexed to, uint256 indexed amount);
    event PriceUpdate(uint80 indexed price);
    event SupplyUpdate(uint40 indexed supply);
    event AlignmentUpdate(uint16 indexed minAllocation, uint16 indexed maxAllocation);
    event BlacklistUpdate(address[] indexed blacklist);
    event ReferralFeePaid(address indexed referral, uint256 indexed amount);
    event ReferralFeeUpdate(uint16 indexed referralFee);
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
    function minAllocation() external view returns (uint16);
    function maxAllocation() external view returns (uint16);
    function blacklist(uint256 _index) external view returns (address);

    function setReferralFee(uint16 _referralFee) external;
    function setBaseURI(string memory _baseURI) external;
    function lockURI() external;
    function setPrice(uint256 _price) external;
    function setRoyalties(address _recipient, uint96 _royaltyFee) external;
    function setRoyaltiesForId(uint256 _tokenId, address _recipient, uint96 _royaltyFee) external;
    function disableRoyalties() external;
    function setBlacklist(address[] memory _blacklist) external;
    function openMint() external;
    function increaseAlignment(uint16 _minAllocation, uint16 _maxAllocation) external;
    function decreaseSupply(uint40 _maxSupply) external;
    function updateApprovedContracts(address[] calldata _contracts, bool[] calldata _values) external;

    function transferOwnership(address _newOwner) external;
    function renounceOwnership(address _newOwner) external;

    function mint(address _to, uint256 _amount) external payable;
    function mint(address _to, uint256 _amount, address _referral) external payable;
    function mint(address _to, uint256 _amount, uint16 _allocation) external payable;
    function mint(address _to, uint256 _amount, address _referral, uint16 _allocation) external payable;

    function fixInventory(uint256[] memory _tokenIds) external payable;
    function checkInventory(uint256[] memory _tokenIds) external payable;
    function alignNfts(uint256[] memory _tokenIds) external payable;
    function alignTokens(uint256 _amount) external payable;
    function alignMaxLiquidity() external payable;
    function claimYield(address _to) external payable;
    function rescueERC20(address _asset, address _to) external;
    function rescueERC721(address _asset, address _to, uint256 _tokenId) external;
    function withdrawFunds(address _to, uint256 _amount) external;
}
