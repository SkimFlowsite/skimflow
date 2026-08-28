# Skimflow Contracts

Solidity contracts for the Skimflow protocol, built with [Foundry](https://book.getfoundry.sh).

## Components

| Contract        | Role                                                                             | Status         |
| --------------- | -------------------------------------------------------------------------------- | -------------- |
| `SkimVault`     | Stake `$SKIM`, accrue ETH via `accRewardPerShare`, claim / unstake anytime.      | In development |
| `SkimFeeHook`   | Uniswap v4 hook — takes 3% in ETH per swap, forwards to the vault as fee recipient. | In development |
| `SKIM` (ERC-20) | Fixed-supply 1,000,000,000 token, no transfer tax.                               | In development |

The public interface the vault will implement is sketched in
[`src/interfaces/ISkimVault.sol`](src/interfaces/ISkimVault.sol). The fee split
(**85% stakers / 15% treasury**) and the O(1) accrual accumulator are described in the
[whitepaper](../docs/whitepaper.md#4--accrual-math).

## Status

Phase 1 of the [roadmap](../README.md#roadmap). The vault and fee hook are being
finalized and audited before deployment. Once deployed on Robinhood Chain (`4663`) and
verified on Blockscout, this README will carry the addresses:

| Contract    | Address        |
| ----------- | -------------- |
| `SKIM`      | _at launch_    |
| `SkimVault` | _at launch_    |
| `SkimFeeHook` | _at launch_  |

## Build & test (once source lands)

```bash
forge install
forge build
forge test -vvv
```

## Design principles

- **Non-upgradeable core.** No admin function can pause withdrawals or move deposited stakes.
- **Fee in ETH, not in token.** Rewards are a hard asset; `$SKIM` carries no transfer tax.
- **Everything on the explorer.** The split and every distribution are readable on chain.
