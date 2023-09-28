// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

/**
 * @title IAlignmentVault
 * @author Zodomo.eth (X: @0xZodomo, Telegram: @zodomo, Email: zodomo@proton.me)
 */
interface IAlignmentVault {
    function vaultId() external view returns (uint256);
    function nftsHeld(uint256 _index) external view returns (uint256);

    function initialize(address _erc721, address _owner, uint256 _vaultId) external;
    function disableInitializers() external;

    function alignLiquidity() external;
    function claimYield(address _recipient) external;
    function checkInventory(uint256[] memory _tokenIds) external;

    function rescueERC20(address _token, address _to) external returns (uint256);
    function rescueERC721(address _token, address _to, uint256 _tokenId) external;
}
