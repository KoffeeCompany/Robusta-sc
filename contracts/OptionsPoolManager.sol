// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {OptionsPoolStorage} from "./OptionsPoolStorage.sol";

contract OptionsPoolManager is OptionsPoolStorage {
    event WithdrawalFeeSet(uint256 oldFee, uint256 newFee);

    constructor() {
        // hardcode the initial withdrawal fee
        instantWithdrawalFee = 0.005 ether;
    }

    /**
     * @notice Sets the new withdrawal fee
     * @param newWithdrawalFee is the fee paid in tokens when withdrawing
     */
    function setWithdrawalFee(uint256 newWithdrawalFee) external onlyOwner {
        require(newWithdrawalFee > 0, "withdrawalFee != 0");

        // cap max withdrawal fees to 30% of the withdrawal amount
        require(newWithdrawalFee < 0.3 ether, "withdrawalFee >= 30%");

        uint256 oldFee = instantWithdrawalFee;
        emit WithdrawalFeeSet(oldFee, newWithdrawalFee);

        instantWithdrawalFee = newWithdrawalFee;
    }

    function getWithdrawalFee() external returns (uint256) {
        return instantWithdrawalFee;
    }
}
