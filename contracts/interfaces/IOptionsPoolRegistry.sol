// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IOptionsPoolRegistry {
    function registerOption(address owner_, address option_) external;

    function registerLiquidity(address owner_, uint256 share_) external;

    function revokeLiquidity(address owner_, uint256 share_) external;
}
