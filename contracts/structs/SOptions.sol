// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OptionType} from "../enums/EOptions.sol";

struct OptionData {
    IUniswapV3Pool pool; // Underlying asset
    OptionType optionType;
    int24 strike;
    uint256 notional;
    uint256 maturity;
    address maker;
    address resolver;
    uint256 price;
}
