# EAX Documentation — Agent Context

**Purpose**: Documentation standards and reference materials for the EAX TBC rotation project

## WHERE TO LOOK

| Document | Purpose |
|----------|---------|
| `integration_guide.md` | Middleware/dashboard integration patterns |
| `shared_libraries_analysis.md` | Library architecture and usage patterns |
| `shared_library_drift_audit.md` | Cross-spec consistency checks |
| `compliance_matrix.csv/md` | API compliance tracking |
| `cross_spec_patterns.md` | Common patterns across specs |
| `eax_flux_review_report.md` | Flux integration analysis |
| `flux_reference_patterns.md` | Flux pattern reference |

## CONVENTIONS

**Documentation Standards**:
- Markdown format for all docs
- CSV for matrix data (compliance tracking)
- Keep in sync with code changes
- Update when APIs or patterns change

## RELATED LOCATIONS

| For | See |
|-----|-----|
| Root project context | `../AGENTS.md` |
| Build tools | `../tools/` (if exists) |
| Flux monorepo | `../flux/AGENTS.md` |
| Spec implementations | `../EAX<Class><Spec>/` |

## NOTES

- Documentation is manually curated — verify freshness before relying
- Compliance matrices should be updated after API changes
- Pattern docs are reference-only; authoritative source is code
