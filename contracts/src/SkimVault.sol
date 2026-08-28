// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC20 } from "./interfaces/IERC20.sol";
import { ISkimVault } from "./interfaces/ISkimVault.sol";

/// @title  SkimVault
/// @notice Non-custodial staking vault for Skimflow. Stake $SKIM to earn a pro-rata
///         share, in ETH, of the 3% fee charged on every $SKIM trade.
/// @dev    Rewards use an O(1) `accRewardPerShare` accumulator (MasterChef-style), so
///         distributing a fee costs the same regardless of the number of stakers.
///
///         Trust model — deliberately minimal:
///           - There is NO owner and NO admin function. The token, the treasury, and
///             the fee split are fixed at deployment and can never change.
///           - No function can pause withdrawals or move a user's deposited stake.
///             Staking, claiming, and unstaking never require permission.
///           - Fee intake is permissionless: the v4 hook forwards fees here, but any
///             address may top up the stream by sending ETH.
contract SkimVault is ISkimVault {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fixed-point scalar for the reward accumulator.
    uint256 private constant ACC_PRECISION = 1e12;

    /// @dev Basis-point denominator.
    uint256 private constant BPS = 10_000;

    /// @notice Treasury share of every fee, in basis points (15%).
    uint256 public constant TREASURY_BPS = 1_500;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The $SKIM token being staked.
    IERC20 private immutable _skim;

    /// @dev Recipient of the 15% treasury share. Immutable — no admin can redirect it.
    address private immutable _treasury;

    /*//////////////////////////////////////////////////////////////
                                  STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Running reward accumulator: ETH-per-share scaled by `ACC_PRECISION`.
    uint256 public accRewardPerShare;

    uint256 private _totalStaked;
    mapping(address => uint256) private _stake;
    mapping(address => uint256) private _rewardDebt;
    mapping(address => uint256) private _accrued; // settled-but-unclaimed ETH

    /// @notice Cumulative ETH ever credited to stakers (the 85% cut, all-time).
    uint256 public totalStakerRewards;
    /// @notice Cumulative ETH ever claimed by stakers.
    uint256 public totalClaimed;

    /*//////////////////////////////////////////////////////////////
                             REENTRANCY GUARD
    //////////////////////////////////////////////////////////////*/

    uint256 private _locked = 1;

    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param skim_     Address of the $SKIM ERC-20.
    /// @param treasury_ Address that receives the 15% treasury share.
    constructor(address skim_, address treasury_) {
        require(skim_ != address(0) && treasury_ != address(0), "ZERO_ADDR");
        _skim = IERC20(skim_);
        _treasury = treasury_;
    }

    /*//////////////////////////////////////////////////////////////
                              FEE INTAKE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISkimVault
    function notifyFee() external payable nonReentrant {
        _distribute(msg.value);
    }

    /// @notice Plain ETH transfers are treated as a fee distribution.
    receive() external payable nonReentrant {
        _distribute(msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                              STAKE / EXIT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISkimVault
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "ZERO_AMOUNT");
        _settle(msg.sender);

        uint256 balBefore = _skim.balanceOf(address(this));
        _safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = _skim.balanceOf(address(this)) - balBefore;

        _stake[msg.sender] += received;
        _totalStaked += received;
        _rewardDebt[msg.sender] = (_stake[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        emit Staked(msg.sender, received);
    }

    /// @inheritdoc ISkimVault
    function unstake(uint256 amount) external nonReentrant {
        require(amount > 0 && amount <= _stake[msg.sender], "BAD_AMOUNT");
        _settle(msg.sender);

        _stake[msg.sender] -= amount;
        _totalStaked -= amount;
        _rewardDebt[msg.sender] = (_stake[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        _safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    /// @inheritdoc ISkimVault
    function claim() external nonReentrant returns (uint256 ethAmount) {
        _settle(msg.sender);
        ethAmount = _accrued[msg.sender];
        require(ethAmount > 0, "NOTHING_TO_CLAIM");

        _accrued[msg.sender] = 0; // effects before interaction
        totalClaimed += ethAmount;
        (bool ok,) = msg.sender.call{ value: ethAmount }("");
        require(ok, "ETH_TRANSFER_FAIL");

        emit Claimed(msg.sender, ethAmount);
    }

    /// @inheritdoc ISkimVault
    function sweepUnaccounted() external nonReentrant returns (uint256 ethAmount) {
        ethAmount = unaccounted();
        require(ethAmount > 0, "NOTHING_TO_SWEEP");

        (bool ok,) = _treasury.call{ value: ethAmount }("");
        require(ok, "SWEEP_TRANSFER_FAIL");

        emit Swept(ethAmount);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISkimVault
    function skim() external view returns (address) {
        return address(_skim);
    }

    /// @inheritdoc ISkimVault
    function treasury() external view returns (address) {
        return _treasury;
    }

    /// @inheritdoc ISkimVault
    function totalStaked() external view returns (uint256) {
        return _totalStaked;
    }

    /// @inheritdoc ISkimVault
    function stakeOf(address user) external view returns (uint256) {
        return _stake[user];
    }

    /// @inheritdoc ISkimVault
    function pending(address user) public view returns (uint256) {
        uint256 acc = (_stake[user] * accRewardPerShare) / ACC_PRECISION;
        return _accrued[user] + (acc - _rewardDebt[user]);
    }

    /// @inheritdoc ISkimVault
    function unaccounted() public view returns (uint256) {
        // Everything still owed to stakers (over-estimated by rounding dust, so this
        // never under-protects). Anything the contract holds beyond it is unaccounted.
        uint256 owed = totalStakerRewards - totalClaimed;
        uint256 bal = address(this).balance;
        return bal > owed ? bal - owed : 0;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Split an incoming fee: 15% to treasury, 85% into the staker accumulator.
    ///      With no stakers, the full amount goes to the treasury (nothing to accrue).
    function _distribute(uint256 amount) private {
        if (amount == 0) return;

        uint256 stakersCut;
        uint256 treasuryCut;
        if (_totalStaked == 0) {
            treasuryCut = amount;
        } else {
            treasuryCut = (amount * TREASURY_BPS) / BPS;
            stakersCut = amount - treasuryCut;
            accRewardPerShare += (stakersCut * ACC_PRECISION) / _totalStaked;
            totalStakerRewards += stakersCut;
        }

        emit FeeDistributed(stakersCut, accRewardPerShare);

        if (treasuryCut > 0) {
            (bool ok,) = _treasury.call{ value: treasuryCut }("");
            require(ok, "TREASURY_TRANSFER_FAIL");
        }
    }

    /// @dev Move a user's newly-earned rewards into their settled balance.
    function _settle(address user) private {
        uint256 acc = (_stake[user] * accRewardPerShare) / ACC_PRECISION;
        uint256 owed = acc - _rewardDebt[user];
        if (owed > 0) _accrued[user] += owed;
        _rewardDebt[user] = acc;
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool ok, bytes memory data) =
            address(_skim).call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAIL");
    }

    function _safeTransferFrom(address from, address to, uint256 amount) private {
        (bool ok, bytes memory data) = address(_skim)
            .call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAIL");
    }
}
