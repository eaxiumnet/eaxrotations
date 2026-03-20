# Phase 05 API Gate Checklist

| Check | Description | Blocking |
| --- | --- | --- |
| Allowlist generation | `tools/api_surface_extract.lua` must regenerate `tools/api_allowlist.lua` from local `.api` sources before sign-off. | Yes |
| Runtime API scan | `tools/api_hard_gate.lua` must pass with zero banned runtime violations in runtime behavior code. | Yes |
| Unified rotation validation | `tools/rotation_validation.lua` must report spec validation plus API hard gate status in one blocking command. | Yes |
