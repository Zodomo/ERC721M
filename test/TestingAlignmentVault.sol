// SPDX-License-Identifier: VPL
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
    function view_NFTX_INVENTORY_STAKING() public pure returns (address) { return (address(_NFTX_INVENTORY_STAKING)); }
    function view_NFTX_LIQUIDITY_STAKING() public pure returns (address) { return (address(_NFTX_LIQUIDITY_STAKING)); }
    function view_NFTX_STAKING_ZAP() public pure returns (address) { return (address(_NFTX_STAKING_ZAP)); }

    function view_erc721() public view returns (address) { return (address(_erc721)); }
    function view_nftxInventory() public view returns (address) { return (address(_nftxInventory)); }
    function view_nftxLiquidity() public view returns (address) { return (address(_nftxLiquidity)); }
    function view_vaultId() public view returns (uint256) { return (_vaultId); }

    function call_checkBalance(address _token) public view returns (uint256) {return (_checkBalance(_token)); }
    function call_sortTokens(address _tokenA, address _tokenB) public pure returns (address, address) {
        (address token0, address token1) = _sortTokens(_tokenA, _tokenB);
        return (token0, token1);
    }
    function call_pairFor(address _tokenA, address _tokenB) public pure returns (address) {
        return (_pairFor(_tokenA, _tokenB));
    }
    
    function execute_wrap(uint256 _eth) public { wrap(_eth); }
    function execute_addInventory(uint256[] calldata _tokenIds) public { addInventory(_tokenIds); }
    function execute_addLiquidity(uint256[] calldata _tokenIds) public { addLiquidity(_tokenIds); }
    function execute_deepenLiquidity(
        uint112 _eth,
        uint112 _weth,
        uint112 _nftxInv
    ) public returns (uint256) { return (deepenLiquidity(_eth, _weth, _nftxInv)); }
    function execute_stakeLiquidity() public returns (uint256) { return (stakeLiquidity()); }
    function execute_claimRewards() public { claimRewards(); }
    function execute_rescueERC20(address _token, address _to) public returns (uint256) {
        return (rescueERC20(_token, _to));
    }
    function execute_rescueERC721(
        address _address,
        address _to,
        uint256 _tokenId
    ) public { rescueERC721(_address, _to, _tokenId); }
}