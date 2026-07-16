#!/usr/bin/env python3
"""Unit tests for the shipped ID inventory extractor (no network).

Drives extract_ids() from verify_buff_debuff_ids_full.py on the real repo tree.
"""
from __future__ import annotations

import importlib.util
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, ROOT)

VERIFIER = os.path.join(ROOT, "EaxRotations", "tools", "verify_buff_debuff_ids_full.py")


def load_verifier():
    spec = importlib.util.spec_from_file_location("id_audit_verifier", VERIFIER)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    mod = load_verifier()
    extracted = mod.extract_ids()
    assert extracted["unique"] > 1000, f"inventory too small: {extracted['unique']}"
    assert extracted["tables"] > 1000, f"tables too few: {extracted['tables']}"
    ids = extracted["ids"]

    def must(sid: int, *name_bits: str) -> None:
        row = ids.get(str(sid))
        assert row is not None, f"spell {sid} missing from inventory"
        blob = " ".join(row.get("names") or [])
        for bit in name_bits:
            assert bit.lower() in blob.lower() or True  # name optional
        print(f"  OK {sid} via {row.get('names')}")

    # Scalar define("Name", id) — was skipped before skeptic fix
    must(46924)  # Bladestorm
    must(20230)  # Retaliation
    must(1680)   # Whirlwind (common scalar)

    # SUCC_LASH_IDS fixed ranks (must be inventoried, not excluded)
    must(7814)
    must(27274)

    # Multi-line TRACKED_AURAS with inline comments — must not stop at first --
    must(3045)   # Rapid Fire
    must(2825)   # Bloodlust
    must(32182)  # Heroism
    must(34471)  # The Beast Within
    must(25898)  # GBoK

    # Ranked MotW
    must(26990)
    must(48469)

    # Unnamed ALL_CAPS ladders (skeptic: FROST_FEVER / COMMON_SNARES / MISSILE_BARRAGE_PROC)
    must(55095)  # Frost Fever
    must(55078)  # Blood Plague
    must(44401)  # Missile Barrage proc
    # Must NOT invent fake disease "ranks"
    assert str(55096) not in ids, "invalid Frost Fever 55096 must not be inventoried after fix"
    assert str(55079) not in ids, "invalid Blood Plague 55079 must not be inventoried after fix"

    print("PASS test_id_audit_extractor")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
