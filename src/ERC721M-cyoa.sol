// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

// >>>>>>>>>>>> [ IMPORTS ] <<<<<<<<<<<<

import "../lib/solady/src/auth/Ownable.sol";
import "./ERC721x.sol";
import "../lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/solady/src/utils/LibString.sol";
import "../lib/solady/src/utils/FixedPointMathLib.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import "../lib/AlignmentVault/src/IAlignmentVault.sol";

import "../lib/forge-std/src/console2.sol";

// >>>>>>>>>>>> [ INTERFACES ] <<<<<<<<<<<<

interface IAsset {
    function balanceOf(address holder) external returns (uint256);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IFactory {
    function deploy(address _erc721, uint256 _vaultId) external returns (address);
}

/**
 * @title ERC721M-cyoa (Choose Your Own Allocation)
 * @author Zodomo.eth (Farcaster/Telegram/Discord/Github: @zodomo, X: @0xZodomo, Email: zodomo@proton.me)
 * @author 0xkrauser.eth (CYOA fork) (Discord/Github/X: 0xkrauser, Email: detroitmetalcrypto@gmail.com)
 * @notice A customized ERC721M that allows minters to  to automatically send a portion of mint funds to an AlignmentVault
 * @custom:github https://github.com/0xKrauser/ERC721M
 */
contract ERC721M is Ownable, ERC721x, ERC2981, Initializable, ReentrancyGuard {
    using LibString for uint256; // Used to convert uint256 tokenId to string for tokenURI()

    // >>>>>>>>>>>> [ ERRORS ] <<<<<<<<<<<<

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
    event AlignmentUpdate(uint16 indexed allocation);
    event MaxAlignmentUpdate(uint16 indexed allocation);
    event BlacklistUpdate(address[] indexed blacklist);
    event ReferralFeePaid(address indexed referral, uint256 indexed amount);
    event ReferralFeeUpdate(uint16 indexed referralFee);
    event BatchMetadataUpdate(uint256 indexed fromTokenId, uint256 indexed toTokenId);
    event ContractMetadataUpdate(string indexed uri);
    event RoyaltyUpdate(uint256 indexed tokenId, address indexed receiver, uint96 indexed royaltyFee);
    event RoyaltyDisabled();

    // >>>>>>>>>>>> [ CONSTANTS ] <<<<<<<<<<<<

    // Address of AlignmentVaultFactory, used when deploying AlignmentVault
    address public constant vaultFactory = 0xD7810e145F1A30C7d0B8C332326050Af5E067d43;
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // >>>>>>>>>>>> [ INTERNAL VARIABLES ] <<<<<<<<<<<<

    string internal _name;
    string internal _symbol;
    string internal _baseURI;
    string internal _contractURI;
    uint40 internal _totalSupply;

    // >>>>>>>>>>>> [ PUBLIC VARIABLES ] <<<<<<<<<<<<

    uint40 public maxSupply;
    uint16 public minAllocation;
    uint16 public maxAllocation;
    address public alignedNft;
    address public vault;
    uint80 public price;
    uint16 public referralFee;
    address[] public blacklist;
    bool public uriLocked;
    bool public mintOpen;

    // >>>>>>>>>>>> [ MODIFIERS ] <<<<<<<<<<<<

    modifier mintable(uint256 _amount) {
        if (!mintOpen) revert MintClosed();
        if (_totalSupply + _amount > maxSupply) revert MintCap();
        _;
    }

    // >>>>>>>>>>>> [ CONSTRUCTION / INITIALIZATION ] <<<<<<<<<<<<

    // Constructor is kept empty in order to make the template compatible with ERC-1167 proxy factories
    constructor() payable {}

    // Initialize contract, should be called immediately after deployment, ideally by factory
    function initialize(
        string memory name_, // Collection name ("Milady")
        string memory symbol_, // Collection symbol ("MIL")
        string memory baseURI_, // ipfs://...
        string memory contractURI_, // ipfs://...
        uint40 _maxSupply, // Max supply (~1.099T max)
        uint16 _royalty, // Percentage in basis points (420 == 4.20%)
        uint16 _allocation, // Minimum Percentage of mint funds to AlignmentVault in basis points, minimum of 5% (777 == 7.77%)
        address _owner, // Collection contract owner
        address _alignedNft, // Address of NFT to configure AlignmentVault for, must have NFTX vault!
        uint80 _price, // Price (~1.2M ETH max)
        uint256 _vaultId // NFTX Vault ID, please check!
    ) external payable virtual initializer {
        // Confirm mint alignment allocation is within valid range
        if (_allocation < 500) revert NotAligned(); // Require allocation be >= 5%
        if (_allocation > 10000 || _royalty > 10000) revert Invalid(); // Require allocation and royalty be <= 100%
        minAllocation = _allocation;
        maxAllocation = _allocation;
        _setTokenRoyalty(0, _owner, _royalty);
        _setDefaultRoyalty(_owner, _royalty);
        // Initialize ownership
        _initializeOwner(_owner);
        // Set all values
        _name = name_;
        _symbol = symbol_;
        _baseURI = baseURI_;
        _contractURI = contractURI_;
        maxSupply = _maxSupply;
        alignedNft = _alignedNft;
        price = _price;
        // Deploy AlignmentVault
        address alignmentVault = IFactory(vaultFactory).deploy(_alignedNft, _vaultId);
        vault = alignmentVault;
        // Send initialize payment (if any) to vault
        if (msg.value > 0) {
            (bool success,) = payable(alignmentVault).call{ value: msg.value }("");
            if (!success) revert TransferFailed();
        }
    }

    // Disables further initialization, it is best practice to use this post-initialization
    // If a deployed contract should not be initializable, call this to prevent that
    function disableInitializers() external virtual {
        _disableInitializers();
    }

    // >>>>>>>>>>>> [ VIEW / METADATA FUNCTIONS ] <<<<<<<<<<<<

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }

    function contractURI() public view virtual returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        if (!_exists(_tokenId)) revert NotMinted(); // Require token exists
        string memory baseURI_ = baseURI();
        return (bytes(baseURI_).length > 0 ? string(abi.encodePacked(baseURI_, _tokenId.toString())) : "");
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    // Override to add royalty interface. ERC721, ERC721Metadata, and ERC721x are present in the ERC721x override
    function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721x, ERC2981) returns (bool) {
        return ERC721x.supportsInterface(_interfaceId) || ERC2981.supportsInterface(_interfaceId);
    }

    function getBlacklist() public view virtual returns (address[] memory) {
        return blacklist;
    }

    // >>>>>>>>>>>> [ INTERNAL FUNCTIONS ] <<<<<<<<<<<<

    // Simple ownership check to reduce code reuse
    function _checkOwnership() internal virtual {
        // Cache owner address to save gas
        address owner = owner();
        // If contract is owned and caller isn't them, revert. If renounced, still process vault action.
        if (owner != address(0) && owner != msg.sender) revert Unauthorized();
    }

    // Blacklist function to prevent mints to and from holders of prohibited assets, applied even if recipient isn't minter
    function _enforceBlacklist(address _minter, address _recipient) internal virtual {
        address[] memory _blacklist = blacklist;
        uint256 count;
        for (uint256 i; i < _blacklist.length;) {
            unchecked {
                count += IAsset(_blacklist[i]).balanceOf(_minter);
                count += IAsset(_blacklist[i]).balanceOf(_recipient);
                if (count > 0) revert Blacklisted();
                ++i;
            }
        }
    }

    // >>>>>>>>>>>> [ MINT LOGIC ] <<<<<<<<<<<<

    // Solady ERC721 _mint override to implement mint funds alignment and blacklist
    function _mint(address _to, uint256 _amount, address _referral, uint16 _allocation
    ) internal {
        console2.log(msg.value);
        // Prevent bad inputs
        if (_to == address(0) || _amount == 0) revert Invalid();
        // Ensure minter and recipient don't hold blacklisted assets
        _enforceBlacklist(msg.sender, _to);
        // Calculate allocation
        uint256 mintAlloc = FixedPointMathLib.fullMulDivUp(_allocation, msg.value, 10000);
        console2.log(mintAlloc);

        // Send aligned amount to AlignmentVault (success is intentionally not read to save gas as it cannot fail)
        payable(vault).call{value: mintAlloc}("");

        // If _referral isn't address(0), process sending referral fee
        // Reentrancy is handled by applying ReentrancyGuard to referral mint function [mint(address, uint256, address)]
        if (_referral != address(0)) {
            uint256 referralAlloc = FixedPointMathLib.mulDivUp(referralFee, msg.value, 10000);
            console2.log(referralAlloc);
            (bool success, ) = payable(_referral).call{value: referralAlloc}("");
            if (!success) revert TransferFailed();
            emit ReferralFeePaid(_referral, referralAlloc);
        }

        // Process ERC721 mints
        // totalSupply is read once externally from loop to reduce SLOADs to save gas
        uint256 supply = _totalSupply;
        for (uint256 i; i < _amount;) {
            _mint(_to, ++supply);
            unchecked {
                ++i;
            }
        }
        unchecked {
            _totalSupply += uint40(_amount);
        }
    }

    // Standard mint function that supports batch minting
    function mint(address _to, uint256 _amount, uint16 _allocation) public payable virtual mintable(_amount) {
        if (msg.value < (price * _amount)) revert InsufficientPayment();
        _mint(_to, _amount, address(0), _allocation);
    }

    // Standard batch mint with referral fee support
    function mint(address _to, uint256 _amount, address _referral, uint16 _allocation) public payable virtual mintable(_amount) nonReentrant {
        if (_referral == msg.sender) revert Invalid();
        if (msg.value < (price * _amount)) revert InsufficientPayment();
        _mint(_to, _amount, _referral, _allocation);
    }

    // Standard single-unit mint to msg.sender (implemented for max scannner compatibility)
    function mint() public payable virtual mintable(1) {
        if (msg.value < price) revert InsufficientPayment();
        _mint(msg.sender, 1, address(0), minAllocation);
    }

    // Standaard multi-unit mint to msg.sender (implemented for max scanner compatibility)
    function mint(uint256 _amount) public payable virtual mintable(_amount) {
        if (msg.value < (price * _amount)) revert InsufficientPayment();
        _mint(msg.sender, _amount, address(0), minAllocation);
    }

    // >>>>>>>>>>>> [ PERMISSIONED / OWNER FUNCTIONS ] <<<<<<<<<<<<

    // Set referral fee, must be < (10000 - allocation)
    function setReferralFee(uint16 _referralFee) external virtual onlyOwner {
        if (_referralFee > (10000 - maxAllocation)) revert Invalid();
        referralFee = _referralFee;
        emit ReferralFeeUpdate(_referralFee);
    }

    // Update baseURI for entire collection
    function setBaseURI(string memory baseURI_) external virtual onlyOwner {
        if (uriLocked) revert URILocked();
        _baseURI = baseURI_;
        emit BatchMetadataUpdate(0, maxSupply);
    }

    // Adjust contractURI if necessary
    function setContractURI(string memory contractURI_) external virtual onlyOwner {
        if (uriLocked) revert URILocked();
        _contractURI = contractURI_;
        emit ContractMetadataUpdate(contractURI_);
    }

    // Permanently lock collection URI
    function lockURI() external virtual onlyOwner {
        uriLocked = true;
        emit URILock();
    }

    // Update ETH mint price
    function setPrice(uint80 _price) external virtual onlyOwner {
        price = _price;
        emit PriceUpdate(_price);
    }

    // Set default royalty receiver and royalty fee
    function setRoyalties(address _recipient, uint96 _royaltyFee) external virtual onlyOwner {
        if (_royaltyFee > 10000) revert Invalid();
        // Revert if royalties are disabled
        (address receiver,) = royaltyInfo(0, 0);
        if (receiver == address(0)) revert RoyaltiesDisabled();

        // Royalty recipient of nonexistent tokenId 0 is used as royalty status indicator, address(0) == disabled
        _setTokenRoyalty(0, _recipient, _royaltyFee);
        _setDefaultRoyalty(_recipient, _royaltyFee);
        emit RoyaltyUpdate(0, _recipient, _royaltyFee);
    }

    // Set royalty receiver and royalty fee for a specific tokenId
    function setRoyaltiesForId(
        uint256 _tokenId,
        address _recipient,
        uint96 _royaltyFee
    ) external virtual onlyOwner {
        if (_royaltyFee > 10000) revert Invalid();
        // Revert if royalties are disabled
        (address receiver,) = royaltyInfo(0, 0);
        if (receiver == address(0)) revert RoyaltiesDisabled();
        // Revert if resetting tokenId 0 as it is utilized for royalty enablement status
        if (_tokenId == 0) revert Invalid();

        // Reset token royalty if fee is 0, else set it
        if (_royaltyFee == 0) _resetTokenRoyalty(_tokenId);
        else _setTokenRoyalty(_tokenId, _recipient, _royaltyFee);
        emit RoyaltyUpdate(_tokenId, _recipient, _royaltyFee);
    }

    // Irreversibly disable royalties by resetting tokenId 0 royalty to (address(0), 0) and deleting default royalty info
    function disableRoyalties() external virtual onlyOwner {
        _deleteDefaultRoyalty();
        _resetTokenRoyalty(0);
        emit RoyaltyDisabled();
    }

    // Configure which assets are on blacklist
    function setBlacklist(address[] memory _blacklist) external virtual onlyOwner {
        blacklist = _blacklist;
        emit BlacklistUpdate(blacklist);
    }

    // Open mint functions
    function openMint() external virtual onlyOwner {
        mintOpen = true;
        emit MintOpen();
    }

    // Increase mint alignment allocation
    // NOTE: There is and will be no function to decrease this value. This operation is one-way only.
    function increaseAlignment(uint16 _allocation) external virtual onlyOwner {
        // Prevent alignment deception (changing it last mint) by locking it in at 50% minted
        if (totalSupply() > maxSupply / 2) revert Invalid();
        // Prevent reducing or oversetting alignment (keeping maxAllocation in mind)
        if (_allocation <= minAllocation || _allocation > maxAllocation) revert Invalid();
        minAllocation = _allocation;
        emit AlignmentUpdate(_allocation);
    }

    function increaseMaxAllocation(uint16 _allocation) external virtual onlyOwner {
        // Prevent reducing or oversetting alignment (keeping referralFee in mind)
        if (_allocation < minAllocation || (_allocation + referralFee) > 10000) revert Invalid();
        maxAllocation = _allocation;
        emit MaxAlignmentUpdate(_allocation);
    }

    // Decrease token maxSupply
    // NOTE: There is and will be no function to increase supply. This operation is one-way only.
    function decreaseSupply(uint40 _newSupply) external virtual onlyOwner {
        if (_newSupply >= maxSupply || _newSupply < totalSupply()) revert Invalid();
        maxSupply = _newSupply;
        emit SupplyUpdate(_newSupply);
    }

    // Restrict ability to update approved ERC721x-supporting contract status to owner
    function updateApprovedContracts(address[] calldata _contracts, bool[] calldata _values) external virtual onlyOwner {
        _updateApprovedContracts(_contracts, _values);
    }

    // Withdraw non-allocated mint funds
    function withdrawFunds(address _to, uint256 _amount) external virtual nonReentrant {
        // Cache owner address to save gas
        address owner = owner();
        uint256 balance = address(this).balance;
        if (_to == address(0)) revert Invalid();
        // If contract is owned and caller isn't them, revert.
        if (owner != address(0) && owner != msg.sender) revert Unauthorized();
        // If contract is renounced, convert _to to vault and withdraw all funds to it
        if (owner == address(0)) {
            _to = vault;
            _amount = balance;
        }
        // Instead of reverting for overage, simply overwrite _amount with balance
        if (_amount > balance) _amount = balance;

        // Process withdrawal
        (bool success,) = payable(_to).call{ value: _amount }("");
        if (!success) revert TransferFailed();
        emit Withdraw(_to, _amount);
    }

    // >>>>>>>>>>>> [ ALIGNMENTVAULT INTEGRATION ] <<<<<<<<<<<<

    // Check contract inventory for unsafe transfers of aligned NFTs that didn't get directed to vault and send them there
    function fixInventory(uint256[] memory _tokenIds) external payable virtual {
        // Iterate through passed array
        for (uint256 i; i < _tokenIds.length;) {
            // Try check for ownership used in case token has been burned
            try IERC721(alignedNft).ownerOf(_tokenIds[i]) {
                // If this address is the owner, send it to the vault
                if (IERC721(alignedNft).ownerOf(_tokenIds[i]) == address(this)) {
                    IERC721(alignedNft).safeTransferFrom(address(this), address(vault), _tokenIds[i]);
                }
            } catch {}
            unchecked {
                ++i;
            }
        }
        // Send any payment to AlignmentVault
        payable(vault).call{ value: msg.value }("");
    }

    // Check vault inventory for unsafely sent NFTs and add them to internal accounting
    function checkInventory(uint256[] memory _tokenIds) external payable virtual {
        IAlignmentVault(vault).checkInventory{ value: msg.value }(_tokenIds);
    }

    // Add specific tokenIds held by vault to NFTX liquidity if enough ETH/WETH is present
    // NOTE: You do not need to fix or check inventory before this operation if tokenIds are known to be held by vault
    function alignNfts(uint256[] memory _tokenIds) external payable virtual {
        _checkOwnership();
        IAlignmentVault(vault).alignNfts{ value: msg.value }(_tokenIds);
    }

    // Add specific amount of ETH/WETH held by vault and all other associated tokens to NFTX liquidity
    // NOTE: This operation doesn't affect NFTs held by vault at all
    function alignTokens(uint256 _amount) external payable virtual {
        _checkOwnership();
        IAlignmentVault(vault).alignTokens{ value: msg.value }(_amount);
    }

    // Iterate through all vaulted NFTs (if any) and add what can be afforded to NFTX liquidity
    // Also adds remaining ETH/WETH to NFTX liquidity, regardless of if there are NFTs left over in inventory
    function alignMaxLiquidity() external payable virtual {
        _checkOwnership();
        IAlignmentVault(vault).alignMaxLiquidity();
    }

    // Claim yield rewards from NFTX. If renounced, compound yield.
    function claimYield(address _to) external payable virtual {
        // Cache owner address to save gas
        address owner = owner();
        // If not renounced and caller is owner, process claim
        if (owner != address(0) && owner != msg.sender) revert Unauthorized();
        // If renounced, change _to to zero address to trigger yield compounding
        if (owner == address(0)) _to = address(0);
        IAlignmentVault(vault).claimYield{ value: msg.value }(_to);
    }

    // >>>>>>>>>>>> [ ASSET HANDLING ] <<<<<<<<<<<<

    // Internal handling for receive() and fallback() to reduce code length
    function _processPayment() internal {
        if (mintOpen) mint(msg.sender, (msg.value / price), minAllocation);
        else {
            // Calculate allocation and split paymeent accordingly
            uint256 mintAlloc = FixedPointMathLib.fullMulDivUp(minAllocation, msg.value, 10000);
            // Success when transferring to vault isn't checked because transfers to vault cant fail
            payable(vault).call{ value: mintAlloc }("");
            // Reentrancy risk is ignored here because if owner wants to withdraw that way that's their prerogative
            // But if transfer to owner fails for any reason, it will be sent to the vault
            (bool success,) = payable(owner()).call{ value: msg.value - mintAlloc }("");
            if (!success) payable(vault).call{ value: msg.value - mintAlloc }("");
        }
    }

    // Forward aligned NFTs to vault, revert if sent other NFTs
    function onERC721Received(address, address, uint256 _tokenId, bytes calldata) external virtual returns (bytes4) {
        address nft = alignedNft;
        if (msg.sender == nft) IERC721(nft).safeTransferFrom(address(this), vault, _tokenId);
        else revert NotAligned();
        return ERC721M.onERC721Received.selector;
    }

    // Rescue non-aligned tokens from contract, else send aligned tokens to vault
    function rescueERC20(address _asset, address _to) external virtual onlyOwner {
        uint256 balance = IERC20(_asset).balanceOf(address(this));
        if (_asset == weth) {
            if (balance > 0) IERC20(_asset).transfer(vault, balance);
        } else {
            if (balance > 0) IERC20(_asset).transfer(_to, balance);
        }
        IAlignmentVault(vault).rescueERC20(_asset, _to);
    }

    // Rescue non-aligned NFTs from contract, else send aligned NFTs to vault
    function rescueERC721(address _asset, address _to, uint256 _tokenId) external virtual onlyOwner {
        if (_asset == alignedNft && IERC721(_asset).ownerOf(_tokenId) == address(this)) {
            IERC721(_asset).safeTransferFrom(address(this), vault, _tokenId);
            return;
        }
        if (IERC721(_asset).ownerOf(_tokenId) == address(this)) {
            IERC721(_asset).transferFrom(address(this), _to, _tokenId);
            return;
        }
        IAlignmentVault(vault).rescueERC721(_asset, _to, _tokenId);
    }

    // Process all received ETH payments
    receive() external payable virtual {
        _processPayment();
    }

    // Process any erroneous contract calls by processing any ETH included and discarding calldata
    fallback() external payable virtual {
        _processPayment();
    }
}