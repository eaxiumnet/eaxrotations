# EaxRotations Provenance Policy

EaxRotations is maintained as original Project Sylvanas work.

Allowed sources:

- Project Sylvanas API stubs and docs in `api/` and `apidocs/`
- TBC Classic game mechanics, spell IDs, talent behavior, and combat logs
- Public guide-level rotation priorities, expressed in new code
- Local runtime testing, bug reports, and original EaxRotations tests

Not allowed:

- Copying source code, comments, schema wording, or implementation structure from other projects
- Mechanical translation of another project's modules into Sylvanas code
- Keeping copied code with only renamed variables, changed whitespace, or attribution

External projects may be used only as behavioral comparison references. If a
feature is useful, write a short behavior note, close the source, and implement
the feature from Sylvanas APIs and TBC mechanics in EaxRotations' own structure.

Before release, run the external-similarity checker against any comparison
checkout and resolve exact long-block matches unless they are unavoidable public
constants.
