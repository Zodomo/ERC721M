// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "solady/utils/LibString.sol";
import "./AlignedNFT.sol";

contract ERC721M is Ownable, AlignedNFT {

    using LibString for uint256;

    error NotMinted();
    error URILocked();
    error MintClosed();
    error CapReached();
    error CapExceeded();
    error InsufficientPayment();

    event URIChanged(string indexed baseUri);
    event URILock();
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event PriceUpdated(uint256 indexed price);

    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    bool public uriLocked;
    bool public mintOpen;
    uint256 public immutable totalSupply;
    uint256 public price;

    modifier mintable() {
        if (!mintOpen) { revert MintClosed(); }
        if (count >= totalSupply) { revert CapReached(); }
        _;
    }

    constructor(
        uint16 _allocation,
        bool _pushStatus,
        address _nft,
        address _pushRecipient,
        string memory __name,
        string memory __symbol,
        string memory __baseURI,
        string memory __contractURI,
        uint256 _totalSupply,
        uint256 _price
    ) AlignedNFT(
        _nft,
        _pushRecipient,
        _allocation,
        _pushStatus
    ) payable {
        _name = __name;
        _symbol = __symbol;
        _baseURI = __baseURI;
        _contractURI = __contractURI;
        totalSupply = _totalSupply;
        price = _price;
        _initializeOwner(msg.sender);
    }

    function name() public view override returns (string memory) { return (_name); }
    function symbol() public view override returns (string memory) { return (_symbol); }
    function baseUri() public view virtual returns (string memory) { return (_baseURI); }
    function contractURI() public view virtual returns (string memory) { return (_contractURI); }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) { revert NotMinted(); } // Require token exists
        string memory __baseURI = baseUri();

        return (bytes(__baseURI).length > 0 ? string(abi.encodePacked(__baseURI, _tokenId.toString())) : "");
    }

    function changePushRecipient(address _to) public virtual onlyOwner { _changePushRecipient(_to); }
    function setPushStatus(bool _pushStatus) public virtual onlyOwner { _setPushStatus(_pushStatus); }
    function setPrice(uint256 _price) public virtual onlyOwner {
        price = _price;
        emit PriceUpdated(_price);
    }
    function openMint() public virtual onlyOwner { mintOpen = true; }

    function updateBaseURI(string memory __baseURI) public virtual onlyOwner {
        if (!uriLocked) {
            _baseURI = __baseURI;
            emit URIChanged(__baseURI);
            emit BatchMetadataUpdate(0, totalSupply);
        } else { revert URILocked(); }
    }
    function lockURI() public virtual onlyOwner {
        uriLocked = true;
        emit URILock();
    }

    function mint(address _to, uint256 _amount) public payable mintable {
        if (msg.value < (price * _amount)) { revert InsufficientPayment(); }
        if (count + _amount > totalSupply) { revert CapExceeded(); }
        _mint(_to, _amount);
    }

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
    function withdrawAllocation(address _to, uint256 _amount) public onlyOwner { _withdrawAllocation(_to, _amount); }

    receive() external payable {
        (bool success, ) = payable(address(vault)).call{ value: msg.value }("");
        if (!success) { revert TransferFailed(); }
    }
    fallback() external payable {
        (bool success, ) = payable(address(vault)).call{ value: msg.value }("");
        if (!success) { revert TransferFailed(); }
    }
}