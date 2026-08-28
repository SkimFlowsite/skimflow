// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { SkimVault } from "../src/SkimVault.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract SkimVaultTest is Test {
    MockERC20 internal skim;
    SkimVault internal vault;

    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant ONE = 1e18;

    function setUp() public {
        skim = new MockERC20();
        vault = new SkimVault(address(skim), treasury);
        _fund(alice, 1_000 * ONE);
        _fund(bob, 1_000 * ONE);
    }

    function _fund(address who, uint256 amt) internal {
        skim.mint(who, amt);
        vm.prank(who);
        skim.approve(address(vault), type(uint256).max);
    }

    function _stake(address who, uint256 amt) internal {
        vm.prank(who);
        vault.stake(amt);
    }

    /// @dev Send a fee into the vault as the hook would.
    function _fee(uint256 amt) internal {
        vm.deal(address(this), amt);
        vault.notifyFee{ value: amt }();
    }

    /*//////////////////////////////////////////////////////////////
                                 BASICS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(vault.skim(), address(skim));
        assertEq(vault.treasury(), treasury);
        assertEq(vault.TREASURY_BPS(), 1_500);
    }

    function test_RevertOnZeroAddressConstructor() public {
        vm.expectRevert("ZERO_ADDR");
        new SkimVault(address(0), treasury);
    }

    function test_StakeMovesTokens() public {
        _stake(alice, 100 * ONE);
        assertEq(vault.stakeOf(alice), 100 * ONE);
        assertEq(vault.totalStaked(), 100 * ONE);
        assertEq(skim.balanceOf(address(vault)), 100 * ONE);
    }

    /*//////////////////////////////////////////////////////////////
                             FEE SPLIT 85/15
    //////////////////////////////////////////////////////////////*/

    function test_SingleStakerEarns85Percent() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);

        assertEq(treasury.balance, 0.15 * 1e18, "treasury 15%");
        assertEq(vault.pending(alice), 0.85 * 1e18, "staker 85%");
    }

    function test_ProportionalSplitAcrossStakers() public {
        _stake(alice, 100 * ONE); // 25%
        _stake(bob, 300 * ONE); // 75%
        _fee(1 * ONE);

        // 0.85 ETH split 1:3
        assertEq(vault.pending(alice), 0.2125 * 1e18);
        assertEq(vault.pending(bob), 0.6375 * 1e18);
        assertEq(treasury.balance, 0.15 * 1e18);
    }

    function test_LateStakerGetsNoPastRewards() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE); // only alice staked -> all 0.85 to alice

        _stake(bob, 100 * ONE); // now 50/50
        _fee(1 * ONE); // 0.85 split evenly -> 0.425 each

        assertEq(vault.pending(alice), 0.85 * 1e18 + 0.425 * 1e18);
        assertEq(vault.pending(bob), 0.425 * 1e18);
    }

    function test_FeeWithNoStakersAllToTreasury() public {
        _fee(1 * ONE);
        assertEq(treasury.balance, 1 * ONE);
        assertEq(vault.accRewardPerShare(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM / UNSTAKE
    //////////////////////////////////////////////////////////////*/

    function test_ClaimTransfersAndZeroes() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);

        uint256 before = alice.balance;
        vm.prank(alice);
        uint256 got = vault.claim();

        assertEq(got, 0.85 * 1e18);
        assertEq(alice.balance - before, 0.85 * 1e18);
        assertEq(vault.pending(alice), 0);
    }

    function test_CannotClaimTwice() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);

        vm.prank(alice);
        vault.claim();
        vm.prank(alice);
        vm.expectRevert("NOTHING_TO_CLAIM");
        vault.claim();
    }

    function test_UnstakeReturnsTokensAndKeepsRewards() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);

        vm.prank(alice);
        vault.unstake(100 * ONE);

        assertEq(skim.balanceOf(alice), 1_000 * ONE, "tokens back");
        assertEq(vault.totalStaked(), 0);
        // earned rewards survive the exit
        assertEq(vault.pending(alice), 0.85 * 1e18);

        vm.prank(alice);
        assertEq(vault.claim(), 0.85 * 1e18);
    }

    function test_RewardsStopAccruingAfterUnstake() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE); // alice earns 0.85
        vm.prank(alice);
        vault.unstake(100 * ONE);

        _stake(bob, 100 * ONE);
        _fee(1 * ONE); // only bob earns now

        assertEq(vault.pending(alice), 0.85 * 1e18); // unchanged
        assertEq(vault.pending(bob), 0.85 * 1e18);
    }

    function test_RevertUnstakeMoreThanStaked() public {
        _stake(alice, 100 * ONE);
        vm.prank(alice);
        vm.expectRevert("BAD_AMOUNT");
        vault.unstake(101 * ONE);
    }

    /*//////////////////////////////////////////////////////////////
                            SWEEP UNACCOUNTED
    //////////////////////////////////////////////////////////////*/

    function test_FeeLeavesOnlyStakerShareInVault() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);
        // 0.15 already sent to treasury; only the 0.85 staker share sits in the vault
        assertEq(address(vault).balance, 0.85 * 1e18);
        assertEq(vault.unaccounted(), 0, "nothing unaccounted");
    }

    function test_SweepCannotTouchStakerRewards() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE);

        // the 0.85 is owed to alice -> sweep must find nothing
        vm.expectRevert("NOTHING_TO_SWEEP");
        vault.sweepUnaccounted();

        // alice still gets her full reward
        vm.prank(alice);
        assertEq(vault.claim(), 0.85 * 1e18);
    }

    function test_SweepRecoversForceSentEth() public {
        _stake(alice, 100 * ONE);
        _fee(1 * ONE); // vault holds 0.85 owed to alice

        // someone force-sends 0.5 ETH outside the fee path (e.g. selfdestruct)
        vm.deal(address(vault), address(vault).balance + 0.5 * 1e18);

        assertEq(vault.unaccounted(), 0.5 * 1e18);
        uint256 tBefore = treasury.balance;
        uint256 got = vault.sweepUnaccounted();

        assertEq(got, 0.5 * 1e18);
        assertEq(treasury.balance - tBefore, 0.5 * 1e18);
        // alice's reward untouched
        assertEq(vault.pending(alice), 0.85 * 1e18);
        vm.prank(alice);
        assertEq(vault.claim(), 0.85 * 1e18);
    }

    function test_SweepRevertsWhenNothing() public {
        vm.expectRevert("NOTHING_TO_SWEEP");
        vault.sweepUnaccounted();
    }

    /*//////////////////////////////////////////////////////////////
                              INVARIANT-ish
    //////////////////////////////////////////////////////////////*/

    function testFuzz_NeverDistributeMoreThanFee(uint96 feeAmt, uint96 stakeRaw) public {
        uint256 s = bound(uint256(stakeRaw), 1e6, 1_000 * ONE);
        _stake(alice, s);
        uint256 f = uint256(feeAmt);
        _fee(f);

        // treasury always gets exactly its 15% (floored)
        uint256 expectedTreasury = (f * 1500) / 10_000;
        assertEq(treasury.balance, expectedTreasury, "treasury exact");

        // a single staker can never be owed more than the 85% cut...
        uint256 stakersCut = f - expectedTreasury;
        assertLe(vault.pending(alice), stakersCut, "no over-credit");

        // ...and treasury + claimable never exceeds what came in (rounding dust stays put)
        assertLe(treasury.balance + vault.pending(alice), f, "no over-distribution");
    }
}
