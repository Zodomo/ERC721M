// SPDX-License-Identifier: VPL
pragma solidity ^0.8.20;

import {SafeMath} from 'openzeppelin/utils/math/SafeMath.sol';
import {IERC20} from 'openzeppelin/token/ERC20/IERC20.sol';
import {IUniswapV2Router02} from 'v2-periphery/interfaces/IUniswapV2Router02.sol';

// Originally sourced from: https://gist.github.com/QuantSoldier/8e0e148c0024df47bccc006560b3f615

interface IWETH9 {
    function deposit() external payable;
}

// Uses approx. 340K GAS
contract UniswapAdd {
    using SafeMath for uint256;

    address private constant router = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address private constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(address token) payable {
        // get weth
        IWETH9(weth).deposit{value: msg.value}();
        uint256 wethBalance = IERC20(weth).balanceOf(address(this));

        // approve router
        IERC20(weth).approve(router, 2 ** 255);
        IERC20(token).approve(router, 2 ** 255);
        
        // construct token path
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = token;

        IUniswapV2Router02(router).swapExactTokensForTokens(
            wethBalance.div(2),
            0,
            path,
            address(this),
            block.timestamp + 5 minutes
        );
        
        // calculate balances and add liquidity
        wethBalance = IERC20(weth).balanceOf(address(this));
        uint256 balance = IERC20(token).balanceOf(address(this));

        IUniswapV2Router02(router).addLiquidity(
            token,
            weth,
            balance,
            wethBalance,
            0,
            0,
            msg.sender,
            block.timestamp + 5 minutes
        );
        
        // sweep any remaining token balances
        if (IERC20(weth).balanceOf(address(this)) > 0) {
            IERC20(weth).transfer(msg.sender, IERC20(weth).balanceOf(address(this)));
        }

        if (IERC20(token).balanceOf(address(this)) > 0) {
            IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
        }
        
        // self-destruct to free up on-chain memory, refunds additional gas
        selfdestruct(payable(msg.sender));
    }
}