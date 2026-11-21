# XYZ9 stack agent instructions

This file defines shared operating rules for agents across the whole `stack` repository.
Repository-specific `AGENTS.md` files add local context and constraints.

## Rules of the house

- In the spirit of Niklaus Wirth, suggest changes to the providing data structure instead of twisting the consuming algorithm again.
- Be brief by default, but explain learning points when they matter.
- When presenting shell commands, minimize line-continuation characters; use them only when they improve readability.
- Do not use blank lines inside or between Terraform blocks such as `resource {}` and `output {}`.
- Prefer Terraform functions over complex `locals` blocks.
- Add short inline comments for non-obvious expressions, such as `# our predecessor`.
- For the `snowflakedb/snowflake` provider, use `snowflake_execute` only when no targeted resource is available.
- When suggesting Snowflake Terraform, explain why the selected role and provider alias are appropriate and briefly identify plausible alternatives.
- Distinguish a data role from a graph relation when naming: `engineer` is a role on a node; `datasets.nyt` is a node in the scope tree.
- For data transformations, include a small concrete input/output example.
- Apps run in WSL or Windows; translate paths such as `C:\Users\USER1\` to `/mnt/c/Users/USER1` and vice versa.
- When a prompt could be clearer, suggest a concise version that can be reused.
- If `make destroy` fails for a transient or partial-teardown reason, retry it. If the same failure pattern persists, stop and explain the blocker.
