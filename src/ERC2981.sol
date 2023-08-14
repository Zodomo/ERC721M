// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./IERC2981.sol";

// Sourced from / inspired by https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/common/ERC2981.sol
// Modified it to implement features and work with Solady and the ERC165 override scheme of this project

abstract contract ERC2981 is IERC2981 {

    error ExceedsDenominator();
    error InvalidReceiver();

    event RoyaltyConfigured(address indexed receiver, uint96 indexed royaltyFee);
    event RoyaltyConfigured(uint256 tokenId, address indexed receiver, uint96 indexed royaltyFee);

    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo internal _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    /**
     * @inheritdoc IERC2981
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view virtual override returns (address, uint256) {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (salePrice * royalty.royaltyFraction) / 10000;

        return (royalty.receiver, royaltyAmount);
    }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        if (feeNumerator > 10000) { revert ExceedsDenominator(); }
        if (receiver == address(0)) { revert InvalidReceiver(); }

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);

        emit RoyaltyConfigured(receiver, feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function _deleteDefaultRoyalty() internal virtual { delete _defaultRoyaltyInfo; }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        if (feeNumerator > 10000) { revert ExceedsDenominator(); }
        if (receiver == address(0)) { revert InvalidReceiver(); }

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
        emit RoyaltyConfigured(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev Resets royalty information for the token id back to the global default.
     */
    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}
