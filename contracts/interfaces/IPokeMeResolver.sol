// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {OptionData} from "../structs/SOption.sol";

interface IPokeMeResolver {
    function checker(uint256 tokenId_, OptionData calldata optionData_)
        external
        view
        returns (bool canExec, bytes memory execPayload);
}
