// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Deployers } from "v4-core/test/utils/Deployers.sol";
import { Hooks } from "@uniswap/v4-core/src/libraries/Hooks.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { Currency, CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";

import { SkimFeeHook } from "../src/SkimFeeHook.sol";
import { SkimVault } from "../src/SkimVault.sol";

interface IApprovable {
    function approve(address, uint256) external returns (bool);
}

/// @notice End-to-end tests: deploy a real Uniswap v4 PoolManager, an ETH/$SKIM pool
///         wired to SkimFeeHook, and verify that real swaps route a 3% ETH fee into the
///         vault with the 85/15 split.
contract SkimFeeHookIntegrationTest is Deployers {
    SkimVault internal vault;
    SkimFeeHook internal hook;
    PoolKey internal poolKey;

    Currency internal token; // currency1 = $SKIM (currency0 = native ETH)
    address internal treasury = makeAddr("treasury");

    function setUp() public {
        vm.deal(address(this), 1_000 ether);

        deployFreshManagerAndRouters();
        token = deployMintAndApproveCurrency(); // ERC20 minted to this contract

        // vault stakes $SKIM (currency1) and receives the ETH fee
        vault = new SkimVault(Currency.unwrap(token), treasury);

        // hook must live at an address whose low bits encode its permissions
        address hookAddr = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                    | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo("SkimFeeHook.sol:SkimFeeHook", abi.encode(manager, address(vault)), hookAddr);
        hook = SkimFeeHook(hookAddr);

        // native ETH / token pool with the hook + initial liquidity
        (poolKey,) = initPoolAndAddLiquidityETH(
            CurrencyLibrary.ADDRESS_ZERO, token, IHooks(hookAddr), 3000, SQRT_PRICE_1_1, 1 ether
        );

        // stake so the 85% share stays in the vault (single staker = this contract)
        IApprovable(Currency.unwrap(token)).approve(address(vault), type(uint256).max);
        vault.stake(1_000 ether);
    }

    /// BUY, exact input: fee is taken in beforeSwap off the specified ETH input.
    function test_BuyExactInput_ChargesThreePercentInEth() public {
        uint256 amountIn = 0.01 ether;

        uint256 vaultBefore = address(vault).balance;
        uint256 treasuryBefore = treasury.balance;

        // zeroForOne = true (ETH -> token), negative amount = exact input
        swapNativeInput(poolKey, true, -int256(amountIn), ZERO_BYTES, amountIn);

        uint256 fee = (amountIn * 300) / 10_000; // 3%
        uint256 treasuryCut = (fee * 1500) / 10_000; // 15%
        uint256 stakerCut = fee - treasuryCut; // 85%

        assertEq(treasury.balance - treasuryBefore, treasuryCut, "treasury got 15% of the 3% fee");
        assertEq(
            address(vault).balance - vaultBefore, stakerCut, "vault holds the 85% staker share"
        );
        assertEq(vault.pending(address(this)), stakerCut, "staker credited the 85% share");
    }

    /// SELL, exact input: fee is taken in afterSwap off the ETH output leg.
    function test_SellExactInput_ChargesFeeInEth() public {
        uint256 amountIn = 1 ether; // token in

        uint256 vaultBefore = address(vault).balance;
        uint256 treasuryBefore = treasury.balance;

        // zeroForOne = false (token -> ETH), exact input, no msg.value
        swap(poolKey, false, -int256(amountIn), ZERO_BYTES);

        uint256 vaultGain = address(vault).balance - vaultBefore;
        uint256 treasuryGain = treasury.balance - treasuryBefore;
        uint256 feeTotal = vaultGain + treasuryGain;

        assertGt(feeTotal, 0, "a fee was taken in ETH on the sell");
        assertEq(treasuryGain, (feeTotal * 1500) / 10_000, "split is 15% treasury / 85% stakers");
        // pending equals the vault share minus at most accumulator rounding dust,
        // and never exceeds it (dust stays locked in the vault, never over-credited).
        assertLe(vault.pending(address(this)), vaultGain, "never over-credited");
        assertApproxEqAbs(
            vault.pending(address(this)), vaultGain, 1e10, "staker credited ~vault share"
        );
    }

    /// The fee always lands in ETH, never in the token.
    function test_FeeIsAlwaysEthNeverToken() public {
        uint256 vaultTokenBefore = IERC20Balance(Currency.unwrap(token)).balanceOf(address(vault));

        swapNativeInput(poolKey, true, -int256(uint256(0.02 ether)), ZERO_BYTES, 0.02 ether);

        // the vault only ever staked-principal in tokens; no fee token should arrive
        assertEq(
            IERC20Balance(Currency.unwrap(token)).balanceOf(address(vault)),
            vaultTokenBefore,
            "no token fee reached the vault"
        );
        assertGt(address(vault).balance, 0, "ETH fee did reach the vault");
    }
}

interface IERC20Balance {
    function balanceOf(address) external view returns (uint256);
}
