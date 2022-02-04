// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {OptionType} from "./enums/EOption.sol";
import {
    INonfungiblePositionManager
} from "./interfaces/INonfungiblePositionManager.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IOptionsPoolRegistry} from "./interfaces/IOptionsPoolRegistry.sol";
import {IOptionsPoolManager} from "./interfaces/IOptionsPoolManager.sol";
import {IPokeMe} from "./interfaces/IPokeMe.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {DSMath} from "./lib/DSMath.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract OptionsPool is
    DSMath,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    ERC20Upgradeable
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public immutable gelato;
    INonfungiblePositionManager private immutable _positionManager;
    IPokeMe private immutable _pokeMe;
    IWETH9 private immutable _WETH9;

    // Recipient for withdrawal fees
    address public feeRecipient;
    uint256 public minimumSupply;

    int24 private _tickSpacing;
    address public baseToken;
    address public quoteToken;

    IOptionsPoolRegistry public immutable registry;
    IOptionsPoolManager public immutable manager;

    event Deposit(address indexed account, uint256 amount, uint256 share);

    event Withdraw(
        address indexed account,
        uint256 amount,
        uint256 share,
        uint256 fee
    );

    /**
     * @notice Initializes the contract pool
     * @param gelato_ is the gelato address to transfer the pokeMe fees
     * @param registry_ is the registry address
     * @param manager_ is the manager address
     * @param positionManager_ is the Uniswap position
     * @param pokeMe_ is the Gelato pokeMe to handle the settlement
     * @param weth9_ is the Wrapped Ether contract.
     */
    constructor(
        address gelato_,
        address registry_,
        address manager_,
        INonfungiblePositionManager positionManager_,
        IPokeMe pokeMe_,
        IWETH9 weth9_
    ) {
        require(gelato_ != address(0), "!gelato_");
        require(registry_ != address(0), "!registry_");
        require(manager_ != address(0), "!manager_");
        require(address(positionManager_) != address(0), "!positionManager_");
        require(address(pokeMe_) != address(0), "!pokeMe_");
        require(address(weth9_) != address(0), "!weth9_");
        gelato = gelato_;
        _positionManager = positionManager_;
        _pokeMe = pokeMe_;
        _WETH9 = weth9_;
        registry = IOptionsPoolRegistry(registry_);
        manager = IOptionsPoolManager(manager_);
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
        IUniswapV3Pool pool_,
        string calldata tokenName_,
        string calldata tokenSymbol_
    ) external initializer {
        require(owner_ != address(0), "!owner_");
        require(feeRecipient_ != address(0), "!feeRecipient_");
        require(maturity_ > block.timestamp, "maturity_ > block.timestamp");
        require(address(pool_) != address(0), "!pool_");
        require(minimumSupply_ > 0, "!minimumSupply_");
        require(bytes(tokenName_).length > 0, "tokenName_ != 0x");
        require(bytes(tokenSymbol_).length > 0, "tokenSymbol_ != 0x");

        __ReentrancyGuard_init();
        __ERC20_init(tokenName_, tokenSymbol_);
        __Ownable_init();
        transferOwnership(owner_);
        manager.initialize(owner_);

        feeRecipient = feeRecipient_;
        minimumSupply = minimumSupply_;

        _tickSpacing = pool_.tickSpacing();
        baseToken = pool_.token0();
        quoteToken = pool_.token1();
    }

    function createOption(
        OptionType optionType_,
        int24 strike_,
        uint256 notional_,
        uint256 maturity_
    ) external payable {
        //
    }

    /**
     * @notice Deposits the `baseToken` into the contract and mint shares.
     * @param amount is the amount of `baseToken` to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        IERC20(baseToken).safeTransferFrom(msg.sender, address(this), amount);
        _deposit(amount);
    }

    /**
     * @notice Mints the shares to the msg.sender
     * @param amount is the amount of `baseToken` deposited
     */
    function _deposit(uint256 amount) private {
        uint256 totalAmount = totalBalance();

        // amount needs to be subtracted from totalBalance because it has already been
        // added to it from either IWETH.deposit and IERC20.safeTransferFrom
        uint256 previousTotal = totalAmount.sub(amount);

        uint256 shareSupply = totalSupply();

        uint256 share = shareSupply == 0
            ? amount
            : amount.mul(shareSupply).div(previousTotal);

        registry.registerLiquidity(msg.sender, share);
        emit Deposit(msg.sender, amount, share);

        _mint(msg.sender, share);
    }

    /**
     * @notice Withdraws basetoken from pool using shares
     * @param share is the number of shares to be burned
     */
    function withdraw(uint256 share) external nonReentrant {
        uint256 withdrawAmount = _withdraw(share, false);
        IERC20(baseToken).safeTransfer(msg.sender, withdrawAmount);
    }

    /**
     * @notice Burns shares and checks if eligible for withdrawal
     * @param share is the number of shares to be burned
     * @param feeless is whether a withdraw fee is charged
     */
    function _withdraw(uint256 share, bool feeless) private returns (uint256) {
        (uint256 amountAfterFee, uint256 feeAmount) = withdrawAmountWithShares(
            share
        );

        if (feeless) {
            amountAfterFee = amountAfterFee.add(feeAmount);
            feeAmount = 0;
        }

        registry.revokeLiquidity(msg.sender, share);
        emit Withdraw(msg.sender, amountAfterFee, share, feeAmount);

        _burn(msg.sender, share);

        IERC20(baseToken).safeTransfer(feeRecipient, feeAmount);

        return amountAfterFee;
    }

    /**
     * @notice Returns the amount withdrawable (in `basetoken` tokens) using the `share` amount
     * @param share is the number of shares burned to withdraw asset from the pool
     * @return amountAfterFee is the amount of basetoken tokens withdrawable from the pool
     * @return feeAmount is the fee amount (in basetoken tokens) sent to the feeRecipient
     */
    function withdrawAmountWithShares(uint256 share)
        public
        returns (uint256 amountAfterFee, uint256 feeAmount)
    {
        uint256 currentBalance = totalBalance();
        (
            uint256 withdrawAmount,
            uint256 newAssetBalance,
            uint256 newShareSupply
        ) = _withdrawAmountWithShares(share, currentBalance);

        require(
            withdrawAmount <= currentBalance,
            "Cannot withdraw more than available"
        );

        uint256 instantWithdrawalFee = manager.getWithdrawalFee();
        feeAmount = wmul(withdrawAmount, instantWithdrawalFee);
        amountAfterFee = withdrawAmount.sub(feeAmount);
    }

    /**
     * @notice Helper function to return the `basetoken` amount returned using the `share` amount
     * @param share is the number of shares used to withdraw
     * @param currentBalance is the value returned by totalBalance(). This is passed in to save gas.
     */
    function _withdrawAmountWithShares(uint256 share, uint256 currentBalance)
        private
        view
        returns (
            uint256 withdrawAmount,
            uint256 newAssetBalance,
            uint256 newShareSupply
        )
    {
        uint256 total = currentBalance;

        uint256 shareSupply = totalSupply();

        withdrawAmount = share.mul(total).div(shareSupply);
        newAssetBalance = total.sub(withdrawAmount);
        newShareSupply = shareSupply.sub(share);
    }

    /**
     * @notice Returns the vault's total balance, including the amounts locked into a short position
     * @return total balance of the vault, including the amounts locked in third party protocols
     */
    function totalBalance() public view returns (uint256) {
        return IERC20(baseToken).balanceOf(address(this));
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
