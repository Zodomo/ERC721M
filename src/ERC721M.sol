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
    error InsufficientPayment();

    event URIChanged(string indexed baseUri);
    event URILock();
    event BatchMetadataUpdate(uint256 indexed _fromTokenId, uint256 indexed _toTokenId);

    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    bool public uriLocked;
    bool public mintOpen;
    uint256 public immutable totalSupply;
    uint256 public count;
    uint256 public price;

    modifier mintable() {
        if (!mintOpen) { revert MintClosed(); }
        if (count >= totalSupply) { revert CapReached(); }
        _;
    }

    constructor(
        uint256 _allocation,
        address _nft,
        address _pushRecipient,
        bool _pushStatus,
        string memory __name,
        string memory __symbol,
        string memory __baseURI,
        string memory __contractURI,
        uint256 _totalSupply,
        uint256 _price
    ) AlignedNFT(
        _allocation,
        _nft,
        _pushRecipient,
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
    function _baseUri() internal view returns (string memory) { return (_baseURI); }
    function contractURI() public view returns (string memory) { return (_contractURI); }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        if (!_exists(_tokenId)) { revert NotMinted(); } // Require token exists
        string memory __baseURI = _baseUri();

        return (bytes(__baseURI).length > 0 ? string(abi.encodePacked(__baseURI, _tokenId.toString())) : "");
    }

    function updateBaseURI(string memory __baseURI) public onlyOwner {
        if (!uriLocked) {
            _baseURI = __baseURI;
            emit URIChanged(__baseURI);
            emit BatchMetadataUpdate(0, totalSupply);
        } else { revert URILocked(); }
    }
    function lockURI() public onlyOwner {
        uriLocked = true;
        emit URILock();
    }

    function mint(address _to, uint256 _amount) public payable mintable {
        if (msg.value < (price * _amount)) { revert InsufficientPayment(); }
        for (uint256 i; i < _amount;) {
            _mint(_to, ++count);
            unchecked { ++i; }
        }
    }
}