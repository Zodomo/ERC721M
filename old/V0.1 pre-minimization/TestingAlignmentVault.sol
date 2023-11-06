// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "openzeppelin/interfaces/IERC20.sol";
import "openzeppelin/interfaces/IERC721.sol";
import "../src/AlignmentVault.sol";

contract TestingAlignmentVault is AlignmentVault {

    constructor(address _nft) AlignmentVault(_nft) { }

    function view_WETH() public pure returns (address) { return (address(_WETH)); }
    function view_SUSHI_V2_FACTORY() public pure returns (address) { return (_SUSHI_V2_FACTORY); }
    function view_SUSHI_V2_ROUTER() public pure returns (address) { return (address(_SUSHI_V2_ROUTER)); }
    function view_liqHelper() public view returns (address) { return (address(_liqHelper)); }

    function view_NFTX_VAULT_FACTORY() public pure returns (address) { return (address(_NFTX_VAULT_FACTORY)); }
    function view_NFTX_LIQUIDITY_STAKING() public pure returns (address) { return (address(_NFTX_LIQUIDITY_STAKING)); }
    function view_NFTX_STAKING_ZAP() public pure returns (address) { return (address(_NFTX_STAKING_ZAP)); }

    function call_estimateFloor() public view returns (uint256) { return _estimateFloor(); }
    
    function execute_wrap(uint256 _eth) public { wrap(_eth); }
    function execute_addLiquidity(uint256[] calldata _tokenIds) public { addLiquidity(_tokenIds); }
    function execute_deepenLiquidity(
        uint112 _eth,
        uint112 _weth,
        uint112 _nftxInv
    ) public returns (uint256) { return (deepenLiquidity(_eth, _weth, _nftxInv)); }
    function execute_stakeLiquidity() public returns (uint256) { return (stakeLiquidity()); }
    function execute_claimRewards(address _recipient) public { claimRewards(_recipient); }
    function execute_compoundRewards(uint112 _eth, uint112 _weth) public { compoundRewards(_eth, _weth); }
    function execute_rescueERC20(address _token, address _to) public returns (uint256) {
        return (rescueERC20(_token, _to));
    }
    function execute_rescueERC721(
        address _address,
        address _to,
        uint256 _tokenId
    ) public { rescueERC721(_address, _to, _tokenId); }
}