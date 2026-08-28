# Skimflow Contracts

Solidity contracts for the Skimflow protocol, built with [Foundry](https://book.getfoundry.sh).

## Components

| Contract        | Role                                                                             | Status              |
| --------------- | -------------------------------------------------------------------------------- | ------------------- |
| `SkimVault`     | Stake `$SKIM`, accrue ETH via `accRewardPerShare`, claim / unstake anytime.      | Implemented, tested |
| `SkimFeeHook`   | Uniswap v4 hook — takes 3% in ETH per swap, forwards to the vault as fee recipient. | Implemented         |
| `SKIM` (ERC-20) | Fixed-supply 1,000,000,000 token, no transfer tax.                               | In development      |

`SkimVault` ([`src/SkimVault.sol`](src/SkimVault.sol)) implements
[`ISkimVault`](src/interfaces/ISkimVault.sol): the **85% stakers / 15% treasury** split
and the O(1) accrual accumulator described in the
[whitepaper](../docs/whitepaper.md#4--accrual-math). It is deliberately trustless — no
owner, no admin, no function that can pause or move a user's stake; the token, treasury,
and split are fixed at deployment. A permissionless `sweepUnaccounted()` recovers only
ETH that is not owed to any staker (rounding dust or force-sent ETH), sending it to the
immutable treasury — it is provably unable to touch staker rewards. Covered by a unit +
fuzz suite in [`test/SkimVault.t.sol`](test/SkimVault.t.sol).

## Status

Phase 1 of the [roadmap](../README.md#roadmap). The vault and fee hook are being
finalized and audited before deployment. Once deployed on Robinhood Chain (`4663`) and
verified on Blockscout, this README will carry the addresses:

| Contract    | Address        |
| ----------- | -------------- |
| `SKIM`      | _at launch_    |
| `SkimVault` | _at launch_    |
| `SkimFeeHook` | _at launch_  |

## Build & test

```bash
git submodule update --init --recursive   # fetches forge-std
forge build
forge test -vvv
```

## Design principles

- **Non-upgradeable core.** No admin function can pause withdrawals or move deposited stakes.
- **Fee in ETH, not in token.** Rewards are a hard asset; `$SKIM` carries no transfer tax.
- **Everything on the explorer.** The split and every distribution are readable on chain.
