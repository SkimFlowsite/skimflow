<div align="center">

<img src="web/assets/mark.png" width="88" alt="Skimflow" />

# Skimflow

Skim the fee. Not the tokens.

[![CI](https://github.com/SkimFlowsite/skimflow/actions/workflows/ci.yml/badge.svg)](https://github.com/SkimFlowsite/skimflow/actions/workflows/ci.yml)
[![Site](https://img.shields.io/badge/site-skimflow.site-EF5A26)](https://skimflow.site)
[![Docs](https://img.shields.io/badge/docs-whitepaper-111210)](https://skimflow.site/docs)
[![X](https://img.shields.io/badge/X-@SkimFlowsite-111210)](https://x.com/SkimFlowsite)
[![License](https://img.shields.io/badge/license-MIT-111210)](LICENSE)

</div>

---

Skimflow is a staking protocol on Robinhood Chain (chain id `4663`). Staking `$SKIM`
earns a pro-rata share, paid in ETH, of the fee charged on every `$SKIM` trade. Rewards
are funded by trading fees rather than token emissions, so there is no inflation and no
team-funded rewards budget.

## Architecture

```
  buy  3% ─┐
  sell 3% ─┼──►  SkimFeeHook (v4)  ──►  SkimVault  ──►  85%  ──►  stakers (ETH, pro rata)
 (in ETH)                             (fee recipient)   15%  ──►  treasury
```

- **SkimFeeHook** — a Uniswap v4 hook on the `$SKIM`/ETH pool. It takes 3% of every swap
  in ETH (buys and sells) and forwards it to the vault.
- **SkimVault** — receives the fee, keeps 15% for the treasury, and distributes 85% to
  stakers via a reward-per-share accumulator. Staking, claiming, and unstaking are
  permissionless and non-custodial. There is no owner and no admin over stakes.

## Contracts

| Contract      | Description                                                        | Status              |
| ------------- | ----------------------------------------------------------------- | ------------------- |
| `SkimVault`   | Staking vault. Accrues ETH per share; claim/unstake anytime.      | Implemented, tested |
| `SkimFeeHook` | v4 hook. 3% ETH fee per swap, forwarded to the vault.             | Implemented         |
| `SKIM`        | Fixed-supply ERC-20, 1,000,000,000 units, no transfer tax.        | Pending deployment  |

Source: [`contracts/`](contracts). Interfaces in
[`contracts/src/interfaces`](contracts/src/interfaces).

## Reward accounting

Distribution is O(1) in the number of stakers. The vault maintains a running
`accRewardPerShare`; a staker's balance is derived from it and a per-account
`rewardDebt` set on each interaction.

```solidity
// on each fee (the 85% staker share)
accRewardPerShare += feeIn * ACC_PRECISION / totalStaked;

// claimable at any time
pending(user) = stake[user] * accRewardPerShare / ACC_PRECISION - rewardDebt[user];
```

A staker earns exactly the fees that arrive while their stake is active. Derivation:
[whitepaper §4](docs/whitepaper.md#4--accrual-math).

## Build

```bash
git clone --recurse-submodules https://github.com/SkimFlowsite/skimflow
cd skimflow/contracts
forge build
forge test
```

## Parameters

| Parameter    | Value                                |
| ------------ | ------------------------------------ |
| Chain        | Robinhood Chain · `4663`             |
| Token        | `$SKIM` · 1,000,000,000 fixed supply |
| Trade fee    | 3% per swap, in ETH                  |
| Fee split    | 85% stakers · 15% treasury           |
| Lockup       | None                                 |
| Custody      | Non-custodial                        |
| Payout asset | ETH                                  |

## Layout

| Path         | Contents                                          |
| ------------ | ------------------------------------------------- |
| `contracts/` | Solidity sources and tests (Foundry)              |
| `docs/`      | Whitepaper and protocol documentation             |
| `web/`       | Source of [skimflow.site](https://skimflow.site)  |

## Status

Pre-launch. The vault and hook are implemented and covered by the test suite; the token
is not yet deployed. Verified addresses will be published here on deployment. See
[CHANGELOG](CHANGELOG.md).

## Security

The core is designed to be non-upgradeable: no owner, no admin over stakes, fixed fee
split. Report vulnerabilities per [SECURITY.md](SECURITY.md). An external audit is
planned before mainnet deployment.

Rewards depend on trading volume and are not guaranteed. Skimflow is experimental
software; review the contracts before use.

## License

[MIT](LICENSE)
