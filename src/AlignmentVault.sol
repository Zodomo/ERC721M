// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
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
    function addLiquidity721(uint256 vaultId, uint256[] calldata ids, uint256 minWethIn, uint256 wethIn) external returns (uint256);
}

contract AlignmentVault is Ownable, Initializable {

    error InsufficientBalance();
    error InvalidVaultId();
    error AlignedAsset();
    error NoNFTXVault();
    error ZeroAddress();
    error ZeroValues();

    IWETH constant internal _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address constant internal _SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Router02 constant internal _SUSHI_V2_ROUTER = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    UniswapV2LiquidityHelper internal _liqHelper;

    INFTXFactory constant internal _NFTX_VAULT_FACTORY = INFTXFactory(0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    INFTXLPStaking constant internal _NFTX_LIQUIDITY_STAKING = INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);
    INFTXStakingZap constant internal _NFTX_STAKING_ZAP = INFTXStakingZap(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    
    IERC721 public erc721; // ERC721 token
    IERC20 public nftxInventory; // NFTX NFT token
    IERC20 public nftxLiquidity; // NFTX NFTWETH token
    uint256 public vaultId;
    uint256[] public nftsHeld;

    constructor() payable { }
    function initialize(address _erc721, uint256 _vaultId) external initializer {
        // Initialize contract ownership
        _initializeOwner(msg.sender);
        // Set target NFT collection for alignment
        erc721 = IERC721(_erc721);
        // Approve sending any NFT tokenId to NFTX Staking Zap contract
        erc721.setApprovalForAll(address(_NFTX_STAKING_ZAP), true);
        // Max approve WETH to NFTX LP Staking contract
        IERC20(address(_WETH)).approve(address(_NFTX_STAKING_ZAP), type(uint256).max);
        // Derive vaultId if necessary
        // Loop index is set to max value in order to determine if a match was found
        uint256 index = type(uint256).max;
        // If no vaultId is specified, use default (initial) vault
        if (_vaultId == 0) { index = 0; }
        else {
            // Retrieve all vaults
            address[] memory vaults = _NFTX_VAULT_FACTORY.vaultsForAsset(_erc721);
            if (vaults.length == 0) { revert NoNFTXVault(); }
            for (uint256 i; i < vaults.length;) {
                if (INFTXVault(vaults[i]).vaultId() == _vaultId) {
                    index = i;
                    vaultId = _vaultId;
                    break;
                }
                unchecked { ++i; }
            }
            if (index == type(uint256).max) { revert InvalidVaultId(); }
        }
        // Derive nftxInventory token contract and vaultId if necessary
        address _nftxInventory = _NFTX_VAULT_FACTORY.vaultsForAsset(_erc721)[index];
        if (_vaultId == 0) { vaultId = uint64(INFTXVault(_nftxInventory).vaultId()); }
        nftxInventory = IERC20(_nftxInventory);
        // Derive nftxLiquidity LP contract
        nftxLiquidity = IERC20(UniswapV2Library.pairFor(
            _SUSHI_V2_FACTORY,
            address(_WETH),
            _nftxInventory
        ));
        // Approve sending nftxLiquidity to NFTX LP Staking contract
        nftxLiquidity.approve(address(_NFTX_LIQUIDITY_STAKING), type(uint256).max);
        // Setup liquidity helper
        _liqHelper = new UniswapV2LiquidityHelper(_SUSHI_V2_FACTORY, address(_SUSHI_V2_ROUTER), address(_WETH));
        // Approve tokens to liquidity helper
        IERC20(address(_WETH)).approve(address(_liqHelper), type(uint256).max);
        nftxInventory.approve(address(_liqHelper), type(uint256).max);
    }
    function disableInitializers() external onlyOwner { _disableInitializers(); }
    
    // Use NFTX SLP for aligned NFT as floor price oracle and for determining WETH required for adding liquidity
    // Using NFTX as a price oracle is intentional, as Chainlink/others weren't sufficient or too expensive
    function _estimateFloor() internal view returns (uint256) {
        // Retrieve SLP reserves to calculate price of NFT token in WETH
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(address(nftxLiquidity)).getReserves();
        // Calculate value of NFT spot in WETH using SLP reserves values
        uint256 spotPrice;
        // Reverse reserve values if token1 isn't WETH
        if (IUniswapV2Pair(address(nftxLiquidity)).token1() != address(_WETH)) {
            spotPrice = ((10**18 * uint256(reserve0)) / uint256(reserve1));
        } else { spotPrice = ((10**18 * uint256(reserve1)) / uint256(reserve0)); }
        return (spotPrice);
    }

    function alignLiquidity() external onlyOwner {
        // Cache vaultId to save gas
        uint256 _vaultId = vaultId;
        // Wrap all ETH, if any
        uint256 balance = address(this).balance;
        if (balance > 0) { _WETH.deposit{ value: balance }(); }
        // Update balance to total WETH
        balance = IERC20(address(_WETH)).balanceOf(address(this));

        // Retrieve NFTs held
        uint256[] memory inventory = nftsHeld;
        uint256 length = inventory.length;
        // Process adding liquidity using as many NFTs as the ETH balance allows
        if (length > 0) {
            // Retrieve NFTX LP price for 1 full inventory token
            uint256 floorPrice = _estimateFloor();
            // Determine how many NFTs we can afford to add to LP
            // Add 1 to floorPrice in order to resolve liquidity rounding issue
            uint256 addQty = balance / ((floorPrice + 1) * length);
            // Add NFTs to LP if we can afford to
            if (addQty > 0) {
                // Calculate exact ETH to add to LP with NFTs
                uint256 requiredEth = addQty * (floorPrice + 1);
                // Iterate through inventory for as many NFTs as we can afford to add
                uint256[] memory tokenIds = new uint256[](addQty);
                for (uint256 i = length; i > length - addQty;) {
                    tokenIds[i - addQty] = inventory[i - 1];
                    nftsHeld.pop();
                    unchecked { --i; }
                }
                // Stake NFTs and ETH, approvals were given in initializeVault()
                _NFTX_STAKING_ZAP.addLiquidity721(_vaultId, tokenIds, 1, requiredEth);
            }
        }

        // Deepen LP with remaining ETH
        // Retrieve updated balance in case any NFTs were added to LP
        balance = IERC20(address(_WETH)).balanceOf(address(this));
        // Process rebalancing any remaining ETH and inventory tokens to add to LP
        _liqHelper.swapAndAddLiquidityTokenAndToken(
            address(_WETH),
            address(nftxInventory),
            uint112(balance),
            uint112(nftxInventory.balanceOf(address(this))),
            1,
            address(this)
        );

        // Stake liquidity tokens
        uint256 liquidity = nftxLiquidity.balanceOf(address(this));
        _NFTX_LIQUIDITY_STAKING.deposit(_vaultId, liquidity);
    }

    // Claim NFTWETH SLP yield
    function claimYield(address _recipient) public onlyOwner {
        // Claim SLP rewards
        _NFTX_LIQUIDITY_STAKING.claimRewards(vaultId);
        // Determine yield amount
        uint256 yield = nftxInventory.balanceOf(address(this));
        // If no yield, end execution to save gas
        if (yield == 0) { return; }
        // Send 50% to recipient
        uint256 amount = yield / 2;
        nftxInventory.transfer(_recipient, amount);
        // Send yield remainder and any ETH to LP
        _liqHelper.swapAndAddLiquidityTokenAndToken(
            address(_WETH),
            address(nftxInventory),
            uint112(IERC20(address(_WETH)).balanceOf(address(this))),
            uint112(yield - amount),
            1,
            address(this)
        );
    }

    // Compound all NFTWETH SLP yield into LP
    function compoundYield() public onlyOwner {
        // Claim SLP rewards
        _NFTX_LIQUIDITY_STAKING.claimRewards(vaultId);
        // Determine yield amount
        uint256 yield = nftxInventory.balanceOf(address(this));
        // If no yield, end execution to save gas
        if (yield == 0) { return; }
        // Send yield and any ETH to LP
        _liqHelper.swapAndAddLiquidityTokenAndToken(
            address(_WETH),
            address(nftxInventory),
            uint112(IERC20(address(_WETH)).balanceOf(address(this))),
            uint112(yield),
            1,
            address(this)
        );
    }

    // Rescue tokens from vault and/or liq helper (use address(0) for ETH)
    function rescueERC20(address _token, address _to) public onlyOwner returns (uint256) {
        // If address(0), rescue ETH from liq helper to vault
        if (_token == address(0)) {
            _liqHelper.emergencyWithdrawEther();
            uint256 balance = address(this).balance;
            if (balance > 0) { _WETH.deposit{ value: balance }(); }
            return (balance);
        }
        // If nftxInventory or nftxLiquidity, rescue from liq helper to vault
        else if (_token == address(_WETH) || 
            _token == address(nftxInventory) ||
            _token == address(nftxLiquidity)) {
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
        if (address(erc721) == _address) { revert AlignedAsset(); }
        // Otherwise, attempt to send to recipient
        else { IERC721(_address).transferFrom(address(this), _to, _tokenId); }
    }

    // Receive logic
    receive() external payable { _WETH.deposit{ value: msg.value }(); }
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes calldata
    ) external virtual returns (bytes4) {
        nftsHeld.push(_tokenId);
        return AlignmentVault.onERC721Received.selector;
    }
}