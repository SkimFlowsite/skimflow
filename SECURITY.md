# Security Policy

Skimflow holds user funds on chain. We take security seriously and welcome
responsible disclosure.

## Reporting a vulnerability

**Do not open a public issue for security bugs.**

Report privately via a direct message to [@SkimFlowsite](https://x.com/SkimFlowsite)
on X, or through GitHub's private
[security advisory](https://github.com/SkimFlowsite/skimflow/security/advisories/new)
form. Please include:

- A description of the vulnerability and its impact.
- Steps or a proof-of-concept to reproduce it.
- Any suggested remediation.

We aim to acknowledge reports within 72 hours.

## Scope

In scope:

- `contracts/` — the vault, fee hook, and token.
- Anything that could lock, steal, or misdirect staked `$SKIM` or accrued ETH.

Out of scope:

- The marketing site (`web/`) except for issues that affect on-chain safety.
- Loss of yield from low trading volume — this is expected behaviour, not a bug.

## Disclosure

Please give us a reasonable window to ship a fix before any public disclosure.
Once the contracts are deployed and verified, a formal bug-bounty program will be
announced. Contributions that harden the protocol before launch are especially valued.
