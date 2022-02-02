// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OptionsPoolStorageV1 is
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Fee incurred when withdrawing out of the vault, in the units of 10**18
    // where 1 ether = 100%, so 0.005 means 0.5% fee
    uint256 public instantWithdrawalFee;
    // Privileged role that is able to select the option terms
    address public manager;
}

// We are following Compound's method of upgrading new contract implementations
// When we need to add new storage variables, we create a new version of OptionsPoolStorage
// e.g. OptionsPoolStorage<versionNumber>, so finally it would look like
// contract OptionsVaultStorage is OptionsPoolStorageV1, OptionsPoolStorageV2
contract OptionsPoolStorage is OptionsPoolStorageV1 {

}
