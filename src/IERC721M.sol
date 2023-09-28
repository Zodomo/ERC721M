// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC721.sol";
import "./IERC721x.sol";
import "./IERC2981.sol";

/**
 * @title IERC721M
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, Email: zodomo@proton.me)
 */
interface IERC721M is IERC721, IERC721x, IERC2981 {

    error BadInput();
    error NotActive();
    error NotMinted();
    error URILocked();
    error Underflow();
    error Overdraft();
    error NotAligned();
    error MintClosed();
    error CapReached();
    error CapExceeded();
    error UnwantedNFT();
    error Blacklisted();
    error ZeroAddress();
    error ZeroQuantity();
    error TransferFailed();
    error SpecialExceeded();
    error RoyaltiesDisabled();
    error InsufficientPayment();
    error InsufficientBalance();

    event URILock();
    event RoyaltyDisabled();
    event URIChanged(string indexed baseURI);
    event BlacklistConfigured(address[] indexed blacklist);
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    
    event NormalMint(address indexed to, uint64 indexed amount);
    event DiscountedMint(address indexed asset, address indexed to, uint64 indexed amount);
    event ConfigureMintDiscount(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint64 userMax,
        uint256 tokenBalance,
        uint256 price
    );

    struct MintInfo {
        bool active; // Mint discount status
        int64 supply; // Count of remaining discounted mints
        int64 allocated; // Total count of discounted mints issued for specific asset
        uint64 userMax; // Total count of discounted mints per user address
        uint256 mintPrice; // Mint rate for asset discount
        uint256 tokenBalance; // Required token balance to qualify for mint
    }

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function baseURI() external view returns (string memory);
    function contractURI() external view returns (string memory);
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function maxSupply() external view returns (uint256);
    function totalSupply() external view returns (uint32);
    function price() external view returns (uint256);

    function vaultFactory() external view returns (address);
    function uriLocked() external view returns (bool);
    function mintOpen() external view returns (bool);
    function alignedNft() external view returns (address);
    function fundsRecipient() external view returns (address);
    function allocation() external view returns (uint16);
    function totalAllocated() external view returns (uint256);
    function blacklistedAssets() external view returns (address[] memory);
    function mintDiscountInfo(address _asset) external view returns (MintInfo memory);
    function minterDiscountCount(address _sender, address _asset) external view returns (uint64);

    function changeFundsRecipient(address _recipient) external;
    function setPrice(uint256 _price) external;
    function openMint() external;
    function updateBaseURI(string memory _baseURI) external;
    function lockURI() external;
    function configureBlacklist(address[] memory _blacklist) external;

    function transferOwnership(address _newOwner) external payable;
    function renounceOwnership(address _newOwner) external payable;
    function configureRoyalties(address _recipient, uint96 _royaltyFee) external;
    function configureRoyaltiesForId(uint256 _tokenId, address _recipient, uint96 _feeNumerator) external;
    function disableRoyalties() external;
    
    function mint(address _to, uint64 _amount) external payable;
    function mintDiscount(address _asset, address _to, uint64 _amount) external payable;
    function configureMintDiscount(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint64[] memory _userMax,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external;

    function fixInventory(uint256[] memory _tokenIds) external;
    function checkInventory(uint256[] memory _tokenIds) external;
    function alignLiquidity() external;
    function claimYield(address _to) external;
    function rescueERC20(address _asset, address _to) external;
    function rescueERC721(address _asset, address _to, uint256 _tokenId) external;
    function withdrawFunds(address _to, uint256 _amount) external;
}