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
        uint256 tokenBalance,
        uint256 price
    );

    struct MintInfo {
        int64 supply;
        int64 allocated;
        bool active;
        uint256 tokenBalance;
        uint256 mintPrice;
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

    modifier mintable(uint256 _amount) {
        if (!mintOpen) { revert MintClosed(); }
        if (totalSupply >= maxSupply) { revert CapReached(); }
        if (totalSupply + _amount > maxSupply) { revert CapExceeded(); }
        _;
    }

    constructor() payable { }
    function initialize(
        uint16 _allocation, // Percentage of mint funds allocated to aligned collection in basis points (500 - 10000)
        uint16 _royaltyFee, // Percentage of royalty fees in basis points (0 - 10000)
        address _alignedNFT, // Address of aligned NFT collection mint funds are being dedicated to
        address _owner, // Collection owner
        uint256 _vaultId // NFTX vault ID
    ) external initializer {
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
    ) external reinitializer(2) {
        _name = __name;
        _symbol = __symbol;
        _baseURI = __baseURI;
        _contractURI = __contractURI;
        maxSupply = _maxSupply;
        price = _price;
    }
    function disableInitializers() external { 
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

    // Check contract inventory for unsafe transfers of aligned NFTs that didn't get directed to vault
    function fixInventory(uint256[] memory _tokenIds) public {
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

    function checkInventory(uint256[] memory _tokenIds) public virtual { vault.checkInventory(_tokenIds); }
    function alignLiquidity() public virtual { vault.alignLiquidity(); }
    function claimYield(address _to) public virtual {
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
    
    function rescueERC20(address _asset, address _to) public virtual onlyOwner {
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (balance > 0) { IERC20(_asset).transfer(_to, balance); }
        vault.rescueERC20(_asset, _to);
    }
    function rescueERC721(
        address _asset,
        address _to,
        uint256 _tokenId
    ) public virtual onlyOwner {
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
    function withdrawFunds(address _to, uint256 _amount) public virtual {
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
    receive() external payable { _processPayment(); }
    fallback() external payable { _processPayment(); }
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
