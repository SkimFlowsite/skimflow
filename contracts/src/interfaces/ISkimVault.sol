// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title ISkimVault
/// @notice Public interface for the Skimflow staking vault.
/// @dev Stake $SKIM, accrue ETH from the pool's 3% trade fee (85% staker share),
///      claim and unstake at any time. Non-custodial: no admin can move or lock stakes.
///      Reward accounting uses an O(1) `accRewardPerShare` accumulator; see the
///      whitepaper section 4 for the derivation.
interface ISkimVault {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when `user` stakes `amount` of $SKIM.
    event Staked(address indexed user, uint256 amount);

    /// @notice Emitted when `user` unstakes `amount` of $SKIM.
    event Unstaked(address indexed user, uint256 amount);

    /// @notice Emitted when `user` claims `ethAmount` of accrued rewards.
    event Claimed(address indexed user, uint256 ethAmount);

    /// @notice Emitted when `ethAmount` (the 85% staker share) is distributed to the pool.
    event FeeDistributed(uint256 ethAmount, uint256 accRewardPerShare);

    /*//////////////////////////////////////////////////////////////
                                MUTATIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice Stake `amount` of $SKIM. Settles any pending rewards first.
    function stake(uint256 amount) external;

    /// @notice Unstake `amount` of $SKIM back to the caller. Settles pending rewards first.
    function unstake(uint256 amount) external;

    /// @notice Send the caller's accrued ETH rewards to their wallet.
    /// @return ethAmount The amount of ETH transferred.
    function claim() external returns (uint256 ethAmount);

    /// @notice Receive a fee distribution from the hook and update `accRewardPerShare`.
    /// @dev Only callable by the configured fee source (the v4 hook / forwarder).
    ///      The caller sends the 85% staker share; the 15% treasury share is routed
    ///      separately and never enters the staker accumulator.
    function notifyFee() external payable;

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice The $SKIM token being staked.
    function skim() external view returns (address);

    /// @notice The protocol treasury that receives the 15% share.
    function treasury() external view returns (address);

    /// @notice Total $SKIM currently staked in the vault.
    function totalStaked() external view returns (uint256);

    /// @notice Amount of $SKIM `user` has staked.
    function stakeOf(address user) external view returns (uint256);

    /// @notice ETH currently claimable by `user`.
    function pending(address user) external view returns (uint256);
}
