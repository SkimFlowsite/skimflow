# Skimflow — Whitepaper

**Version 0.1 · Draft · Pre-launch**
Robinhood Chain · chain id `4663`

Skimflow turns trading fees into staking yield. Stake `$SKIM` and receive a pro-rata
share of the fees every trade pays, settled in ETH. This document describes the model,
the on-chain mechanism, the fee split, the accrual math, security assumptions, and risks.

---

## Abstract

Skimflow is a staking protocol whose rewards are funded by trading fees rather than token
emissions. A 3% fee in ETH is charged on every `$SKIM` trade, routed to a vault contract,
and distributed to stakers pro rata. Because rewards derive from fee revenue, there is no
inflation and no team-funded rewards budget; reward flow scales with trading volume.

## 1 · Motivation

Emission-based staking pays rewards in newly minted tokens. This has three structural
drawbacks:

- **Dilution.** Each reward increases supply, diluting holders who do not participate.
- **Finite duration.** Emissions are capped; the reward rate declines as they are exhausted.
- **Payout asset.** Rewards accrue in the staked token itself rather than an external asset.

Skimflow addresses these by paying rewards from fee revenue, denominated in ETH.

## 2 · Model

`$SKIM` trades on a Uniswap v4 pool that charges a fee on every swap. Rather than being
retained by the team or spent externally, that fee is distributed to stakers. A staker
receives a share of each fee proportional to their share of total stake, for the duration
of their stake.

Staking and claiming are non-custodial: staked `$SKIM` and accrued ETH are held by the
vault contract and withdrawable by their owner at any time. There are no lockups.

## 3 · Mechanism

### 3.1 Fee source

The `$SKIM` pool uses a Uniswap v4 hook that charges **3% in ETH on every swap**, on both
buys and sells. The fee is taken in ETH rather than in `$SKIM`, so rewards are a hard
asset and the token itself carries no transfer tax.

### 3.2 Routing

The hook's fee recipient is the **Skimflow vault contract**, not an externally owned
wallet. Every fee therefore arrives on chain at a contract whose only job is to account
for and distribute it.

### 3.3 Fee split

Each incoming fee is split on chain:

- **85%** streamed to stakers, in ETH, pro rata by share.
- **15%** to the protocol treasury, for liquidity, development, and operations.

The split is enforced by the contract, not by discretion, and is readable on the explorer.

### 3.4 Stake, claim, unstake

Staking deposits `$SKIM` and records your share. Claiming sends your accrued ETH to your
wallet. Unstaking returns your `$SKIM`. There are no epochs, no windows, and no penalties;
accrual is continuous.

## 4 · Accrual math

Rewards use a standard accumulator so that distribution is O(1) regardless of how many
stakers exist. The vault tracks a running `accRewardPerShare`. When a fee of `feeIn` ETH
arrives and `totalStaked` is non-zero:

```solidity
// on each fee arrival (85% of the 3% trade fee)
accRewardPerShare += feeIn * 1e18 / totalStaked;

// a staker's claimable ETH at any time
pending(user) = stake[user] * accRewardPerShare / 1e18 - rewardDebt[user];

// on stake / unstake / claim, settle then reset the debt
rewardDebt[user] = stake[user] * accRewardPerShare / 1e18;
```

Because `accRewardPerShare` only ever moves forward while you are staked, you earn exactly
your share of the fees that arrive during your staking period, and nothing before or after.
Depositing does not dilute past rewards, and leaving does not forfeit earned rewards.

## 5 · The `$SKIM` token

`$SKIM` is a fixed-supply ERC-20 of **1,000,000,000** tokens, minted once, with no transfer
tax. Its single utility is access to the fee stream: to skim, you stake `$SKIM`. Demand to
earn therefore translates into demand to hold and stake the token. Final allocation is
published at launch; the founder allocation is staked into the same vault under the same
rules as everyone else.

## 6 · Protocol treasury

The 15% treasury share is the only revenue the protocol keeps, and it is transparent by
design. It funds deepening the liquidity pool, contract audits and development, and ongoing
operations. It is not a hidden tax: the split is stated here, shown on the site, and
enforced on chain.

## 7 · Security & trust assumptions

- **Non-custodial.** Staked `$SKIM` and accrued ETH are held by the vault and withdrawable only by their owner.
- **No admin over stakes.** There is no function that lets any owner pause withdrawals or move deposited funds. Exit never needs permission.
- **Fixed rules.** The fee split and accrual logic are set in the deployed contract; the core is designed to be non-upgradeable.
- **Verifiable.** The vault, the token, and every distribution are readable on chain via Blockscout; the protocol relies on no off-chain state.
- **No stuck fees.** When no one is staked, a fee has no stakers to accrue to, so the whole amount routes to the treasury rather than being lost. A `sweepUnaccounted()` function can recover rounding dust or ETH force-sent to the contract, but it is mathematically bounded to `balance − rewards owed to stakers` and can never touch a staker's earned ETH.
- **Liveness-isolated treasury.** The 15% treasury payout is best-effort and cannot revert, so even a misconfigured treasury can never brick swaps, fee settlement, or staker claims; an undelivered cut is simply left recoverable by `sweepUnaccounted()`.

## 8 · Risks

- **Variable yield.** Rewards track trading volume. In quiet markets the stream pays little or nothing. No rate is fixed or guaranteed.
- **Volume dependence.** The model has no yield without trades. It is not a fixed-income product.
- **Smart-contract risk.** On-chain code can contain bugs. Review the contracts and never stake more than you can afford to lose.
- **Timing.** Because accrual is continuous, rewards favour those staked when volume occurs. Staking around known large trades is possible but the accumulator limits its edge.
- **Market risk.** `$SKIM` is a volatile asset. Its price can fall regardless of fee income.

## 9 · Parameters

| Parameter    | Value                                |
| ------------ | ------------------------------------ |
| Chain        | Robinhood Chain · `4663`             |
| Token        | `$SKIM` · 1,000,000,000 fixed supply |
| Trade fee    | 3% per swap, in ETH                  |
| Fee split    | 85% stakers · 15% treasury           |
| Lockup       | None                                 |
| Custody      | Non-custodial                        |
| Payout asset | ETH                                  |
| Contracts    | Published at launch · Blockscout     |

## 10 · Roadmap

| Phase   | Milestone     | Detail                                                                       |
| ------- | ------------- | ---------------------------------------------------------------------------- |
| Phase 0 | Model & docs  | Publish the mechanism, the fee split, and this document. *(current phase)*    |
| Phase 1 | Contracts     | Ship the vault and the fee hook, verified on Blockscout, 85/15 split on chain.|
| Phase 2 | Launch        | Deploy `$SKIM`, seed liquidity, open the vault. Staking and claiming go live. |
| Phase 3 | Depth         | Grow volume and liquidity, and use the treasury to reinforce both.           |

---

*This document is a draft describing intended behaviour and is not final until the
contracts are deployed and verified. Rewards depend on real trading volume and are not
guaranteed. Skimflow is experimental on-chain software. Nothing here is financial advice.*
