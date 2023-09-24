// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./AlignedNFT.sol";

// This is a WIP contract
// Author: Zodomo // Zodomo.eth // X: @0xZodomo // T: @zodomo // zodomo@proton.me
// https://github.com/Zodomo/ERC721M
contract ERC721M is AlignedNFT {

    using LibString for uint256;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

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

    bool public uriLocked;
    bool public mintOpen;
    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    uint256 public immutable maxSupply;
    uint256 public price;

    mapping(address => MintInfo) public mintDiscountInfo;
    mapping(address => MintInfo) public mintBurnInfo;
    mapping(address => MintInfo) public mintLockInfo;
    mapping(address => MintInfo) public mintWithAssetsInfo;
    mapping(address => mapping(address => MinterInfo)) public burnerInfo;
    mapping(address => mapping(address => MinterInfo)) public lockerInfo;

    modifier mintable(uint256 _amount) {
        if (!mintOpen) { revert MintClosed(); }
        if (totalSupply >= maxSupply) { revert CapReached(); }
        if (totalSupply + _amount > maxSupply) { revert CapExceeded(); }
        _;
    }

    constructor(
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        uint16 _royaltyFee, // Percentage of royalty fees in basis points (0 - 10000)
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _fundsRecipient, // Recipient of non-aligned mint funds
        address _owner, // Collection owner
        string memory __name, // NFT collection name
        string memory __symbol, // NFT collection symbol/ticker
        string memory __baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory __contractURI, // Full Contract URI for NFT collection information
        uint256 _maxSupply, // Max mint supply
        uint256 _price // Standard mint price
    ) AlignedNFT(
        _alignedNFT,
        _fundsRecipient,
        _allocation
    )
    payable {
        // Prevent bad royalty fee
        if (_royaltyFee > 10000) { revert BadInput(); }
        // Set all relevant metadata and contract configurations
        _name = __name;
        _symbol = __symbol;
        _baseURI = __baseURI;
        _contractURI = __contractURI;
        maxSupply = _maxSupply;
        price = _price;

        _initializeOwner(_owner);
        // Initialize royalties
        _setTokenRoyalty(0, _fundsRecipient, uint96(_royaltyFee));
        // Configure default royalties for contract owner
        _setDefaultRoyalty(_fundsRecipient, uint96(_royaltyFee));
    }


    // ERC721 Metadata
    function name() public view virtual override returns (string memory) { return (_name); }
    function symbol() public view virtual override returns (string memory) { return (_symbol); }
    function baseURI() public view virtual returns (string memory) { return (_baseURI); }
    function contractURI() public view virtual returns (string memory) { return (_contractURI); }
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) { revert NotMinted(); } // Require token exists
        string memory __baseURI = baseURI();

        return (bytes(__baseURI).length > 0 ? string(abi.encodePacked(__baseURI, _tokenId.toString())) : "");
    }

    // Contract management
    function changeFundsRecipient(address _to) public virtual onlyOwner { _changeFundsRecipient(_to); }
    function setPrice(uint256 _price) public virtual onlyOwner {
        price = _price;
        emit PriceUpdated(_price);
    }
    function openMint() public virtual onlyOwner { mintOpen = true; }
    function updateBaseURI(string memory __baseURI) public virtual onlyOwner {
        if (!uriLocked) {
            _baseURI = __baseURI;
            emit URIChanged(__baseURI);
            emit BatchMetadataUpdate(0, maxSupply);
        } else { revert URILocked(); }
    }
    function lockURI() public virtual onlyOwner {
        uriLocked = true;
        emit URILock();
    }

    // Standard mint function that supports batch minting
    function mint(address _to, uint64 _amount) public payable mintable(_amount) {
        if (msg.value < (price * _amount)) { revert InsufficientPayment(); }
        _mint(_to, uint256(_amount));
        emit NormalMint(_to, _amount);
    }

    // Discounted mint for owners of specific ERC20/721 tokens
    function mintDiscount(address _asset, address _to, uint64 _amount) public payable mintable(_amount) {
        MintInfo memory info = mintDiscountInfo[_asset];
        // Check if discount is active
        if (!info.active || info.supply == 0) { revert NotActive(); }
        // Determine if amount exceeds supply
        int64 amount = (uint256(_amount).toInt256()).toInt64();
        if (amount > info.supply) { revert SpecialExceeded(); }
        // Ensure holder balance of asset is sufficient
        if (IAsset(_asset).balanceOf(msg.sender) < info.tokenBalance) { revert InsufficientBalance(); }
        if (_amount * info.mintPrice > msg.value) { revert InsufficientPayment(); }
        // Update MintInfo
        unchecked { info.supply -= amount; }
        if (info.supply == 0) { info.active = false; }
        mintDiscountInfo[_asset] = info;
        // Process mint
        _mint(_to, uint256(_amount));
        emit DiscountedMint(_asset, _to, _amount);
    }

    // Configure asset ownership-based discounted mints, bulk compatible
    // Each individual collection must have a corresponding discount price and total discounted mint quantity
    function configureMintDiscount(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) public virtual onlyOwner {
        // Confirm all arrays match in length to ensure each collection has proper values set
        uint256 length = _assets.length;
        if (
            length != _status.length
            || length != _allocations.length
            || length != _tokenBalances.length
            || length != _prices.length
        ) { revert ArrayLengthMismatch(); }

        // Loop through and configure each corresponding discount
        for (uint256 i; i < length;) {
            // Retrieve current mint info, if any
            MintInfo memory info = mintDiscountInfo[_assets[i]];
            info.active = _status[i];
            // Ensure supply or allocation cant underflow if theyre being reduced
            if (info.supply + _allocations[i] < 0) { 
                revert Underflow();
            }
            unchecked {
                info.supply += _allocations[i];
                info.allocated += _allocations[i];
            }
            // Enforced disable if adjustment eliminates mint availability
            if (info.supply <= 0 || info.allocated <= 0) { info.active = false; }
            info.tokenBalance = _tokenBalances[i];
            info.mintPrice = _prices[i];
            mintDiscountInfo[_assets[i]] = info;
            emit ConfigureMintDiscount(_assets[i], _status[i], _allocations[i], _tokenBalances[i], _prices[i]);
            unchecked { ++i; }
        }
    }

    function claimRewards(address _recipient) public virtual onlyOwner { vault.claimRewards(_recipient); }
    function compoundRewards(uint112 _eth, uint112 _weth) public virtual onlyOwner { vault.compoundRewards(_eth, _weth); }
    function rescueERC20(address _asset, address _to) public virtual onlyOwner { vault.rescueERC20(_asset, _to); }
    function rescueERC721(
        address _asset,
        address _to,
        uint256 _tokenId
    ) public virtual onlyOwner { vault.rescueERC721(_asset, _to, _tokenId); }
    function withdrawFunds(address _to, uint256 _amount) public virtual {
        // If renounced, send to fundsRecipient only
        if (owner() == address(0)) { _to = fundsRecipient; }
        // Otherwise, apply ownership check
        else if (owner() != msg.sender) { revert Unauthorized(); }
        _withdrawFunds(_to, _amount);
    }

    // Internal handling for receive() and fallback() to reduce code length
    function _processPayment() internal {
        if (mintOpen && msg.value >= price) { mint(msg.sender, uint64(msg.value / price)); }
        else { payable(address(vault)).call{ value: msg.value }(""); }
    }
    // Attempt to use funds sent directly to contract on mints if open and mintable, else send to vault
    receive() external payable { _processPayment(); }
    fallback() external payable { _processPayment(); }
}
