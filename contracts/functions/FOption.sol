// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    IUniswapV3Factory
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {
    ISwapRouter
} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OptionData} from "../structs/SOption.sol";
import {OptionType} from "../enums/EOption.sol";
import {SWAPROUTER} from "../constants/COptions.sol";

int24 constant tick_t0_discrepancy = 2;

function _getStrikeTicks(
    IUniswapV3Pool pool_,
    OptionType optionType_,
    int24 strike_,
    int24 tickT0_
) view returns (int24 lowerTick, int24 upperTick) {
    int24 tickSpacing = pool_.tickSpacing();
    require(
        strike_ % tickSpacing == 0,
        "FOption::getStrikeTicks:: strike is not initializable tick"
    );

    bool isCall = optionType_ == OptionType.CALL;

    lowerTick = isCall ? strike_ : strike_ - tickSpacing;
    upperTick = isCall ? strike_ + tickSpacing : strike_;

    (, int24 tick, , , , , ) = pool_.slot0();

    int24 discrepancy = tick_t0_discrepancy * tickSpacing;

    require(
        tick + discrepancy > tickT0_ && tick - discrepancy < tickT0_,
        "Option::createOption: Wrong t0 tick."
    );

    require(
        isCall
            ? lowerTick > tick && upperTick > tick
            : lowerTick < tick && upperTick < tick,
        "FOption::getStrikeTicks:: strike in wrong side"
    );
}

function _safeTransferFrom(
    uint256 notional_,
    IERC20 tokenIn_,
    IWETH9 WETH9_,
    address receiver_
) {
    if (msg.value > 0) {
        require(
            msg.value == notional_,
            "RangeOrder:setRangeOrder:: Invalid notional in."
        );
        require(
            address(tokenIn_) == address(WETH9_),
            "RangeOrder:setRangeOrder:: ETH range order should use WETH token."
        );

        WETH9_.deposit{value: msg.value}();
    } else
        SafeERC20.safeTransferFrom(tokenIn_, msg.sender, receiver_, notional_);
}

function _swapExactOutput(
    address tokenIn_,
    address tokenOut_,
    uint24 fee_,
    address receiver_,
    uint256 amountOut_,
    uint256 amountInMax_
) returns (uint256 amountIn) {
    return
        ISwapRouter(SWAPROUTER).exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: tokenIn_,
                tokenOut: tokenOut_,
                fee: fee_,
                recipient: receiver_,
                deadline: block.timestamp,
                amountOut: amountOut_,
                amountInMaximum: amountInMax_,
                sqrtPriceLimitX96: 0
            })
        );
}
