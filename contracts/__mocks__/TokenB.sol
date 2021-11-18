// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenB is ERC20 {
    constructor() ERC20("Token B", "TKNB") {
        _mint(0xF953c3d475dc0a9877329F71e2CE3d2519a519A2, 1e27);
    }
}
