// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;


contract ERC721M {
    using SafeCastLib for uint256;
    using SafeCastLib for int256;

    error NotActive();
    error Underflow();
    error SpecialExceeded();
    
    error InsufficientBalance();

    event DiscountedMint(address indexed asset, address indexed to, uint64 indexed amount);
    event ConfigureMintDiscount(
        address indexed asset,
        bool indexed status,
        int64 indexed allocation,
        uint64 userMax,
        uint256 tokenBalance,
        uint256 price
    );

    struct MintInfo {
        bool active; // Mint discount status
        int64 supply; // Count of remaining discounted mints
        int64 allocated; // Total count of discounted mints issued for specific asset
        uint64 userMax; // Total count of discounted mints per user address
        uint256 mintPrice; // Mint rate for asset discount
        uint256 tokenBalance; // Required token balance to qualify for mint
    }

    mapping(address => MintInfo) public mintDiscountInfo;
    // msg.sender => asset address => count
    mapping(address => mapping(address => uint64)) public minterDiscountCount;

    // Discounted mint for owners of specific ERC20/721 tokens
    function mintDiscount(address _asset, address _to, uint64 _amount) external payable virtual mintable(_amount) {
        MintInfo memory info = mintDiscountInfo[_asset];
        // Check if discount is active by reading status and remaining discount supply
        if (!info.active || info.supply == 0) revert NotActive();
        // Determine if mint amount exceeds supply
        int64 amount = (uint256(_amount).toInt256()).toInt64();
        if (amount > info.supply) revert SpecialExceeded();
        if (_amount + minterDiscountCount[msg.sender][_asset] > info.userMax) revert SpecialExceeded();
        // Ensure holder balance of asset is sufficient
        if (IAsset(_asset).balanceOf(msg.sender) < info.tokenBalance) revert InsufficientBalance();
        if (_amount * info.mintPrice > msg.value) revert InsufficientPayment();
        // Update MintInfo
        unchecked {
            info.supply -= amount;
        }
        if (info.supply == 0) info.active = false;
        mintDiscountInfo[_asset] = info;
        // Process mint
        _mint(_to, uint256(_amount));
        emit DiscountedMint(_asset, _to, _amount);
    }

    // Configure asset ownership-based discounted mints, bulk compatible
    // Each individual collection must have a corresponding discount price and total discounted mint quantity
    function configureMintDiscount(
        address[] memory _assets,
        bool[] memory _status,
        int64[] memory _allocations,
        uint64[] memory _userMax,
        uint256[] memory _tokenBalances,
        uint256[] memory _prices
    ) external payable virtual onlyOwner {
        // Confirm all arrays match in length to ensure each collection has proper values set
        uint256 length = _assets.length;
        if (
            length != _status.length || length != _allocations.length || length != _userMax.length
                || length != _tokenBalances.length || length != _prices.length
        ) revert ArrayLengthMismatch();

        // Loop through and configure each corresponding discount
        for (uint256 i; i < length;) {
            // Retrieve current mint info, if any
            MintInfo memory info = mintDiscountInfo[_assets[i]];
            info.active = _status[i];
            // Ensure supply or allocation cant underflow if theyre being reduced
            if (info.supply + _allocations[i] < 0) {
                revert Underflow();
            }
            unchecked {
                info.supply += _allocations[i];
                info.allocated += _allocations[i];
            }
            // Enforced disable if adjustment eliminates mint availability
            if (info.supply <= 0 || info.allocated <= 0) info.active = false;
            info.userMax = _userMax[i];
            info.tokenBalance = _tokenBalances[i];
            info.mintPrice = _prices[i];
            mintDiscountInfo[_assets[i]] = info;
            emit ConfigureMintDiscount(
                _assets[i], _status[i], _allocations[i], _userMax[i], _tokenBalances[i], _prices[i]
            );
            unchecked {
                ++i;
            }
        }
    }
}
