// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {_getStrikeTicks, _safeTransferFrom} from "../functions/FOption.sol";
import {OptionType} from "../enums/EOption.sol";

contract OptionFunctionMock {
    function getStrikeTicksMock(
        IUniswapV3Pool pool_,
        OptionType optionType_,
        int24 strike_,
        int24 tickT0_
    ) external view returns (int24 lowerTick, int24 upperTick) {
        return _getStrikeTicks(pool_, optionType_, strike_, tickT0_);
    }

    function safeTransferFromMock(
        uint256 notional_,
        IERC20 tokenIn_,
        IWETH9 WETH9_,
        address receiver_
    ) external payable {
        _safeTransferFrom(notional_, tokenIn_, WETH9_, receiver_);
    }
}
