// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {OptionData} from "../structs/SOption.sol";

interface IOption {
    function canSettle(uint256 tokenId_, OptionData calldata optionData_)
        external
        view
        returns (bool);
    
    function settleOption(uint256 tokenId_, OptionData calldata optionData_)
        external; 

    function createOption(OptionData calldata optionData_) external;
}