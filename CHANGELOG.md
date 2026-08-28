# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `SkimVault` staking vault: stake `$SKIM`, accrue ETH via an O(1)
  `accRewardPerShare` accumulator, claim and unstake at any time.
- On-chain 85% / 15% fee split (stakers / treasury), enforced by the contract.
- `ISkimVault` interface and full Foundry test suite (unit + fuzz).

### Pending
- `SkimFeeHook` — the Uniswap v4 hook that charges the 3% ETH fee and forwards it
  to the vault.
- `$SKIM` token deployment and verified addresses.

## [0.1.0] - 2026-08-29

### Added
- Protocol model, whitepaper, and documentation.
- Marketing site (`skimflow.site`) and brand assets.
- Repository scaffolding: license, contribution and security policies.

[Unreleased]: https://github.com/SkimFlowsite/skimflow/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/SkimFlowsite/skimflow/releases/tag/v0.1.0
