// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "solady/auth/Ownable.sol";
import "solady/utils/FixedPointMathLib.sol";
import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "v2-core/interfaces/IUniswapV2Pair.sol";
import "liquidity-helper/UniswapV2LiquidityHelper.sol";

interface INFTXFactory {
    function vaultsForAsset(address asset) external view returns (address[] memory);
}

interface INFTXVault {
    function vaultId() external view returns (uint256);
}

interface INFTXInventoryStaking {
    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;
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

library OrderStructs {

    // Reservoir
    struct ExecutionInfo {
        address module;
        bytes data;
        uint256 value;
    }

    // ISeaport.AdvancedOrder
    struct AdvancedOrder {
        OrderParameters parameters;
        uint120 numerator;
        uint120 denominator;
        bytes signature;
        bytes extraData;
    }

    struct OrderParameters {
        address offerer;
        address zone;
        OfferItem[] offer;
        ConsiderationItem[] consideration;
        OrderType orderType;
        uint256 startTime;
        uint256 endTime;
        bytes32 zoneHash;
        uint256 salt;
        bytes32 conduitKey;
        uint256 totalOriginalConsiderationItems;
    }

    struct OfferItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
    }

    struct ConsiderationItem {
        ItemType itemType;
        address token;
        uint256 identifierOrCriteria;
        uint256 startAmount;
        uint256 endAmount;
        address recipient;
    }

    enum OrderType {
        FULL_OPEN,
        PARTIAL_OPEN,
        FULL_RESTRICTED,
        PARTIAL_RESTRICTED
    }

    enum ItemType {
        NATIVE,
        ERC20,
        ERC721,
        ERC1155,
        ERC721_WITH_CRITERIA,
        ERC1155_WITH_CRITERIA
    }

    // ETHListingParams
    struct ETHListingParams {
        address fillTo;
        address refundTo;
        bool revertIfIncomplete;
        // The total amount of ETH to be provided when filling
        uint256 amount;
    }

    // Fee
    struct Fee {
        address recipient;
        uint256 amount;
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
    address constant internal _SEAPORTV15MODULE = 0xF645877ab54E5856F39dC90425ae21748F52B5d4;
    address constant internal _SUSHI_V2_FACTORY = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    IUniswapV2Router02 constant internal _SUSHI_V2_ROUTER = IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    UniswapV2LiquidityHelper internal _liqHelper;

    INFTXFactory constant internal _NFTX_VAULT_FACTORY = INFTXFactory(0xBE86f647b167567525cCAAfcd6f881F1Ee558216);
    INFTXInventoryStaking constant internal _NFTX_INVENTORY_STAKING = INFTXInventoryStaking(0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);
    INFTXLPStaking constant internal _NFTX_LIQUIDITY_STAKING = INFTXLPStaking(0x688c3E4658B5367da06fd629E41879beaB538E37);
    INFTXStakingZap constant internal _NFTX_STAKING_ZAP = INFTXStakingZap(0xdC774D5260ec66e5DD4627E1DD800Eff3911345C);
    
    IERC721 internal immutable _erc721; // ERC721 token
    IERC20 internal immutable _nftxInventory; // NFTX NFT token
    IERC20 internal immutable _nftxLiquidity; // NFTX NFTWETH token
    uint256 internal immutable _vaultId;

    // Sort token addresses for LP address derivation
    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        if (_tokenA == _tokenB) { revert IdenticalAddresses(); }
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        if (token0 == address(0)) { revert ZeroAddress(); }
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
        _nftxLiquidity = IERC20(_pairFor(address(_WETH), address(_nftxInventory)));
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
    function checkBalanceNFTXInventory() public view returns (uint256) { return (_nftxInventory.balanceOf(address(this))); }
    function checkBalanceNFTXLiquidity() public view returns (uint256) { return (_nftxLiquidity.balanceOf(address(this))); }

    // Wrap ETH into WETH
    function wrap(uint256 _eth) public onlyOwner {
        _WETH.deposit{ value: _eth }();
    }

    // TODO: Parse Reservoir API calldata to get Seaport calldata
    function decodeReservoirCalldata(bytes calldata data) public pure returns (OrderStructs.ExecutionInfo memory) {
        // Decode calldata to Reservoir's ExecutionInfo struct
        OrderStructs.ExecutionInfo memory reservoir = abi.decode(data[4:], (OrderStructs.ExecutionInfo));
        // Return struct data
        return (reservoir);
    }

    /* TODO: Decode NFT order calldata to retrieve NFT collection address and order price
    function decodeSeaportCalldata(bytes calldata data) public pure returns (
        OrderStructs.AdvancedOrder memory order,
        OrderStructs.ETHListingParams memory params,
        OrderStructs.Fee[] memory fees
    ) {
        // Track offset as calldata is parsed, also skip function selector
        uint256 offset = 4;

        // Decode AdvancedOrder struct, starting with OrderParameters internal struct
        order.parameters.offerer = abi.decode(data[offset:], (address));
        order.parameters.zone = abi.decode(data[offset + 32:], (address));
        offset += 64;

        // Decode offer array in OrderParameters struct
        uint256 offerItemsLength = abi.decode(data[offset:], (uint256));
        order.parameters.offer = new OrderStructs.OfferItem[](offerItemsLength);
        offset += 32;

        for (uint256 i = 0; i < offerItemsLength; i++) {
            order.parameters.offer[i].itemType = OrderStructs.ItemType(uint8(abi.decode(data[offset:], (uint256))));
            order.parameters.offer[i].token = abi.decode(data[offset + 32:], (address));
            order.parameters.offer[i].identifierOrCriteria = abi.decode(data[offset + 64:], (uint256));
            order.parameters.offer[i].startAmount = abi.decode(data[offset + 96:], (uint256));
            order.parameters.offer[i].endAmount = abi.decode(data[offset + 128:], (uint256));
            offset += 160;
        }

        // Decode consideration array in OrderParameters struct
        uint256 considerationItemsLength = abi.decode(data[offset:], (uint256));
        order.parameters.consideration = new OrderStructs.ConsiderationItem[](considerationItemsLength);
        offset += 32;

        for (uint256 i = 0; i < considerationItemsLength; i++) {
            order.parameters.consideration[i].itemType = OrderStructs.ItemType(uint8(abi.decode(data[offset:], (uint256))));
            order.parameters.consideration[i].token = abi.decode(data[offset + 32:], (address));
            order.parameters.consideration[i].identifierOrCriteria = abi.decode(data[offset + 64:], (uint256));
            order.parameters.consideration[i].startAmount = abi.decode(data[offset + 96:], (uint256));
            order.parameters.consideration[i].endAmount = abi.decode(data[offset + 128:], (uint256));
            order.parameters.consideration[i].recipient = abi.decode(data[offset + 160:], (address));
            offset += 192;
        }

        order.parameters.orderType = OrderStructs.OrderType(uint8(abi.decode(data[offset:], (uint256))));
        order.parameters.startTime = abi.decode(data[offset + 32:], (uint256));
        order.parameters.endTime = abi.decode(data[offset + 64:], (uint256));
        order.parameters.zoneHash = abi.decode(data[offset + 96:], (bytes32));
        order.parameters.salt = abi.decode(data[offset + 128:], (uint256));
        order.parameters.conduitKey = abi.decode(data[offset + 160:], (bytes32));
        order.parameters.totalOriginalConsiderationItems = abi.decode(data[offset + 192:], (uint256));
        offset += 224;

        order.numerator = uint120(abi.decode(data[offset:], (uint256)));
        order.denominator = uint120(abi.decode(data[offset + 32:], (uint256)));
        order.signature = abi.decode(data[offset + 64:], (bytes));
        order.extraData = abi.decode(data[offset + 96:], (bytes));

        offset += 128;

        // Decode ETHListingParams struct
        params.fillTo = abi.decode(data[offset:], (address));
        params.refundTo = abi.decode(data[offset + 32:], (address));
        params.revertIfIncomplete = abi.decode(data[offset + 64:], (bool));
        params.amount = abi.decode(data[offset + 96:], (uint256));

        offset += 128;

        // Decode Fees struct array
        uint256 feesArrayLength = abi.decode(data[offset:], (uint256));
        offset += 32;

        fees = new OrderStructs.Fee[](feesArrayLength);
        for (uint256 i = 0; i < feesArrayLength; i++) {
            fees[i].recipient = abi.decode(data[offset:], (address));
            fees[i].amount = abi.decode(data[offset + 32:], (uint256));
            offset += 64;
        }
    }

    // TODO: Execute floor buys
    function acceptETHListings(bytes calldata data) public onlyOwner {
        // Step 1: Parse calldata into structs to retrieve order info
        OrderStructs.AdvancedOrder memory order;
        OrderStructs.ETHListingParams memory params;
        OrderStructs.Fee[] memory fees;
        (order, params, fees) = decodeSeaportCalldata(data);
        // Step 2: Verify order is for aligned NFT collection, revert if not
        for (uint256 i; i < order.parameters.offer.length;) {
            if (order.parameters.offer[i].token != address(_erc721)) { revert AlignedAsset(); }
            unchecked { ++i; }
        }
        // Step 3: Retrieve floor price with _estimateFloor and calculate upper bound
        uint256 floorEstimate = _estimateFloor();
        uint256 upperBound = FixedPointMathLib.fullMulDiv(floorEstimate, 11000, 10000);
        // Step 4: Verify order payment for each NFT isn't more than 10% over floor, revert if not
        // TODO: Determine params.amount is for all tokens being purchased or not, initially assuming it is for all
        if ((params.amount / order.parameters.offer.length) > upperBound) { revert PriceTooHigh(); }
        // Step 5: Process order as long as all token purchases are within 10% of floor to prevent abuse
        (bool success, ) = _SEAPORTV15MODULE.call{ value: params.amount }(data);
        if (!success) { revert SeaportPurchaseFailed(); }
    }
    // Overload using the OrderStructs directly to avoid paying for parsing
    function acceptETHListings(
        OrderStructs.AdvancedOrder calldata order,
        OrderStructs.ETHListingParams calldata params,
        OrderStructs.Fee[] calldata fees
    ) public onlyOwner {
        // Step 1: Verify order is for aligned NFT collection, revert if not
        for (uint256 i; i < order.parameters.offer.length;) {
            if (order.parameters.offer[i].token != address(_erc721)) { revert AlignedAsset(); }
            unchecked { ++i; }
        }
        // Step 2: Retrieve floor price with _estimateFloor and calculate upper bound
        uint256 floorEstimate = _estimateFloor();
        uint256 upperBound = FixedPointMathLib.fullMulDiv(floorEstimate, 11000, 10000);
        // Step 3: Verify order payment for each NFT isn't more than 10% over floor, revert if not
        // TODO: Determine params.amount is for all tokens being purchased or not, initially assuming it is for all
        if ((params.amount / order.parameters.offer.length) > upperBound) { revert PriceTooHigh(); }
        // Step 4: Process order as long as all token purchases are within 10% of floor to prevent abuse
        string memory FUNC_SELECTOR = 
            "acceptETHListings(((address,address,(uint8,address,uint256,uint256,uint256)[],(uint8,address,uint256,uint256,uint256,address)[],uint8,uint256,uint256,bytes32,uint256,bytes32,uint256),uint120,uint120,bytes,bytes),(address,address,bool,uint256),(address,uint256)[])";
        bytes memory data = abi.encodeWithSignature(FUNC_SELECTOR, order, params, fees);
        (bool success, ) = _SEAPORTV15MODULE.call{ value: params.amount }(data);
        if (!success) { revert SeaportPurchaseFailed(); }
    } */

    // Add NFTs to NFTX Inventory
    // NOTE: This action imposes a timelock at NFTX
    function addInventory(uint256[] calldata _tokenIds) public onlyOwner {
        _NFTX_STAKING_ZAP.provideInventory721(_vaultId, _tokenIds);
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

    // Rescue tokens from vault and/or liq helper
    // Rescue ETH/ERC20 (use address(0) for ETH)
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
    fallback() external payable { }
}