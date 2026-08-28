<div align="center">

<img src="web/assets/mark.png" width="88" alt="Skimflow" />

# Skimflow

**Skim the fee. Not the tokens.**

Real ETH yield from trade fees — stake `$SKIM`, collect a pro-rata share of every
trade's fee in ETH, on [Robinhood Chain](https://robinhood.com) (chain id `4663`).

[![Site](https://img.shields.io/badge/site-skimflow.site-EF5A26)](https://skimflow.site)
[![Docs](https://img.shields.io/badge/docs-whitepaper-111210)](https://skimflow.site/docs)
[![X](https://img.shields.io/badge/X-@SkimFlowsite-111210)](https://x.com/SkimFlowsite)
[![Status](https://img.shields.io/badge/status-pre--launch-EF5A26)](#roadmap)
[![License](https://img.shields.io/badge/license-MIT-111210)](LICENSE)

</div>

---

## What is Skimflow

Most staking pays rewards by **printing new tokens**. That dilutes holders and only
lasts while emissions last. Skimflow pays rewards from a real, recurring source
instead: the fee charged on every trade of its own token.

A **3% fee in ETH** is taken on each buy and sell, routed to a vault contract, and
streamed to stakers pro rata. There is no inflation and no team funding of rewards.
**Yield exists exactly as long as people trade.**

> In one line: **stake `$SKIM`, and you become the house.** Every trade pays a toll,
> and stakers collect it in ETH, proportional to their share of the staked pool.

## How it works

```
          buy 3%  ─┐
          sell 3% ─┼──►  v4 fee hook  ──►  Skimflow vault  ──►  85%  ──►  stakers (ETH, pro rata)
       (fee in ETH)                          (fee recipient)     15%  ──►  protocol treasury
```

1. The `$SKIM` Uniswap v4 pool charges **3% in ETH** on every swap (buy and sell).
2. The hook's fee recipient is the **vault contract**, not a wallet.
3. Each fee is split on chain: **85% to stakers, 15% to treasury**.
4. Stakers **stake / claim / unstake** anytime — no lockups, no epochs, non-custodial.

## Accrual model

Rewards use a standard O(1) accumulator so distribution cost is independent of the
number of stakers. The vault tracks a running `accRewardPerShare`:

```solidity
// on each fee arrival (the 85% staker share of the 3% trade fee)
accRewardPerShare += feeIn * 1e18 / totalStaked;

// a staker's claimable ETH at any time
pending(user) = stake[user] * accRewardPerShare / 1e18 - rewardDebt[user];

// on stake / unstake / claim: settle, then reset the debt
rewardDebt[user] = stake[user] * accRewardPerShare / 1e18;
```

You earn exactly your share of the fees that arrive **while you are staked** — nothing
before, nothing after. Full derivation in the [whitepaper](docs/whitepaper.md).

## Repository layout

| Path            | What's inside                                                        |
| --------------- | ------------------------------------------------------------------- |
| `docs/`         | Whitepaper and protocol documentation                               |
| `contracts/`    | Solidity contracts — vault + fee hook (Foundry). See status below.  |
| `web/`          | Source of the live site at [skimflow.site](https://skimflow.site)   |

## Parameters

| Parameter    | Value                              |
| ------------ | ---------------------------------- |
| Chain        | Robinhood Chain · `4663`           |
| Token        | `$SKIM` · 1,000,000,000 fixed supply |
| Trade fee    | 3% per swap, in ETH                |
| Fee split    | 85% stakers · 15% treasury         |
| Lockup       | None                               |
| Custody      | Non-custodial                      |
| Payout asset | ETH                                |

## Roadmap

- [x] **Phase 0 — Model & docs.** Publish the mechanism, the fee split, and the whitepaper.
- [ ] **Phase 1 — Contracts.** Ship the vault and fee hook, verified on Blockscout, 85/15 split enforced on chain.
- [ ] **Phase 2 — Launch.** Deploy `$SKIM`, seed liquidity, open the vault.
- [ ] **Phase 3 — Depth.** Grow volume and liquidity; use the treasury to reinforce both.

## Status

**Pre-launch.** The model, documentation, and site are live. The vault and fee-hook
contracts are being finalized (Phase 1) and this repository will carry the verified
addresses once deployed. See [`contracts/README.md`](contracts/README.md).

## Disclaimer

Skimflow is experimental on-chain software. Rewards depend on real trading volume and
are **not guaranteed**; in quiet markets the stream pays little or nothing. Nothing in
this repository is financial advice. Review the contracts and never stake more than you
can afford to lose.

## License

[MIT](LICENSE)
