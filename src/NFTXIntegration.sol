// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import "./UniswapV2LiquidityHelper.sol";
import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";

interface INFTXFactory {
    function vaultsForAsset(address asset) external view returns (address[] memory);
}

interface INFTXVault {
    function vaultId() external view returns (uint256);
}

interface INFTXInventoryStaking {
    function vaultXToken(uint256 vaultId) external view returns (address);
    function xTokenAddr(address baseToken) external view returns (address);
    function xTokenShareValue(uint256 vaultId) external view returns (uint256);

    function __NFTX_INVENTORY_STAKING_init(address nftxFactory) external;
    
    function deployXTokenForVault(uint256 vaultId) external;
    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);
    function timelockMintFor(uint256 vaultId, uint256 amount, address to, uint256 timelockLength) external returns (uint256);
    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;
}

interface INFTXLPStaking {
    function nftxVaultFactory() external view returns (address);
    function rewardDistTokenImpl() external view returns (address);
    function stakingTokenProvider() external view returns (address);
    function vaultToken(address _stakingToken) external view returns (address);
    function stakingToken(address _vaultToken) external view returns (address);
    function rewardDistributionToken(uint256 vaultId) external view returns (address);
    function newRewardDistributionToken(uint256 vaultId) external view returns (address);
    function oldRewardDistributionToken(uint256 vaultId) external view returns (address);
    function unusedRewardDistributionToken(uint256 vaultId) external view returns (address);
    function rewardDistributionTokenAddr(address stakedToken, address rewardToken) external view returns (address);
    
    // Write functions.
    function __NFTX_LIQUIDITY_STAKING__init(address _stakingTokenProvider) external;
    function setNFTXVaultFactory(address newFactory) external;
    function setStakingTokenProvider(address newProvider) external;
    function addPoolForVault(uint256 vaultId) external;
    function updatePoolForVault(uint256 vaultId) external;
    function updatePoolForVaults(uint256[] calldata vaultId) external;
    function receiveRewards(uint256 vaultId, uint256 amount) external returns (bool);
    function deposit(uint256 vaultId, uint256 amount) external;
    function timelockDepositFor(uint256 vaultId, address account, uint256 amount, uint256 timelockLength) external;
    function exit(uint256 vaultId, uint256 amount) external;
    function rescue(uint256 vaultId) external;
    function withdraw(uint256 vaultId, uint256 amount) external;
    function claimRewards(uint256 vaultId) external;
}

interface INFTXStakingZap {
    function provideInventory721(uint256 vaultId, uint256[] calldata tokenIds) external;
    function addLiquidity721(uint256 vaultId, uint256[] calldata ids, uint256 minWethIn, uint256 wethIn) external returns (uint256);
}

abstract contract NFTXIntegration {

    error BalanceDidntIncrease(address token);
    error InsufficientBalance();
    error IncorrectOwner();
    error IdenticalAddresses();
    error ZeroAddress();

    IWETH constant internal _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant internal _SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Router02 constant internal _SUSHI_V2_ROUTER = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    UniswapV2LiquidityHelper internal immutable _liqHelper;

    INFTXFactory constant internal _NFTX_VAULT_FACTORY = INFTXFactory(0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    INFTXInventoryStaking constant internal _NFTX_INVENTORY_STAKING = INFTXInventoryStaking(0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);
    INFTXLPStaking constant internal _NFTX_LIQUIDITY_STAKING = INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);
    INFTXStakingZap constant internal _NFTX_STAKING_ZAP = INFTXStakingZap(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    
    IERC721 immutable internal _erc721; // ERC721 token
    IERC20 immutable internal _nftxInventory; // NFTX NFT token
    IERC20 immutable internal _nftxLiquidity; // NFTX NFTWETH token
    uint256 immutable internal _vaultId;

    function _checkBalance(IERC20 _token) internal view returns (uint256) {
        if (address(_token) == address(0)) { return (address(this).balance); }
        else { return (_token.balanceOf(address(this))); }
    }

    // Sort token addresses for LP address derivation
    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        if (_tokenA != _tokenB) { revert IdenticalAddresses(); }
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        if (token0 != address(0)) { revert ZeroAddress(); }
    }

    // Calculates the CREATE2 address for a pair without making any external calls
    function _pairFor(address _tokenA, address _tokenB) internal pure returns (address pair) {
        (address token0, address token1) = _sortTokens(_tokenA, _tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
        hex'ff',
        _SUSHI_V2_ROUTER.factory(),
        keccak256(abi.encodePacked(token0, token1)),
        hex'e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303' // NFTX init code hash
        )))));
    }

    // TODO: Remove _id once on-chain vault ID derivation is solved
    constructor(address _nft) payable {
        // Set target NFT collection for alignment
        _erc721 = IERC721(_nft);
        // Approve sending any NFT tokenId to NFTX Staking Zap contract
        _erc721.setApprovalForAll(address(_NFTX_STAKING_ZAP), true);
        // Max approve WETH to NFTX LP Staking contract
        IERC20(address(_WETH)).approve(address(_NFTX_LIQUIDITY_STAKING), type(uint256).max);
        // Setup liquidity helper
        _liqHelper = new UniswapV2LiquidityHelper(_SUSHI_V2_FACTORY, address(_SUSHI_V2_ROUTER), address(_WETH));
        // Derive _nftxInventory token contract
        _nftxInventory = IERC20(_NFTX_VAULT_FACTORY.vaultsForAsset(address(_erc721))[0]);
        // Derive _vaultId
        _vaultId = INFTXVault(address(_nftxInventory)).vaultId();
        // Derive _nftxLiquidity LP contract
        _nftxLiquidity = IERC20(_pairFor(address(_WETH), address(_nftxInventory)));
    }

    // Wrap ETH into WETH
    function _wrap(uint256 _eth) internal {
        if (address(this).balance < _eth) { revert InsufficientBalance(); }
        _WETH.deposit{ value: _eth }();
    }

    function _addInventory(uint256[] calldata _tokenIds) internal returns (uint256) {
        // Verify ownership of _tokenIds
        if (_erc721.balanceOf(address(this)) < _tokenIds.length) { revert InsufficientBalance(); }
        for (uint i; i < _tokenIds.length;) {
            if (_erc721.ownerOf(_tokenIds[i]) != address(this)) { revert IncorrectOwner(); }
            unchecked { ++i; }
        }
        uint256 inventoryBal = _checkBalance(_nftxInventory);
        _NFTX_STAKING_ZAP.provideInventory721(_vaultId, _tokenIds);
        uint256 inventoryBalDiff = _checkBalance(_nftxInventory) - inventoryBal;
        if (inventoryBalDiff == 0) { revert BalanceDidntIncrease(address(_nftxInventory)); }
        return (inventoryBalDiff);
    }

    // TODO: Add ERC721 NFTs and WETH to NFTX NFTWETH SLP
    function _addLiquidity(uint256[] calldata _tokenIds) internal returns (uint256) {
        // Verify ownership of _tokenIds
        if (_erc721.balanceOf(address(this)) < _tokenIds.length) { revert InsufficientBalance(); }
        for (uint i; i < _tokenIds.length;) {
            if (_erc721.ownerOf(_tokenIds[i]) != address(this)) { revert IncorrectOwner(); }
            unchecked { ++i; }
        }
        // TODO:
        // 1) Calculate WETH required to add number of tokens
        // 2) Check if WETH is enough, if not, WETH + ETH and handle conversion, else revert
        // 3) Call addLiquidity721()
        return (0);
    }

    // Add any amount of ETH, WETH, and NFTX Inventory tokens to NFTWETH SLP
    function _deepenLiquidity(
        uint112 _eth, 
        uint112 _weth, 
        uint112 _nftxInv
    ) internal returns (uint256) {
        // Verify balance of all inputs
        if (_checkBalance(IERC20(address(0))) < _eth ||
            _checkBalance(IERC20(address(_WETH))) < _weth ||
            _checkBalance(_nftxInventory) < _nftxInv
        ) { revert InsufficientBalance(); }
        // Wrap any ETH into WETH
        if (_eth > 0) {
            _wrap(uint256(_eth));
            _weth += _eth;
            _eth = 0;
        }
        // Supply any ratio of WETH and NFTX Inventory tokens in return for max SLP tokens
        uint256 liquidity = _liqHelper.swapAndAddLiquidityTokenAndToken(
            address(_WETH),
            address(_nftxInventory),
            _weth,
            _nftxInv,
            1,
            address(this)
        );
        return (liquidity);
    }
}