// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./AlignedNFT.sol";

/**
 * @title ERC721M
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, Email: zodomo@proton.me)
 */
contract ERC721M is AlignedNFT {

    using LibString for uint256;
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

    error NotActive();
    error NotMinted();
    error URILocked();
    error Underflow();
    error NotAligned();
    error MintClosed();
    error CapReached();
    error CapExceeded();
    error UnwantedNFT();
    error SpecialExceeded();
    error InsufficientPayment();
    error InsufficientBalance();

    event URILock();
    event URIChanged(string indexed baseURI);
    event PriceUpdated(uint256 indexed price);
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

    bool public uriLocked;
    bool public mintOpen;
    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    uint256 public maxSupply;
    uint256 public price;

    mapping(address => MintInfo) public mintDiscountInfo;
    // msg.sender => asset address => count
    mapping(address => mapping(address => uint64)) public minterDiscountCount;

    modifier mintable(uint256 _amount) {
        if (!mintOpen) { revert MintClosed(); }
        if (totalSupply >= maxSupply) { revert CapReached(); }
        if (totalSupply + _amount > maxSupply) { revert CapExceeded(); }
        _;
    }

    modifier onlyHolderOwnerFundsRecipient() {
        if (balanceOf(msg.sender) == 0
            && msg.sender != owner()
            && msg.sender != fundsRecipient
        ) { revert Unauthorized(); }
        _;
    }

    constructor() payable { }
    function initialize(
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        uint16 _royaltyFee, // Percentage of royalty fees in basis points (0 - 10000)
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _owner, // Collection owner
        uint256 _vaultId // NFTX vault ID
    ) external virtual payable initializer {
        // Ensure allocation is within proper range before storing
        if (_allocation < 500) { revert NotAligned(); } // Require allocation be >= 5%
        if (_allocation > 10000) { revert BadInput(); } // Require allocation be <= 100%
        allocation = _allocation;
        // Prevent bad royalty fee before initializing
        if (_royaltyFee > 10000) { revert BadInput(); }
        // Manually set for non-existent tokenId 0 to use as init status
        _setTokenRoyalty(0, _owner, uint96(_royaltyFee));
        _setDefaultRoyalty(_owner, uint96(_royaltyFee));
        // Initialize contract ownership
        _initializeOwner(_owner);
        // Set remaining storage variables
        alignedNft = _alignedNFT;
        fundsRecipient = _owner;
        // Deploy AlignmentVault and initialize
        vault = IAlignmentVault(IFactory(vaultFactory).deploy(_alignedNFT, _vaultId));
    }
    function initializeMetadata(
        string memory __name, // NFT collection name
        string memory __symbol, // NFT collection symbol/ticker
        string memory __baseURI, // Base URI for NFT metadata, preferably on IPFS
        string memory __contractURI, // Full Contract URI for NFT collection information
        uint256 _maxSupply, // Max mint supply
        uint256 _price // Standard mint price
    ) external virtual payable reinitializer(2) {
        _name = __name;
        _symbol = __symbol;
        _baseURI = __baseURI;
        _contractURI = __contractURI;
        maxSupply = _maxSupply;
        price = _price;
    }
    function disableInitializers() external virtual payable { 
        _disableInitializers();
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

    // Change recipient of mint funds
    // NOTE: This is important if you are going to renounce!
    function changeFundsRecipient(address _to) external virtual payable onlyOwner { _changeFundsRecipient(_to); }
    // Set standard mint price
    function setPrice(uint256 _price) external virtual payable onlyOwner {
        price = _price;
        emit PriceUpdated(_price);
    }
    function openMint() external virtual payable onlyOwner { mintOpen = true; }
    // Update baseURI for entire collection
    function updateBaseURI(string memory __baseURI) external virtual payable onlyOwner {
        if (!uriLocked) {
            _baseURI = __baseURI;
            emit URIChanged(__baseURI);
            emit BatchMetadataUpdate(0, maxSupply);
        } else { revert URILocked(); }
    }
    // Permanently lock collection URI
    function lockURI() external virtual payable onlyOwner {
        uriLocked = true;
        emit URILock();
    }

    // Standard mint function that supports batch minting
    function mint(address _to, uint64 _amount) public virtual payable mintable(_amount) {
        if (msg.value < (price * _amount)) { revert InsufficientPayment(); }
        _mint(_to, uint256(_amount));
        emit NormalMint(_to, _amount);
    }

    // Discounted mint for owners of specific ERC20/721 tokens
    function mintDiscount(address _asset, address _to, uint64 _amount) external virtual payable mintable(_amount) {
        MintInfo memory info = mintDiscountInfo[_asset];
        // Check if discount is active by reading status and remaining discount supply
        if (!info.active || info.supply == 0) { revert NotActive(); }
        // Determine if mint amount exceeds supply
        int64 amount = (uint256(_amount).toInt256()).toInt64();
        if (amount > info.supply) { revert SpecialExceeded(); }
        if (_amount + minterDiscountCount[msg.sender][_asset] > info.userMax) { revert SpecialExceeded(); }
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
        uint64[] memory _userMax,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external virtual payable onlyOwner {
        // Confirm all arrays match in length to ensure each collection has proper values set
        uint256 length = _assets.length;
        if (
            length != _status.length
            || length != _allocations.length
            || length != _userMax.length
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
            info.userMax = _userMax[i];
            info.tokenBalance = _tokenBalances[i];
            info.mintPrice = _prices[i];
            mintDiscountInfo[_assets[i]] = info;
            emit ConfigureMintDiscount(
                _assets[i],
                _status[i],
                _allocations[i],
                _userMax[i],
                _tokenBalances[i],
                _prices[i]
            );
            unchecked { ++i; }
        }
    }

    // Check contract inventory for unsafe transfers of aligned NFTs that didn't get directed to vault
    function fixInventory(uint256[] memory _tokenIds) external virtual payable {
        // Iterate through passed array
        for (uint256 i; i < _tokenIds.length;) {
            // Try check for ownership used in case token has been burned
            try IERC721(alignedNft).ownerOf(_tokenIds[i]) {
                // If this address is the owner, send it to the vault
                if (IERC721(alignedNft).ownerOf(_tokenIds[i]) == address(this)) {
                    IERC721(alignedNft).safeTransferFrom(address(this), address(vault), _tokenIds[i]);
                }
            } catch { }
            unchecked { ++i; }
        }
    }
    // Iterate through unsafely sent NFTs to check for ownership and update vault inventory
    function checkInventory(uint256[] memory _tokenIds) external virtual payable { vault.checkInventory(_tokenIds); }
    // Iterate through all vaulted NFTs (if any) and add what can be afforded to liq, sweep remaining funds to liq after
    function alignLiquidity() external virtual payable onlyHolderOwnerFundsRecipient { vault.alignLiquidity(); }
    // Claim yield rewards from NFTX liquidity
    function claimYield(address _to) external virtual payable {
        // Cache owner address to save gas
        address owner = owner();
        // If not renounced and caller is owner, process claim
        if (owner != address(0) && owner == msg.sender) {
            vault.claimYield(_to);
            return;
        }
        // If renounced, send to fundsRecipient only
        if (owner == address(0)) {
            vault.claimYield(fundsRecipient);
            return;
        }
        // Otherwise apply ownership check
        if (owner != msg.sender) { revert Unauthorized(); }
    }
    
    // Rescue non-aligned tokens from contract, else send aligned tokens to vault
    function rescueERC20(address _asset, address _to) external virtual payable onlyOwner {
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (balance > 0) { IERC20(_asset).transfer(_to, balance); }
        vault.rescueERC20(_asset, _to);
    }
    // Rescue non-aligned NFTs from contract, else send aligned NFTs to vault
    function rescueERC721(
        address _asset,
        address _to,
        uint256 _tokenId
    ) external virtual payable onlyOwner {
        if (_asset == alignedNft && IERC721(_asset).ownerOf(_tokenId) == address(this)) {
            IERC721(_asset).safeTransferFrom(address(this), address(vault), _tokenId);
            return;
        }
        if (IERC721(_asset).ownerOf(_tokenId) == address(this)) {
            IERC721(_asset).transferFrom(address(this), _to, _tokenId);
            return;
        }
        vault.rescueERC721(_asset, _to, _tokenId);
    }
    // Claim funds accrued to deployer from mint funds
    function withdrawFunds(address _to, uint256 _amount) external virtual payable {
        // If renounced, send to fundsRecipient only
        if (owner() == address(0)) { _to = fundsRecipient; }
        // Otherwise apply ownership check
        else if (owner() != msg.sender) { revert Unauthorized(); }
        _withdrawFunds(_to, _amount);
    }

    // Internal handling for receive() and fallback() to reduce code length
    function _processPayment() internal {
        if (mintOpen && msg.value >= price) { mint(msg.sender, uint64(msg.value / price)); }
        else { payable(address(vault)).call{ value: msg.value }(""); }
    }
    // Attempt to use funds sent directly to contract on mints if open and mintable, else send to vault
    receive() external virtual payable { _processPayment(); }
    fallback() external virtual payable { _processPayment(); }
    // Forward aligned NFTs to vault, revert if sent other NFTs
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes calldata
    ) external virtual returns (bytes4) {
        if (msg.sender == alignedNft) { IERC721(alignedNft).safeTransferFrom(address(this), address(vault), _tokenId); }
        else { revert UnwantedNFT(); }
        return ERC721M.onERC721Received.selector;
    }
}
