# tools/

## Responsibility
Holds offline validation and maintenance scripts for enforcing Sylvanas API boundaries, benchmarking rotation behavior, and auditing repository consistency.

## Design
- **Policy-enforcement scripts**: `api_allowlist.lua`, `api_hard_gate.lua`, and `api_surface_extract.lua` define and inspect allowed API usage.
- **Performance harnesses**: `benchmark_matrix.lua`, `benchmark_thresholds.lua`, and `dps_benchmark.lua` encode throughput expectations.
- **Audit utilities**: `rotation_validation.lua` and `audit_shared_duplicates.py` detect rotation regressions and duplicated logic.

## Flow
1. Developers run tooling scripts outside the live combat loop.
2. Scripts inspect repo files or benchmark behavior against expected thresholds.
3. Results guide refactors, API cleanups, and regression fixes in live `EAX*/` or `eax_shared/` code.

## Integration
- Consumed by: developers maintaining the repo.
- Targets: `EAX*/`, `eax_shared/`, and API policy definitions.
- Adjacent docs: `AGENTS.md`, `README.md`.
