// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "solady/utils/LibString.sol";
import "./AlignedNFT.sol";

contract ERC721M is Ownable, AlignedNFT {

    using LibString for uint256;

    error NotMinted();
    error URILock();

    event URILocked(string indexed baseUri, string indexed contractUri);

    string private _name;
    string private _symbol;
    string private _baseURI;
    string private _contractURI;
    bool public uriLocked;

    constructor(
        uint256 _allocation,
        address _nft,
        address _pushRecipient,
        bool _pushStatus,
        string memory __name,
        string memory __symbol,
        string memory __baseURI,
        string memory __contractURI
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
        if (!uriLocked) { _baseURI = __baseURI; } else { revert URILock(); }
    }
    function updateContractURI(string memory __contractURI) public onlyOwner {
        if (!uriLocked) { _contractURI = __contractURI; } else { revert URILock(); }
    }
    function lockURI() public onlyOwner {
        uriLocked = true;
        emit URILocked(_baseURI, _contractURI);
    }
}