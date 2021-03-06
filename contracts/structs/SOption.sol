// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {OptionType} from "../enums/EOption.sol";

struct OptionData {
    IUniswapV3Pool pool; // Underlying asset
    OptionType optionType;
    int24 strike;
    // solhint-disable-next-line var-name-mixedcase
    int24 tickT0; // tick at t_0 during option creation
    uint256 notional;
    uint256 maturity;
    address maker;
    address resolver;
    uint256 price;
}
