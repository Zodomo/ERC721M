//// ERC721M.sol

interface IFactory {
    function ownershipUpdate(address _newOwner) external;
}

error LockedAsset();
error NotLocked();
error NotUnlocked();
error NotBurnable();
error InsufficientLock();
error InsufficientAssets();

event ConfigureMintBurn(
    address indexed asset,
    bool indexed status,
    int64 indexed allocation,
    uint256 tokenBalance,
    uint256 price
);
event ConfigureMintLock(
    address indexed asset,
    bool indexed status,
    int64 indexed allocation,
    uint40 timelock,
    uint256 tokenBalance,
    uint256 price
);
event ConfigureMintWithAssets(
    address indexed asset,
    bool indexed status,
    int64 indexed allocation,
    uint256 tokenBalance,
    uint256 price
);

struct MinterInfo {
    uint256 amount;
    uint256[] amounts;
    uint40[] timelocks;
}

mapping(address => MintInfo) public mintBurnInfo;
mapping(address => MintInfo) public mintLockInfo;
mapping(address => MintInfo) public mintWithAssetsInfo;
mapping(address => mapping(address => MinterInfo)) public burnerInfo;
mapping(address => mapping(address => MinterInfo)) public lockerInfo;

// NOTE: Must set factory address if factory is to be notified of ownership changes
address public constant factory = address(0);

// Ownership change overrides to callback into factory to notify frontend
function transferOwnership(address _newOwner) public payable override onlyOwner {
    address _factory = factory;
    if (_factory != address(0)) { IFactory(_factory).ownershipUpdate(_newOwner); }
    super.transferOwnership(_newOwner);
}
function renounceOwnership() public payable override onlyOwner {
    address _factory = factory;
    if (_factory != address(0)) { IFactory(_factory).ownershipUpdate(address(0)); }
    super.renounceOwnership();
}

//// ERC721MFactory.sol

event OwnershipChanged(address indexed collection, address indexed owner);

modifier onlyCollection(address _collection) {
    if (contractDeployers[_collection] == address(0)) { revert NotDeployed(); }
    _;
}

function ownershipUpdate(address _newOwner) external onlyCollection(msg.sender) {
    emit OwnershipChanged(msg.sender, _newOwner);
}

//// AlignmentVault.sol

interface INFTXInventoryStaking {
    function deposit(uint256 vaultId, uint256 _amount) external;
    function withdraw(uint256 vaultId, uint256 _share) external;
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

address constant internal _SEAPORTV15MODULE = 0xF645877ab54E5856F39dC90425ae21748F52B5d4;
INFTXInventoryStaking constant internal _NFTX_INVENTORY_STAKING = INFTXInventoryStaking(0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);

// Sort token addresses for LP address derivation
function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
    if (_tokenA == _tokenB) { revert IdenticalAddresses(); }
    (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    if (token0 == address(0)) { revert ZeroAddress(); }
}

// Calculates the CREATE2 address for a pair without making any external calls
function _pairFor(address _tokenA, address _tokenB) internal pure returns (address pair) {
    (address token0, address token1) = UniswapV2Library.sortTokens(_tokenA, _tokenB);
    pair = address(uint160(uint256(keccak256(abi.encodePacked(
    hex'ff',
    _SUSHI_V2_ROUTER.factory(),
    keccak256(abi.encodePacked(token0, token1)),
    hex'e18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303' // NFTX init code hash
    )))));
}

// TODO: Parse Reservoir API calldata to get Seaport calldata
function decodeReservoirCalldata(bytes calldata data) public pure returns (OrderStructs.ExecutionInfo memory) {
    // Decode calldata to Reservoir's ExecutionInfo struct
    OrderStructs.ExecutionInfo memory reservoir = abi.decode(data[4:], (OrderStructs.ExecutionInfo));
    // Return struct data
    return (reservoir);
}

// TODO: Decode NFT order calldata to retrieve NFT collection address and order price
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
}

// Add NFTs to NFTX Inventory
// NOTE: This action imposes a timelock at NFTX
function addInventory(uint256[] calldata _tokenIds) public onlyOwner {
    _NFTX_STAKING_ZAP.provideInventory721(_vaultId, _tokenIds);
}