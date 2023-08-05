// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "solady/utils/LibString.sol";
import "./AlignedNFT.sol";

interface IERC721Burn {
    function burn(uint256 _tokenId) external;
}

contract ERC721M is AlignedNFT {

    using LibString for uint256;

    error NotMinted();
    error URILocked();
    error MintClosed();
    error CapReached();
    error NoDiscount();
    error CapExceeded();
    error TokenNotBurned();
    error DiscountExceeded();
    error MintBurnDisabled();
    error TokenNotLockable();
    error ArrayLengthMismatch();
    error InsufficientPayment();
    error CollectionZeroBalance();
    error NotEnoughTokensLocked();
    error NotBurnableCollection();

    event URILock();
    event URIChanged(string indexed baseUri);
    event PriceUpdated(uint256 indexed price);
    event TokensLocked(address indexed token, uint256 indexed amount);
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event CollectionDiscount(address indexed collection, uint256 indexed discount, uint256 indexed quantity);
    event DiscountOverwritten(address indexed collection, uint256 indexed discount, uint256 indexed remainingQty);

    bool public uriLocked;
    bool public mintOpen;
    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    uint256 public immutable maxSupply;
    uint256 public price;
    uint256 public burnsToMint;
    mapping(address => uint256[]) public collectionDiscount; // NFT address => [Discount Price, Quantity of Discounted Mints]
    mapping(address => bool) public burnableCollections; // Collections that are eligible for burn to mint
    mapping(address => uint256) public burnedTokens; // How many tokens an address has burned
    mapping(address => uint256) public tokenTimelock; // Timelock period for each token
    mapping(address => uint256) public tokenLockAmounts; // Amount of tokens required to lock to mint, token is not allowed if zero
    mapping(address => mapping(address => uint256)) public lockedTokens; // How many tokens of any type have been locked, msg.sender => (token => amount)
    mapping(address => mapping(address => uint256)) public lockTimestamp; // Timestamp for when specific token lock ends per token, msg.sender => (token => timestamp)

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
    ) payable {
        // Prevent bad royalty fee
        if (_royaltyFee > 10000) { revert BadInput(); }

        // Set all relevant metadata and contract configurations
        _name = __name;
        _symbol = __symbol;
        _baseURI = __baseURI;
        _contractURI = __contractURI;
        maxSupply = _maxSupply;
        price = _price;

        // Set ownership using msg.sender or tx.origin to support factory deployment
        // Determination is made by checking if msg.sender is a smart contract or not by checking code size
        uint32 size;
        address sender;
        assembly { size:= extcodesize(sender) }
        if (size > 0) { sender = tx.origin; }
        else { sender = msg.sender; }
        _initializeOwner(sender);

        // Configure royalties for contract owner
        _setDefaultRoyalty(sender, uint96(_royaltyFee));
    }


    // ERC721 Metadata
    function name() public view virtual override returns (string memory) { return (_name); }
    function symbol() public view virtual override returns (string memory) { return (_symbol); }
    function baseUri() public view virtual returns (string memory) { return (_baseURI); }
    function contractURI() public view virtual returns (string memory) { return (_contractURI); }
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) { revert NotMinted(); } // Require token exists
        string memory __baseURI = baseUri();

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
    function mint(address _to, uint256 _amount) public payable mintable(_amount) {
        if (msg.value < (price * _amount)) { revert InsufficientPayment(); }
        _mint(_to, _amount);
    }

    // Discounted mint for owners of specific NFTs
    function mintDiscounted(address _nft, address _to, uint256 _amount) public payable mintable(_amount) {
        // Apply all discount checks
        if (IERC721(_nft).balanceOf(msg.sender) == 0) { revert CollectionZeroBalance(); }
        uint256 discountPrice = collectionDiscount[_nft][0];
        if (discountPrice > 0 && msg.value < (discountPrice * _amount)) { revert InsufficientPayment(); }
        uint256 discountQuantity = collectionDiscount[_nft][1];
        if (discountQuantity == 0) { revert NoDiscount(); }
        if (_amount > discountQuantity) { revert DiscountExceeded(); } // Also prevents underflow

        // Deduct mints from discount allocation
        unchecked { collectionDiscount[_nft][1] -= _amount; } // Cannot underflow as it is checked for prior
        _mint(_to, _amount);
    }
    // Configure collection ownership-based discounted mints, bulk compatible
    // Each individual collection must have a corresponding discount price and total discounted mint quantity
    function configureMintDiscount(
        address[] memory _nft,
        uint256[] memory _price,
        uint256[] memory _quantity
    ) public virtual onlyOwner {
        // Confirm all arrays match in length to ensure each collection has proper values set
        uint256 length = _nft.length;
        if (length != _price.length && length != _quantity.length) { revert ArrayLengthMismatch(); }
        uint256[] memory discount = new uint256[](2);
        // Loop through and configure each corresponding discount
        for (uint256 i; i < length;) {
            // Log if existing discount is being overwritten
            uint256 remainingQty = collectionDiscount[_nft[i]][1];
            if (remainingQty > 0) {
                emit DiscountOverwritten(_nft[i], collectionDiscount[_nft[i]][0], remainingQty);
            }
            // Store new discount, if _quantity is zero, discount is disabled
            if (_quantity[i] == 0) {
                discount[0] = 0;
                discount[1] = 0;
            } else {
                discount[0] = _price[i];
                discount[1] = _quantity[i];
            }
            collectionDiscount[_nft[i]] = discount;
            emit CollectionDiscount(_nft[i], _price[i], _quantity[i]);
            unchecked { ++i; }
        }
    }

    // Burn NFTs of any allowed collections to mint
    // _tokenIds is an array of tokenId arrays, each corresponding to a collection
    function mintBurn(
        address _to, 
        address[] memory _nft, 
        uint256[][] memory _tokenIds
    ) public virtual payable {
        // TODO: Replicate mintable modifier logic
        // If burnsToMint is zero, mintBurn is disabled
        if (burnsToMint == 0) { revert MintBurnDisabled(); }
        // Require NFT collection and array of tokenId arrays be equal length
        if (_nft.length != _tokenIds.length) { revert ArrayLengthMismatch(); }
        // Iterate through each collection
        for (uint256 i; i < _nft.length;) {
            // Confirm collection is burnable
            if (!burnableCollections[_nft[i]]) { revert NotBurnableCollection(); }
            // Iterate through all tokenIds for the collection
            for (uint256 j; j < _tokenIds[i].length;) {
                // Balance is checked and reduction validated to ensure burn took place
                uint256 nftBal = IERC721(_nft[i]).balanceOf(msg.sender);
                // Attempt to call a burn function, otherwise attempt to destroy token by sending to zero or dead address
                try IERC721Burn(_nft[i]).burn(_tokenIds[i][j]) { } catch { }
                if (nftBal == IERC721(_nft[i]).balanceOf(msg.sender)) {
                    try IERC721(_nft[i]).transferFrom(msg.sender, address(0x0), _tokenIds[i][j]) { }
                    catch { IERC721(_nft[i]).transferFrom(msg.sender, address(0xDEAD), _tokenIds[i][j]); }
                }
                if (IERC721(_nft[i]).balanceOf(msg.sender) >= nftBal) { revert TokenNotBurned(); }
                ++burnedTokens[msg.sender];
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
        uint256 mintAmount = burnedTokens[msg.sender] / burnsToMint;
        burnedTokens[msg.sender] -= (mintAmount * burnsToMint);
        _mint(_to, mintAmount);
    }
    // Configure mint to burn functionality by specifying allowed collections and how many tokens are required
    // Amount is shared across all collections
    // Set _amount to zero to disable mintBurn
    function configureMintBurn(address[] memory _nft, uint256 _amount) public virtual onlyOwner {
        for (uint256 i; i < _nft.length;) {
            if (_amount == 0) { burnableCollections[_nft[i]] = false; }
            else { burnableCollections[_nft[i]] = true;}
            unchecked { ++i; }
        }
        burnsToMint = _amount;
    }

    // Lock tokens to mint, timelock period is defined per token, token timelock will reset each time a respective token is locked
    function mintLockTokens(
        address _to, 
        address[] memory _tokens, 
        uint256[] memory _amounts
    ) public virtual payable {
        // TODO: Replicate mintable modifier logic
        // Require NFT collection and array of tokenId arrays be equal length
        if (_tokens.length != _amounts.length) { revert ArrayLengthMismatch(); }
        for (uint256 i; i < _tokens.length;) {
            // Retrieve token and amount for better code readability
            address token = _tokens[i];
            uint256 amount = _amounts[i];
            // Confirm token is lockable
            uint256 requiredAmount = tokenLockAmounts[token];
            if (requiredAmount == 0) { revert TokenNotLockable(); }
            if (tokenLockAmounts[token] > _amounts[i]) { revert NotEnoughTokensLocked(); }

            // TODO: Calculate how many mints can take place with amount

            // Transfer tokens and confirm it actually occurred
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).transferFrom(msg.sender, address(this), amount);
            if (balance >= IERC20(token).balanceOf(address(this))) { revert TransferFailed(); }

            // Log token lock
            lockedTokens[msg.sender][token] += amount;
            lockTimestamp[msg.sender][token] = block.timestamp + tokenTimelock[token]; // Reset token timelock every mint
            emit TokensLocked(token, amount);

            // TODO: Mint based on amount

            unchecked { ++i; }
        }
    }
    // Configure lock tokens to mint function by specifying token address, amounts, and timelock periods per token
    // Setting amount to zero will disable token as a lockable option
    function configureMintLockTokens(
        address[] memory _tokens, 
        uint256[] memory _amounts, 
        uint256[] memory _timestamps
    ) public virtual onlyOwner {
        // Confirm all arrays are equal length
        uint256 length = _tokens.length;
        if (length != _amounts.length && length != _timestamps.length) { revert ArrayLengthMismatch(); }
        for (uint256 i; i < length;) {
            tokenLockAmounts[_tokens[i]] = _amounts[i];
            tokenTimelock[_tokens[i]] = _timestamps[i];
            unchecked { ++i; }
        }
    }

    // Vault contract management
    function wrap(uint256 _amount) public virtual onlyOwner { vault.wrap(_amount); }
    function addInventory(uint256[] calldata _tokenIds) public virtual onlyOwner { vault.addInventory(_tokenIds); }
    function addLiquidity(uint256[] calldata _tokenIds) public virtual onlyOwner { vault.addLiquidity(_tokenIds); }
    function deepenLiquidity(
        uint112 _eth,
        uint112 _weth,
        uint112 _nftxInv
    ) public virtual onlyOwner { vault.deepenLiquidity(_eth, _weth, _nftxInv); }
    function stakeLiquidity() public virtual onlyOwner { vault.stakeLiquidity(); }
    function claimRewards(address _recipient) public virtual onlyOwner { vault.claimRewards(_recipient); }
    function compoundRewards(uint112 _eth, uint112 _weth) public virtual onlyOwner { vault.compoundRewards(_eth, _weth); }
    function rescueERC20(address _token, address _to) public virtual onlyOwner { vault.rescueERC20(_token, _to); }
    function rescueERC721(
        address _address,
        address _to,
        uint256 _tokenId
    ) public virtual onlyOwner { vault.rescueERC721(_address, _to, _tokenId); }
    function withdrawFunds(address _to, uint256 _amount) public virtual {
        // If renounced, send to fundsRecipient only
        if (owner() == address(0)) { _to = fundsRecipient; }
        // Otherwise, apply ownership check
        else if (owner() != msg.sender) { revert Unauthorized(); }
        _withdrawFunds(_to, _amount);
    }

    // Internal handling for receive() and fallback() to reduce code length
    function _processPayment() internal {
        if (mintOpen && msg.value >= price) { mint(msg.sender, msg.value / price); }
        else {
            (bool success, ) = payable(address(vault)).call{ value: msg.value }("");
            if (!success) { revert TransferFailed(); }
        }
    }
    // Attempt to use funds sent directly to contract on mints if open and mintable, else send to vault
    receive() external payable { _processPayment(); }
    fallback() external payable { _processPayment(); }
}