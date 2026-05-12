# Docs Subtree Guidance

## Purpose

`EaxRotations/docs/` contains current project-facing docs only. Historical
session notebooks, generated changelogs, old audit ledgers, and stale TODO lists
do not belong here.

## Current Docs

| File | Role |
| --- | --- |
| `README_Sylvanas_API_Edition.md` | Current overview, load path, API boundary, and test baseline |
| `api_boundary.md` | API boundary and Eax branding rules |
| `AGENTS.md` | This docs-subtree policy |

## Update Rules

- Update existing docs before adding new files.
- Keep status text current and short.
- Treat `api/` and `apidocs/` as the Project Sylvanas source of truth.
- If code and docs disagree, inspect live code and Project Sylvanas API docs,
  then update the stale doc.
- Keep public-source docs Eax-branded and free of unrelated project links.

## Avoid

- Reintroducing large audit ledgers as permanent docs.
- Recreating session TODO files.
- Adding generated changelogs.
- Referencing private or unrelated projects.
- Documenting non-Eax runtime dependencies as acceptable.
