// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {OptionData} from "../structs/SOptions.sol";

interface IResolver {
    function checker(
        uint256,
        OptionData memory order,
        address feeToken_
    ) external view returns (bool, bytes memory);
}
