// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    INonfungiblePositionManager
} from "./interfaces/INonfungiblePositionManager.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IPokeMe} from "./interfaces/IPokeMe.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OptionsPool is 
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable gelato;
    INonfungiblePositionManager private immutable _positionManager;
    IPokeMe private immutable _pokeMe;
    IWETH9 private immutable _WETH9;
    
    // Recipient for withdrawal fees
    address public feeRecipient;
    uint256 public immutable minimumSupply;

    /**
     * @notice Initializes the contract pool
     * @param gelato_ is the gelato address to transfer the pokeMe fees
     * @param positionManager_ is the Uniswap position
     * @param pokeMe_ is the Gelato pokeMe to handle the settlement
     * @param weth9_ is the Wrapped Ether contract.
     */
    constructor(
        address gelato_,
        INonfungiblePositionManager positionManager_,
        IPokeMe pokeMe_,
        IWETH9 weth9_
    ) {
        require(gelato_ != address(0), "!gelato_");
        require(address(positionManager_) != address(0), "!positionManager_");
        require(address(pokeMe_) != address(0), "!pokeMe_");
        require(address(weth9_) != address(0), "!weth9_");
        gelato = gelato_;
        _positionManager = positionManager_;
        _pokeMe = pokeMe_;
        _WETH9 = weth9_;
    }

    /**
     * @notice Initializes the OptionPool contract
     * @param owner_ is the owner of the contract who can set the manager
     * @param feeRecipient_ is the recipient address for withdrawal fees.
     * @param maturity_ is the option pool maturity.
     * @param pool_ is the Uniswap V3 Pool.
     */
    function initialize(
        address owner_,
        address feeRecipient_,
        uint256 maturity_,
        uint256 minimumSupply_,
        IUniswapV3Pool pool_
    ) external initializer {
        require(owner_ != address(0), "!owner_");
        require(feeRecipient_ != address(0), "!feeRecipient_");
        require(maturity_ > block.timestamp, "maturity_ > block.timestamp");
        require(address(pool_) != address(0), "!pool_");
        require(minimumSupply_ > 0, "!minimumSupply_");

        __ReentrancyGuard_init();
        __Ownable_init();
        transferOwnership(owner_);

        feeRecipient = feeRecipient_;
        minimumSupply = minimumSupply_;
    }

    /**
     * @notice Sets the new fee recipient
     * @param newFeeRecipient is the address of the new fee recipient
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "!newFeeRecipient");
        feeRecipient = newFeeRecipient;
    }
}