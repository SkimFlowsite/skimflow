# Contributing to Skimflow

Thanks for your interest in Skimflow. This document explains how to build the
project and how to propose changes.

## Repository layout

| Path         | What's inside                                   |
| ------------ | ----------------------------------------------- |
| `contracts/` | Solidity (Foundry) — vault, fee hook, token     |
| `web/`       | Static marketing site (`skimflow.site`)         |
| `docs/`      | Whitepaper and protocol documentation           |

## Building the contracts

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```bash
git clone --recurse-submodules https://github.com/SkimFlowsite/skimflow
cd skimflow/contracts
forge build
forge test -vvv
```

If you cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Coding standards

- Solidity `0.8.26`, formatted with `forge fmt`.
- Every non-trivial function carries a NatSpec comment.
- New contract behaviour must ship with tests. Keep the suite green (`forge test`).
- Favour clarity and minimal trust assumptions over cleverness. The core is meant to
  be non-upgradeable, so correctness at deploy time matters more than flexibility.

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused; one logical change per PR.
3. Run `forge fmt` and `forge test` before pushing.
4. Describe *what* changed and *why* in the PR body.

## Reporting bugs

Use the issue templates. For **security-sensitive** bugs, do not open a public
issue — follow [`SECURITY.md`](SECURITY.md) instead.
