// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import {
    INonfungiblePositionManager
} from "./interfaces/INonfungiblePositionManager.sol";
import {IPokeMe} from "./interfaces/IPokeMe.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IResolver} from "./interfaces/IResolver.sol";
import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {OptionData} from "./structs/SOption.sol";
import {OptionType} from "./enums/EOption.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {PRICE_ORACLE} from "./constants/COptions.sol";
import {
    _getStrikeTicks,
    _safeTransferFrom,
    _swapExactOutput
} from "./functions/FOption.sol";

contract Option {
    using SafeERC20 for IERC20;

    address public immutable gelato;
    INonfungiblePositionManager private immutable _positionManager;
    IPokeMe private immutable _pokeMe;
    IWETH9 public immutable WETH9;

    mapping(uint256 => bytes32) public hashById;
    mapping(uint256 => bytes32) public taskById;
    mapping(bytes32 => address) public buyers;

    event LogOptionCreation(
        uint256 indexed tokenId,
        OptionData option,
        address sender
    );
    event LogOptionBuy(uint256 tokenId, address buyer);
    event LogSettle(
        uint256 indexed tokenId,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 feeAmount
    );
    event LogCancel(uint256 indexed tokenId);

    modifier onlyPokeMe() {
        require(
            msg.sender == address(_pokeMe),
            "Option::onlyPokeMe: only pokeMe"
        );
        _;
    }

    constructor(
        address gelato_,
        INonfungiblePositionManager positionManager_,
        IPokeMe pokeMe_,
        IWETH9 WETH9_
    ) {
        gelato = gelato_;
        _positionManager = positionManager_;
        _pokeMe = pokeMe_;
        WETH9 = WETH9_;
    }

    function createOption(OptionData calldata optionData_) external payable {
        bool isCall = optionData_.optionType == OptionType.CALL;

        (int24 lowerTick, int24 upperTick) = _getStrikeTicks(
            optionData_.pool,
            optionData_.optionType,
            optionData_.strike,
            optionData_.tickT0
        );

        address token0 = optionData_.pool.token0();
        address token1 = optionData_.pool.token1();

        IERC20 tokenIn = IERC20(isCall ? token0 : token1);

        _safeTransferFrom(optionData_.notional, tokenIn, WETH9, address(this));

        tokenIn.safeApprove(address(_positionManager), optionData_.notional);

        (uint256 tokenId, , , ) = _positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: optionData_.pool.fee(),
                tickLower: lowerTick,
                tickUpper: upperTick,
                amount0Desired: isCall ? optionData_.notional : 0,
                amount1Desired: isCall ? 0 : optionData_.notional,
                amount0Min: isCall ? optionData_.notional : 0,
                amount1Min: isCall ? 0 : optionData_.notional,
                recipient: address(this),
                deadline: block.timestamp // solhint-disable-line not-rely-on-time
            })
        );
        _saveOption(tokenId, optionData_, isCall ? token1 : token0);

        emit LogOptionCreation(tokenId, optionData_, msg.sender);
    }

    function cancelOption(uint256 tokenId_, OptionData calldata optionData_)
        external
    {
        require(
            msg.sender == _positionManager.ownerOf(tokenId_),
            "Option::cancelOption: only owner"
        );
        bytes32 optionDataHash = keccak256(abi.encode(optionData_));
        require(
            hashById[tokenId_] == optionDataHash,
            "Option::cancelOption: invalid hash"
        );
        require(
            buyers[optionDataHash] == address(0),
            "Option::cancelOption: option already bought"
        );

        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = _positionManager.positions(tokenId_);

        _pokeMe.cancelTask(taskById[tokenId_]);

        delete hashById[tokenId_];
        delete taskById[tokenId_];
        delete buyers[optionDataHash];

        (uint256 amount0, uint256 amount1) = _collect(tokenId_, liquidity);

        if (amount0 > 0) {
            IERC20(token0).safeTransfer(optionData_.maker, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeTransfer(optionData_.maker, amount1);
        }

        emit LogCancel(tokenId_);
    }

    function buyOption(uint256 tokenId_, OptionData calldata optionData_)
        external
        payable
    {
        require(
            address(this) == _positionManager.ownerOf(tokenId_),
            "Option::buyOption: only owner"
        );
        bytes32 optionDataHash = keccak256(abi.encode(optionData_));
        require(
            hashById[tokenId_] == optionDataHash,
            "Option::buyOption: invalid hash"
        );
        require(
            buyers[optionDataHash] == address(0),
            "Option::buyOption: option already bought"
        );
        require(
            optionData_.maturity > block.timestamp,
            "Option::buyOption: option expired"
        );

        buyers[optionDataHash] = msg.sender;

        IERC20 tokenIn = IERC20(
            optionData_.optionType == OptionType.CALL
                ? optionData_.pool.token1()
                : optionData_.pool.token0()
        );

        if (msg.value > 0) {
            require(
                msg.value == optionData_.price,
                "Option:buyOption:: Invalid price in."
            );
            require(
                address(tokenIn) == address(WETH9),
                "Option:buyOption:: ETH option should use WETH token."
            );

            WETH9.deposit{value: msg.value}();
        } else
            tokenIn.safeTransferFrom(
                msg.sender,
                address(this),
                optionData_.price
            );

        tokenIn.safeTransfer(optionData_.maker, optionData_.price);

        emit LogOptionBuy(tokenId_, msg.sender);
    }

    function settleOption(uint256 tokenId_, OptionData calldata optionData_)
        external
        onlyPokeMe
    {
        canSettle(tokenId_, optionData_);
        (uint256 feeAmount, address feeToken) = _pokeMe.getFeeDetails();
        bytes32 optionDataHash = keccak256(abi.encode(optionData_));

        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = _positionManager.positions(tokenId_);

        require(
            feeToken == token0 || feeToken == token1,
            "feeToken token invald."
        );
        uint256 amount0;
        uint256 amount1;
        {
            address optionBuyer = buyers[optionDataHash];

            delete hashById[tokenId_];
            delete taskById[tokenId_];
            delete buyers[optionDataHash];

            (amount0, amount1) = _collect(tokenId_, liquidity);

            if (feeToken == token0) {
                if (amount0 < feeAmount) {
                    amount1 -= _swapExactOutput(
                        token1,
                        token0,
                        optionData_.pool.fee(),
                        address(this),
                        feeAmount - amount0,
                        amount1
                    );

                    amount0 += feeAmount;
                }

                amount0 -= feeAmount;
            } else {
                if (amount1 < feeAmount) {
                    amount0 -= _swapExactOutput(
                        token0,
                        token1,
                        optionData_.pool.fee(),
                        address(this),
                        feeAmount - amount1,
                        amount0
                    );

                    amount1 += feeAmount;
                }

                amount1 -= feeAmount;
            }

            {
                (, int24 tick, , , , , ) = optionData_.pool.slot0();

                bool executeOption;

                {
                    bool isCall = optionData_.optionType == OptionType.CALL;
                    executeOption = isCall
                        ? tick > optionData_.tickT0
                        : tick < optionData_.tickT0;
                }

                if (amount0 > 0) {
                    IERC20(token0).safeTransfer(
                        executeOption ? optionBuyer : optionData_.maker,
                        amount0
                    );
                }

                if (amount1 > 0) {
                    IERC20(token1).safeTransfer(
                        executeOption ? optionBuyer : optionData_.maker,
                        amount1
                    );
                }
            }
        }

        // gelato fee
        IERC20(feeToken).safeTransfer(gelato, feeAmount);

        _positionManager.burn(tokenId_);

        emit LogSettle(tokenId_, amount0, amount1, feeAmount);
    }

    function canSettle(uint256 tokenId_, OptionData calldata optionData_)
        public
        view
        returns (bool)
    {
        require(
            address(this) == _positionManager.ownerOf(tokenId_),
            "Option::canSettle: only owner"
        );
        bytes32 optionDataHash = keccak256(abi.encode(optionData_));
        require(
            hashById[tokenId_] == optionDataHash,
            "Option::canSettle: invalid hash"
        );
        require(
            buyers[optionDataHash] != address(0),
            "Option::canSettle: option not yet bought"
        );
        require(
            optionData_.maturity <= block.timestamp,
            "Option::canSettle: option not matured yet"
        );
        return true;
    }

    function _saveOption(
        uint256 tokenId_,
        OptionData calldata optionData_,
        address feeToken_
    ) internal {
        hashById[tokenId_] = keccak256(abi.encode(optionData_));
        taskById[tokenId_] = _pokeMe.createTaskNoPrepayment(
            address(this),
            this.settleOption.selector,
            optionData_.resolver,
            abi.encodeWithSelector(
                IResolver.checker.selector,
                tokenId_,
                optionData_
            ),
            feeToken_
        );
    }

    function _collect(uint256 tokenId_, uint128 liquidity_)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        _positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId_,
                liquidity: liquidity_,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp // solhint-disable-line not-rely-on-time
            })
        );
        (amount0, amount1) = _positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId_,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        return (amount0, amount1);
    }
}
