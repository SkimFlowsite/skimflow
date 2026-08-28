// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { BaseHook } from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { BalanceDelta } from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { SwapParams } from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {
    BeforeSwapDelta,
    toBeforeSwapDelta,
    BeforeSwapDeltaLibrary
} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

/// @title  SkimFeeHook
/// @notice Uniswap v4 hook for the $SKIM pool. Every buy and every sell pays a
///         3% fee, always collected in ETH (never in $SKIM). The fee is forwarded
///         to `feeRecipient` — the Skimflow vault — which splits it 85% to stakers
///         and 15% to the treasury.
///
/// @dev    In the pool, currency0 = native ETH and currency1 = $SKIM. A BUY is
///         ETH -> SKIM (`zeroForOne == true`); a SELL is SKIM -> ETH
///         (`zeroForOne == false`). ETH (currency0) is the swap's *specified*
///         currency iff `zeroForOne == exactInput`. To always land the fee in ETH:
///           - when ETH is specified, skim it from the specified amount in `beforeSwap`;
///           - when ETH is unspecified, skim it from the ETH leg in `afterSwap`.
///         Requires beforeSwap + afterSwap with both return-delta flags, so the
///         deploy salt must be mined (HookMiner) to encode them in the address.
contract SkimFeeHook is BaseHook {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice Buy fee in basis points (300 = 3%).
    uint256 public constant BUY_FEE_BPS = 300;
    /// @notice Sell fee in basis points (300 = 3%).
    uint256 public constant SELL_FEE_BPS = 300;

    /// @notice Where ETH fees are sent — the Skimflow vault. Immutable.
    address public immutable feeRecipient;

    event FeeTaken(bool indexed isBuy, uint256 ethAmount);

    constructor(IPoolManager _manager, address _feeRecipient) BaseHook(_manager) {
        require(_feeRecipient != address(0), "ZERO_RECIPIENT");
        feeRecipient = _feeRecipient;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @dev ETH (currency0) is the specified currency here: skim the fee off it.
    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bool exactInput = params.amountSpecified < 0;
        bool ethIsSpecified = (params.zeroForOne == exactInput);
        if (!ethIsSpecified) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        uint256 specifiedAbs = params.amountSpecified < 0
            ? uint256(-params.amountSpecified)
            : uint256(params.amountSpecified);

        uint256 feeBps = params.zeroForOne ? BUY_FEE_BPS : SELL_FEE_BPS;
        uint256 feeAmount = (specifiedAbs * feeBps) / 10_000;
        if (feeAmount == 0) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        // ETH is currency0. Take it to the vault and charge the swapper by
        // returning a positive specified-delta.
        poolManager.take(key.currency0, feeRecipient, feeAmount);
        emit FeeTaken(params.zeroForOne, feeAmount);

        return
            (
                BaseHook.beforeSwap.selector,
                toBeforeSwapDelta(int128(int256(feeAmount)), int128(0)),
                0
            );
    }

    /// @dev ETH (currency0) is the unspecified currency here: skim the fee off the ETH leg.
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        bool exactInput = params.amountSpecified < 0;
        bool ethIsSpecified = (params.zeroForOne == exactInput);
        if (ethIsSpecified) {
            return (BaseHook.afterSwap.selector, int128(0)); // already taken in beforeSwap
        }

        // ETH (currency0) is unspecified; its net movement is delta.amount0().
        int128 ethDelta = delta.amount0();
        uint256 magnitude = ethDelta < 0 ? uint256(uint128(-ethDelta)) : uint256(uint128(ethDelta));

        uint256 feeBps = params.zeroForOne ? BUY_FEE_BPS : SELL_FEE_BPS;
        uint256 feeAmount = (magnitude * feeBps) / 10_000;
        if (feeAmount == 0) {
            return (BaseHook.afterSwap.selector, int128(0));
        }

        poolManager.take(key.currency0, feeRecipient, feeAmount);
        emit FeeTaken(params.zeroForOne, feeAmount);

        return (BaseHook.afterSwap.selector, int128(int256(feeAmount)));
    }
}
