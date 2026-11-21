# Security Policy

## Supported scope

Security reports are welcome for the infrastructure code and workflows in this repository.

## Reporting a vulnerability

Please do not open public GitHub issues for sensitive findings.

Instead, report privately by contacting the maintainer directly and include:

- affected files/paths
- reproduction steps
- potential impact
- suggested mitigation (if known)

You can expect acknowledgement and initial triage feedback as soon as practical.

## Handling secrets and credentials

- Never commit credentials, certificates, tokens, or private keys
- Never paste real secret values into issues, PRs, or commit messages
- Use local secret stores and environment-specific secure channels

## Hardening baseline

See `AGENTS.md` for current baseline constraints and cloud hardening defaults used by xyz9.
