// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract OptionsPoolRegistry is Ownable {
    using SafeMath for uint256;

    mapping(address => mapping(address => bool)) public options;
    mapping(address => uint256) public providers;

    event RegisterOption(address owner, address option);
    event RevokeOption(address owner, address option);
    event RegisterLiquidity(address owner, uint256 share);
    event RevokeLiquidity(address owner, uint256 share);

    /**
     * @notice Register option
     * @param owner_ is the option creator address
     * @param option_ is the option address
     */
    function registerOption(address owner_, address option_)
        external
        onlyOwner
    {
        require(owner_ != address(0), "!owner_");
        require(option_ != address(0), "!option_");
        options[owner_][option_] = true;
        emit RegisterOption(owner_, option_);
    }

    function revokeOption(address owner_, address option_)
        external
        onlyOwner
    {
        require(owner_ != address(0), "!owner_");
        require(option_ != address(0), "!option_");
        if(options[owner_][option_] == true)
        {
            delete options[owner_][option_];
            emit RevokeOption(owner_, option_);
        }
    }

    function registerLiquidity(address owner_, uint256 share_)
        external
        onlyOwner
    {
        require(owner_ != address(0), "!owner_");
        if (providers[owner_] != 0) {
            uint256 stored = providers[owner_];
            providers[owner_] = stored.add(share_);
        } else {
            providers[owner_] = share_;
        }
        emit RegisterLiquidity(owner_, share_);
    }

    function revokeLiquidity(address owner_, uint256 share_)
        external
        onlyOwner
    {
        require(owner_ != address(0), "!owner_");
        uint256 stored = providers[owner_];
        require(stored >= share_, "share to revoke is greater than stored");
        providers[owner_] -= share_;
        if(providers[owner_] == 0)
        {
            delete providers[owner_];
        }
        emit RevokeLiquidity(owner_, share_);
    }
}
