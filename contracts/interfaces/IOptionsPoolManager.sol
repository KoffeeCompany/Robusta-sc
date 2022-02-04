// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IOptionsPoolManager {
    function getWithdrawalFee() external returns (uint256);
    function initialize(address owner_) external;
}
