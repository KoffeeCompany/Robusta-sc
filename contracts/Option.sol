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

contract Option {
    using SafeERC20 for IERC20;

    address private immutable _gelato;
    INonfungiblePositionManager private immutable _positionManager;
    IPokeMe private immutable _pokeMe;
    IWETH9 private immutable _WETH9;

    mapping(uint256 => bytes32) public hashById;
    mapping(uint256 => bytes32) public taskById;
    mapping(bytes32 => address) public buyers;

    event LogOptionCreation(
        uint256 tokenId,
        OptionData indexed option,
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
            "EjectLP::onlyPokeMe: only pokeMe"
        );
        _;
    }

    constructor(
        address gelato_,
        INonfungiblePositionManager positionManager_,
        IPokeMe pokeMe_,
        IWETH9 WETH9_
    ) {
        _gelato = gelato_;
        _positionManager = positionManager_;
        _pokeMe = pokeMe_;
        _WETH9 = WETH9_;
    }

    function createOption(OptionData calldata optionData_) external payable {
        (, int24 tick, , , , , ) = optionData_.pool.slot0();

        bool isCall = optionData_.optionType == OptionType.CALL;

        int24 tickSpacing = optionData_.pool.tickSpacing();
        int24 lowerTick = isCall
            ? optionData_.strike
            : optionData_.strike - tickSpacing;
        int24 upperTick = isCall
            ? optionData_.strike + tickSpacing
            : optionData_.strike;
        require(tick < lowerTick || tick > upperTick, "eject tick in range");

        address token0 = optionData_.pool.token0();
        address token1 = optionData_.pool.token1();

        IERC20 tokenIn = IERC20(isCall ? token0 : token1);

        if (msg.value > 0) {
            require(
                msg.value == optionData_.notional,
                "RangeOrder:setRangeOrder:: Invalid notional in."
            );
            require(
                address(tokenIn) == address(_WETH9),
                "RangeOrder:setRangeOrder:: ETH range order should use WETH token."
            );

            _WETH9.deposit{value: msg.value}();
        } else
            tokenIn.safeTransferFrom(
                msg.sender,
                address(this),
                optionData_.notional
            );

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
        require(
            optionData_.maturity > block.timestamp,
            "Option::cancelOption: option expired"
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
                "RangeOrder:setRangeOrder:: Invalid price in."
            );
            require(
                address(tokenIn) == address(_WETH9),
                "RangeOrder:setRangeOrder:: ETH range order should use WETH token."
            );

            _WETH9.deposit{value: msg.value}();
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

        bool isCall = optionData_.optionType == OptionType.CALL;
        (, int24 tick, , , , , ) = optionData_.pool.slot0();
        int24 tickSpacing = optionData_.pool.tickSpacing();
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
            "Option:settleOption: invalid fee token."
        );

        {
            address optionBuyer = buyers[optionDataHash];

            delete hashById[tokenId_];
            delete taskById[tokenId_];
            delete buyers[optionDataHash];

            bool executeOption = isCall
                ? tick >= optionData_.strike + tickSpacing
                : tick <= optionData_.strike - tickSpacing;

            (uint256 amount0, uint256 amount1) = _collect(tokenId_, liquidity);

            if (feeToken == token0) {
                amount0 -= feeAmount;
            } else {
                amount1 -= feeAmount;
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

        IERC20(feeToken).safeTransfer(
            _gelato,
            feeAmount
        );

        _positionManager.burn(tokenId_);
    }

    function canSettle(uint256 tokenId_, OptionData calldata optionData_)
        public
        view
        returns (bool)
    {
        require(
            address(this) == _positionManager.ownerOf(tokenId_),
            "Option::settleOption: only owner"
        );
        bytes32 optionDataHash = keccak256(abi.encode(optionData_));
        require(
            hashById[tokenId_] == optionDataHash,
            "Option::settleOption: invalid hash"
        );
        require(
            buyers[optionDataHash] != address(0),
            "Option::settleOption: option not yet bought"
        );
        require(
            optionData_.maturity <= block.timestamp,
            "Option::settleOption: option not matured yet"
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
