// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "liquidity-helper/UniswapV2LiquidityHelper.sol";

interface INFTXFactory {
    function vaultsForAsset(address asset) external view returns (address[] memory);
}

interface INFTXVault {
    function vaultId() external view returns (uint256);
}

interface INFTXLPStaking {
    function deposit(uint256 vaultId, uint256 amount) external;
    function claimRewards(uint256 vaultId) external;
}

interface INFTXStakingZap {
    function provideInventory721(uint256 vaultId, uint256[] calldata tokenIds) external;
    function addLiquidity721(uint256 vaultId, uint256[] calldata ids, uint256 minWethIn, uint256 wethIn) external returns (uint256);
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract AlignmentVault is Ownable, ERC721TokenReceiver {

    error InsufficientBalance();
    error IdenticalAddresses();
    error ZeroAddress();
    error ZeroValues();
    error NFTXVaultDoesntExist();
    error AlignedAsset();
    error PriceTooHigh();
    error SeaportPurchaseFailed();

    IWETH constant internal _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant internal _SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Router02 constant internal _SUSHI_V2_ROUTER = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    UniswapV2LiquidityHelper internal _liqHelper;

    INFTXFactory constant internal _NFTX_VAULT_FACTORY = INFTXFactory(0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    INFTXLPStaking constant internal _NFTX_LIQUIDITY_STAKING = INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);
    INFTXStakingZap constant internal _NFTX_STAKING_ZAP = INFTXStakingZap(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    
    IERC721 internal immutable _erc721; // ERC721 token
    IERC20 internal immutable _nftxInventory; // NFTX NFT token
    IERC20 internal immutable _nftxLiquidity; // NFTX NFTWETH token
    uint256 internal immutable _vaultId;

    // Use NFTX SLP for aligned NFT as floor price oracle and for determining WETH required for adding liquidity
    // Using NFTX as a price oracle is intentional, as Chainlink/others weren't sufficient or too expensive
    function _estimateFloor() internal view returns (uint256) {
        // Retrieve SLP reserves to calculate price of NFT token in WETH
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(address(_nftxLiquidity)).getReserves();
        // Calculate value of NFT spot in WETH using SLP reserves values
        uint256 spotPrice;
        // Reverse reserve values if token1 isn't WETH
        if (IUniswapV2Pair(address(_nftxLiquidity)).token1() != address(_WETH)) {
            spotPrice = ((10**18 * uint256(reserve0)) / uint256(reserve1));
        } else { spotPrice = ((10**18 * uint256(reserve1)) / uint256(reserve0)); }
        return (spotPrice);
    }

    constructor(address _nft) payable {
        // Initialize contract ownership
        _initializeOwner(msg.sender);
        // Set target NFT collection for alignment
        _erc721 = IERC721(_nft);
        // Approve sending any NFT tokenId to NFTX Staking Zap contract
        _erc721.setApprovalForAll(address(_NFTX_STAKING_ZAP), true);
        // Max approve WETH to NFTX LP Staking contract
        IERC20(address(_WETH)).approve(address(_NFTX_STAKING_ZAP), type(uint256).max);
        // Derive _nftxInventory token contract
        _nftxInventory = IERC20(address(_NFTX_VAULT_FACTORY.vaultsForAsset(address(_erc721))[0]));
        // Revert if NFTX vault doesn't exist
        if (address(_nftxInventory) == address(0)) { revert NFTXVaultDoesntExist(); }
        // Derive _nftxLiquidity LP contract
        _nftxLiquidity = IERC20(UniswapV2Library.pairFor(
            _SUSHI_V2_FACTORY,
            address(_WETH),
            address(_nftxInventory)
        ));
        // Approve sending _nftxLiquidity to NFTX LP Staking contract
        _nftxLiquidity.approve(address(_NFTX_LIQUIDITY_STAKING), type(uint256).max);
        // Derive _vaultId
        _vaultId = INFTXVault(address(_nftxInventory)).vaultId();
        // Setup liquidity helper
        _liqHelper = new UniswapV2LiquidityHelper(_SUSHI_V2_FACTORY, address(_SUSHI_V2_ROUTER), address(_WETH));
        // Approve tokens to liquidity helper
        IERC20(address(_WETH)).approve(address(_liqHelper), type(uint256).max);
        _nftxInventory.approve(address(_liqHelper), type(uint256).max);
    }

    // Check token balances
    function checkBalanceNFT() public view returns (uint256) { return (_erc721.balanceOf(address(this))); }
    function checkBalanceETH() public view returns (uint256) { return (address(this).balance); }
    function checkBalanceWETH() public view returns (uint256) { return (IERC20(address(_WETH)).balanceOf(address(this))); }
    function checkBalanceNFTXLiquidity() public view returns (uint256) { return (_nftxLiquidity.balanceOf(address(this))); }

    // Wrap ETH into WETH
    function wrap(uint256 _eth) public onlyOwner {
        _WETH.deposit{ value: _eth }();
    }

    // Add NFTs and WETH to NFTX NFTWETH SLP
    function addLiquidity(uint256[] calldata _tokenIds) public onlyOwner returns (uint256) {
        // Store _tokenIds.length in memory to save gas
        uint256 length = _tokenIds.length;
        // Retrieve WETH balance
        uint256 wethBal = IERC20(address(_WETH)).balanceOf(address(this));
        // Calculate value of NFT in WETH using SLP reserves values
        uint256 ethPerNFT = _estimateFloor();
        // Determine total amount of WETH required using _tokenIds length
        uint256 totalRequiredWETH = ethPerNFT * length;
        // NOTE: Add 1 wei per token if _tokenIds > 1 to resolve Uniswap V2 liquidity issues
        if (length > 1) { totalRequiredWETH += (length * 1); }
        // Check if contract has enough WETH on hand
        if (wethBal < totalRequiredWETH) {
            // If not, check to see if WETH + ETH balance is enough
            if ((wethBal + address(this).balance) < totalRequiredWETH) {
                // If there just isn't enough ETH, revert
                revert InsufficientBalance();
            } else {
                // If there is enough WETH + ETH, wrap the necessary ETH
                uint256 amountToWrap = totalRequiredWETH - wethBal;
                wrap(amountToWrap);
            }
        }
        // Add NFT + WETH liquidity to NFTX and return amount of SLP deposited
        return (_NFTX_STAKING_ZAP.addLiquidity721(_vaultId, _tokenIds, 1, totalRequiredWETH));
    }

    // Add any amount of ETH, WETH, and NFTX Inventory tokens to NFTWETH SLP
    function deepenLiquidity(
        uint112 _eth, 
        uint112 _weth, 
        uint112 _nftxInv
    ) public onlyOwner returns (uint256) {
        // Verify balance of all inputs
        if (address(this).balance < _eth ||
            IERC20(address(_WETH)).balanceOf(address(this)) < _weth ||
            _nftxInventory.balanceOf(address(this)) < _nftxInv
        ) { revert InsufficientBalance(); }
        // Wrap any ETH into WETH
        if (_eth > 0) {
            wrap(uint256(_eth));
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

    // Stake NFTWETH SLP in NFTX
    function stakeLiquidity() public onlyOwner returns (uint256 liquidity) {
        // Check available SLP balance
        liquidity = _nftxLiquidity.balanceOf(address(this));
        // Stake entire balance
        _NFTX_LIQUIDITY_STAKING.deposit(_vaultId, liquidity);
    }

    // Claim NFTWETH SLP rewards
    function claimRewards(address _recipient) public onlyOwner {
        // Retrieve balance to diff against
        uint256 invTokenBal = _nftxInventory.balanceOf(address(this));
        // Claim SLP rewards
        _NFTX_LIQUIDITY_STAKING.claimRewards(_vaultId);
        // Determine reward amount
        uint256 reward = _nftxInventory.balanceOf(address(this)) - invTokenBal;
        // Send 50% to recipient, remainder stored in contract
        _nftxInventory.transfer(_recipient, reward / 2);
    }

    // Compound NFTWETH SLP rewards, optionally include ETH/WETH
    function compoundRewards(uint112 _eth, uint112 _weth) public onlyOwner {
        // Retrieve balance to diff against
        uint112 invTokenBal = uint112(_nftxInventory.balanceOf(address(this)));
        // Claim SLP rewards
        _NFTX_LIQUIDITY_STAKING.claimRewards(_vaultId);
        // Determine reward amount
        uint112 reward = uint112(_nftxInventory.balanceOf(address(this))) - invTokenBal;
        if (_eth == 0 && _weth == 0 && reward == 0) { revert ZeroValues(); }
        // Deepen liquidity with entire reward amount and any optional ETH/WETH balance
        deepenLiquidity(_eth, _weth, reward);
    }

    // Rescue tokens from vault and/or liq helper (use address(0) for ETH)
    function rescueERC20(address _token, address _to) public onlyOwner returns (uint256) {
        // If address(0), rescue ETH from liq helper to vault
        if (_token == address(0)) {
            uint256 balance = address(this).balance;
            _liqHelper.emergencyWithdrawEther();
            return (address(this).balance - balance);
        }
        // If _nftxInventory or _nftxLiquidity, rescue from liq helper to vault
        else if (_token == address(_WETH) || 
            _token == address(_nftxInventory) ||
            _token == address(_nftxLiquidity)) {
                uint256 balance = IERC20(_token).balanceOf(address(this));
                _liqHelper.emergencyWithdrawErc20(_token);
                uint256 balanceDiff = IERC20(_token).balanceOf(address(this)) - balance;
                return (balanceDiff);
        }
        // If any other token, rescue from liq helper and/or vault and send to recipient
        else {
            // Retrieve tokens from liq helper, if any
            if (IERC20(_token).balanceOf(address(_liqHelper)) > 0) {
                _liqHelper.emergencyWithdrawErc20(_token);
            }
            // Check updated balance
            uint256 balance = IERC20(_token).balanceOf(address(this));
            // Send entire balance to recipient
            IERC20(_token).transfer(_to, balance);
            return (balance);
        }
    }
    function rescueERC721(
        address _address, 
        address _to,
        uint256 _tokenId
    ) public onlyOwner {
        // If _address is for the aligned collection, revert
        if (address(_erc721) == _address) { revert AlignedAsset(); }
        // Otherwise, attempt to send to recipient
        else { IERC721(_address).transferFrom(address(this), _to, _tokenId); }
    }

    // Receive logic
    receive() external payable { }
}