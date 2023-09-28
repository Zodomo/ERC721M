// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
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
    function addLiquidity721(uint256 vaultId, uint256[] calldata ids, uint256 minWethIn, uint256 wethIn)
        external
        returns (uint256);
}

/**
 * @title AlignmentVault
 * @notice This allows anything to send ETH to a vault for the purpose of permanently deepening the floor liquidity of a target NFT collection.
 * @notice While the liquidity is locked forever, the yield can be claimed indefinitely.
 * @dev You must initialize this contract once deployed! There is a factory for this, use it!
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, GitHub: Zodomo, Email: zodomo@proton.me)
 */
contract AlignmentVault is Ownable, Initializable {
    error InvalidVaultId();
    error AlignedAsset();
    error NoNFTXVault();
    error UnwantedNFT();

    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal constant _SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Router02 internal constant _SUSHI_V2_ROUTER =
        IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    INFTXFactory internal constant _NFTX_VAULT_FACTORY = INFTXFactory(0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    INFTXLPStaking internal constant _NFTX_LIQUIDITY_STAKING =
        INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);
    INFTXStakingZap internal constant _NFTX_STAKING_ZAP = INFTXStakingZap(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);

    UniswapV2LiquidityHelper internal _liqHelper; // Liquidity helper used to deepen NFTX SLP with any amount of tokens
    IERC721 public erc721; // ERC721 token
    IERC20 public nftxInventory; // NFTX NFT token
    IERC20 public nftxLiquidity; // NFTX NFTWETH token
    uint256 public vaultId; // NFTX vault Id
    uint256[] public nftsHeld; // Inventory of aligned erc721 NFTs stored in contract

    constructor() payable {}

    // Initializes all contract variables and NFTX integration
    function initialize(address _erc721, address _owner, uint256 _vaultId) external payable virtual initializer {
        // Initialize contract ownership
        _initializeOwner(_owner);
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
        if (_vaultId == 0) {
            index = 0;
        } else {
            // Retrieve all vaults
            address[] memory vaults = _NFTX_VAULT_FACTORY.vaultsForAsset(_erc721);
            // Revert if no vaults are returned
            if (vaults.length == 0) revert NoNFTXVault();
            // Search for vaultId
            for (uint256 i; i < vaults.length;) {
                if (INFTXVault(vaults[i]).vaultId() == _vaultId) {
                    index = i;
                    vaultId = _vaultId;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            // If vaultId wasn't found, revert
            if (index == type(uint256).max) revert InvalidVaultId();
        }
        // Derive nftxInventory token contract and vaultId if necessary
        address _nftxInventory = _NFTX_VAULT_FACTORY.vaultsForAsset(_erc721)[index];
        if (_vaultId == 0) vaultId = uint64(INFTXVault(_nftxInventory).vaultId());
        nftxInventory = IERC20(_nftxInventory);
        // Derive nftxLiquidity LP contract
        nftxLiquidity = IERC20(UniswapV2Library.pairFor(_SUSHI_V2_FACTORY, address(_WETH), _nftxInventory));
        // Approve sending nftxLiquidity to NFTX LP Staking contract
        nftxLiquidity.approve(address(_NFTX_LIQUIDITY_STAKING), type(uint256).max);
        // Setup liquidity helper
        _liqHelper = new UniswapV2LiquidityHelper(_SUSHI_V2_FACTORY, address(_SUSHI_V2_ROUTER), address(_WETH));
        // Approve tokens to liquidity helper
        IERC20(address(_WETH)).approve(address(_liqHelper), type(uint256).max);
        nftxInventory.approve(address(_liqHelper), type(uint256).max);
    }

    // Recommended to disable initialization once initialized.
    function disableInitializers() external payable virtual {
        _disableInitializers();
    }

    // renounceOwnership is overridden as it would render the vault useless
    function renounceOwnership() public payable virtual override {}

    // Use NFTX SLP for aligned NFT as floor price oracle and for determining WETH required for adding liquidity
    // Using NFTX as a price oracle is intentional, as Chainlink/others weren't sufficient or too expensive
    function _estimateFloor() internal view virtual returns (uint256) {
        // Retrieve SLP reserves to calculate price of NFT token in WETH
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(address(nftxLiquidity)).getReserves();
        // Calculate value of NFT spot in WETH using SLP reserves values
        uint256 spotPrice;
        // Reverse reserve values if token1 isn't WETH
        if (IUniswapV2Pair(address(nftxLiquidity)).token1() != address(_WETH)) {
            spotPrice = ((10 ** 18 * uint256(reserve0)) / uint256(reserve1));
        } else {
            spotPrice = ((10 ** 18 * uint256(reserve1)) / uint256(reserve0));
        }
        return (spotPrice);
    }

    // Automatically add NFTs to LP that can be afforded, sweep remaining ETH into LP, and stake at NFTX
    function alignLiquidity() external payable virtual onlyOwner {
        // Cache vaultId to save gas
        uint256 _vaultId = vaultId;
        // Wrap all ETH, if any
        uint256 balance = address(this).balance;
        if (balance > 0) _WETH.deposit{value: balance}();
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
            uint256 afford = balance / (floorPrice + 1);
            uint256 addQty;
            // If we can afford to add more than we have, add what we have, otherwise add what we can afford
            (afford >= length) ? addQty = length : addQty = afford;
            // Add NFTs to LP if we can afford to
            if (addQty > 0) {
                // Calculate exact ETH to add to LP with NFTs
                uint256 requiredEth = addQty * (floorPrice + 1);
                // Iterate through inventory for as many NFTs as we can afford to add
                uint256[] memory tokenIds = new uint256[](addQty);
                for (uint256 i; i < addQty;) {
                    tokenIds[i] = inventory[length - addQty + i];
                    nftsHeld.pop();
                    unchecked {
                        ++i;
                    }
                }
                // Stake NFTs and ETH, approvals were given in initializeVault()
                _NFTX_STAKING_ZAP.addLiquidity721(_vaultId, tokenIds, 1, requiredEth);
                // Update cached balance after adding NFTs to vault
                balance = IERC20(address(_WETH)).balanceOf(address(this));
            }
        }

        // Cache nftxInventory to prevent a double SLOAD
        uint256 nftxInvBal = nftxInventory.balanceOf(address(this));
        // Process rebalancing remaining ETH and inventory tokens (if any) to add to LP
        if (balance > 0 || nftxInvBal > 0) {
            _liqHelper.swapAndAddLiquidityTokenAndToken(
                address(_WETH), address(nftxInventory), uint112(balance), uint112(nftxInvBal), 1, address(this)
            );
        }

        // Stake liquidity tokens, if any
        uint256 liquidity = nftxLiquidity.balanceOf(address(this));
        if (liquidity > 0) _NFTX_LIQUIDITY_STAKING.deposit(_vaultId, liquidity);
    }

    // Claim NFTWETH SLP yield, yield is compounded if address(0) is provided
    function claimYield(address _recipient) external payable virtual onlyOwner {
        // Cache vaultId to save gas
        uint256 _vaultId = vaultId;
        // Claim SLP rewards
        _NFTX_LIQUIDITY_STAKING.claimRewards(_vaultId);
        // Determine yield amount
        uint256 yield = nftxInventory.balanceOf(address(this));
        // If no yield, end execution to save gas
        if (yield == 0) return;
        // If recipient is provided, send them 50%
        if (_recipient != address(0)) {
            uint256 amount;
            unchecked {
                amount = yield / 2;
                yield -= amount;
            }
            nftxInventory.transfer(_recipient, amount);
        }
        // Send all remaining yield to LP
        _liqHelper.swapAndAddLiquidityTokenAndToken(
            address(_WETH), address(nftxInventory), 0, uint112(yield), 1, address(this)
        );

        // Stake that LP
        uint256 liquidity = nftxLiquidity.balanceOf(address(this));
        _NFTX_LIQUIDITY_STAKING.deposit(_vaultId, liquidity);
    }

    // Check contract inventory for unsafe transfers of aligned NFTs so alignLiquidity() can see them
    function checkInventory(uint256[] memory _tokenIds) external payable virtual {
        // Cache nftsHeld to reduce SLOADs
        uint256[] memory inventory = nftsHeld;
        // Iterate through passed array
        for (uint256 i; i < _tokenIds.length;) {
            // Try check for ownership used in case token has been burned
            try erc721.ownerOf(_tokenIds[i]) {
                // If this address is the owner, see if it is in nftsHeld cached array
                if (erc721.ownerOf(_tokenIds[i]) == address(this)) {
                    bool noticed;
                    for (uint256 j; j < inventory.length;) {
                        // If NFT is found, end loop and iterate to next tokenId
                        if (inventory[j] == _tokenIds[i]) {
                            noticed = true;
                            break;
                        }
                        unchecked {
                            ++j;
                        }
                    }
                    // If tokenId wasn't in stored array, add it
                    if (!noticed) nftsHeld.push(_tokenIds[i]);
                }
            } catch {}
            unchecked {
                ++i;
            }
        }
    }

    // Rescue tokens from vault and/or liq helper (use address(0) for ETH), returns 0 for aligned assets
    function rescueERC20(address _token, address _to) external payable virtual onlyOwner returns (uint256) {
        // If address(0), rescue ETH from liq helper to vault
        if (_token == address(0)) {
            _liqHelper.emergencyWithdrawEther();
            uint256 balance = address(this).balance;
            if (balance > 0) _WETH.deposit{value: balance}();
            return (0);
        }
        // If WETH, nftxInventory, or nftxLiquidity, rescue from liq helper to vault
        else if (_token == address(_WETH) || _token == address(nftxInventory) || _token == address(nftxLiquidity)) {
            _liqHelper.emergencyWithdrawErc20(_token);
            return (0);
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
    
    // Retrieve non-aligned NFTs, but retain aligned NFTs
    function rescueERC721(address _token, address _to, uint256 _tokenId) external payable virtual onlyOwner {
        // If _address is for the aligned collection, revert
        if (address(erc721) == _token) revert AlignedAsset();
        // Otherwise, attempt to send to recipient
        else IERC721(_token).transferFrom(address(this), _to, _tokenId);
    }

    // Receive logic
    receive() external payable virtual {
        _WETH.deposit{value: msg.value}();
    }
    
    // Log only aligned NFTs stored in the contract, revert if sent other NFTs
    function onERC721Received(address, address, uint256 _tokenId, bytes calldata) external virtual returns (bytes4) {
        if (msg.sender == address(erc721)) nftsHeld.push(_tokenId);
        else revert UnwantedNFT();
        return AlignmentVault.onERC721Received.selector;
    }
}
