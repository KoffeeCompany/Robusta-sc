// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {IPokeMeResolver} from "./interfaces/IPokeMeResolver.sol";
import {IOption} from "./interfaces/IOption.sol";
import {OptionData} from "./structs/SOption.sol";

contract OptionResolver is IPokeMeResolver {
    IOption private immutable _option;

    constructor(IOption option_) {
        _option = option_;
    }

    function checker(uint256 tokenId_, OptionData calldata optionData_)
        external
        view
        override
        returns (bool canExec, bytes memory execPayload)
    {
        try _option.canSettle(tokenId_, optionData_) returns (bool canExec) {
            return (
                canExec,
                abi.encodeWithSelector(
                    IOption.settleOption.selector,
                    tokenId_,
                    optionData_
                )
            );
        } catch {
            return (
                false,
                abi.encodeWithSelector(
                    IOption.settleOption.selector,
                    tokenId_,
                    optionData_
                )
            );
        }
    }
}
