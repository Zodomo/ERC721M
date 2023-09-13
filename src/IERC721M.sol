// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC721.sol";
import "./IERC721x.sol";
import "./IERC2981.sol";

interface IERC721M is IERC721, IERC721x, IERC2981 {

    error URILocked();
    error Underflow();
    error MintClosed();
    error CapReached();
    error LockedAsset();
    error CapExceeded();
    error SpecialExceeded();

    error NotERC721();
    error NotActive();
    error NotMinted();
    error NotLocked();
    error NotUnlocked();
    error NotBurnable();

    error InsufficientLock();
    error InsufficientAssets();
    error InsufficientPayment();
    error InsufficientBalance();

    event URILock();
    event URIChanged(string indexed baseURI);
    event PriceUpdated(uint256 indexed price);
    event TokensLocked(address indexed token, uint256 indexed amount);
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event AssetsUnlocked(address indexed asset, uint256 indexed unlocks, uint256 indexed total);
    
    event NormalMint(address indexed to, uint64 indexed amount);
    event DiscountedMint(address indexed asset, address indexed to, uint64 indexed amount);
    event ConfigureMintDiscount(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint256 tokenBalance,
        uint256 price
    );
    event ConfigureMintBurn(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint256 tokenBalance,
        uint256 price
    );
    event ConfigureMintLock(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint40 timelock,
        uint256 tokenBalance,
        uint256 price
    );
    event ConfigureMintWithAssets(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint256 tokenBalance,
        uint256 price
    );

    struct MintInfo {
        int64 supply;
        int64 allocated;
        bool active;
        uint40 timelock;
        uint256 tokenBalance;
        uint256 mintPrice;
    }
    struct MinterInfo {
        uint256 amount;
        uint256[] amounts;
        uint40[] timelocks;
    }

    function factory() external view returns (address);
    function uriLocked() external view returns (bool);
    function mintOpen() external view returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function baseURI() external view returns (string memory);
    function contractURI() external view returns (string memory);
    function maxSupply() external view returns (uint256);
    function price() external view returns (uint256);
    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function mintDiscountInfo(address _asset) external view returns (MintInfo memory);
    function mintBurnInfo(address _asset) external view returns (MintInfo memory);
    function mintLockInfo(address _asset) external view returns (MintInfo memory);
    function mintWithAssetsInfo(address _asset) external view returns (MintInfo memory);
    function burnerInfo(address _sender, address _asset) external view returns (MinterInfo memory);
    function lockerInfo(address _sender, address _asset) external view returns (MinterInfo memory);

    function changeFundsRecipient(address _recipient) external;
    function setPrice(uint256 _price) external;
    function openMint() external;
    function updateBaseURI(string memory _baseURI) external;
    function lockURI() external;

    function transferOwnership(address _newOwner) external payable;
    function renounceOwnership(address _newOwner) external payable;
    
    function mint(address _to, uint64 _amount) external payable;
    function mintDiscount(address _asset, address _to, uint64 _amount) external payable;
    function configureMintDiscount(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external;
    function mintBurn(address _to, address[] memory _assets, uint256[][] memory _burns) external payable;
    function configureMintBurn(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external;
    function mintLock(address _to, address[] memory _assets, uint256[][] memory _locks) external payable;
    function configureMintLock(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint40[] memory _timelocks,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external;
    function unlockAssets(address _asset) external;
    function mintWithAssets(address _to, address[] memory _assets, uint256[][] memory _tokens) external payable;
    function configureMintWithAssets(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external;

    function wrap(uint256 _amount) external;
    function addInventory(uint256[] calldata _tokenIds) external;
    function addLiquidity(uint256[] calldata _tokenIds) external;
    function deepenLiquidity(uint112 _eth, uint112 _weth, uint112 _nftxInv) external;
    function stakeLiquidity() external;
    function claimRewards(address _recipient) external;
    function compoundRewards(uint112 _eth, uint112 _weth) external;
    function rescueERC20(address _asset, address _to) external;
    function rescueERC721(address _asset, address _to, uint256 _tokenId) external;
    function withdrawFunds(address _to, uint256 _amount) external;

    /////////////////////////////////////////

    error NotAligned();
    error TransferFailed();
    error Overdraft();
    error ZeroAddress();
    error ZeroQuantity();
    error BadInput();
    error RoyaltiesDisabled();
    error BlacklistedCollector();

    event RoyaltyDisabled();
    event VaultDeployed(address indexed vault);
    event AllocationSet(uint256 indexed allocation);
    event BlacklistConfigured(address[] indexed blacklist);

    function alignedNft() external view returns (address);
    function fundsRecipient() external view returns (address);
    function totalAllocated() external view returns (uint256);
    function totalSupply() external view returns (uint32);
    function allocation() external view returns (uint16);
    function blacklistedAssets() external view returns (address[] memory);

    function configureRoyalties(address _recipient, uint96 _royaltyFee) external;
    function configureRoyaltiesForId(uint256 _tokenId, address _recipient, uint96 _feeNumerator) external;
    function disableRoyalties() external;
    
    function configureBlacklist(address[] memory _blacklist) external;
}