"""
cleanup_ai_slop.py — Strip all remaining AI boilerplate patterns from EaxRotations .lua files.

Patterns removed:
1. "Readability notes:" blocks (with What/When/Why/Safety sub-sections)
2. "Decision notes:" blocks (next lines until blank/end)
3. "Usage (production):" and "Usage (test — dofile pattern):" comment blocks
4. "@codebuff" markers
5. "Enhanced 202" date-stamped lines
6. "Production " references in comments
7. Clean up duplicate blank lines left behind
"""

import os
import re
import sys

ROOT = "EaxRotations"
SKIP_DIRS = {"_backup", ".git", "__pycache__"}

# === Patterns to strip (entire line) ===

READABILITY_HEADER = re.compile(r"^--\s*Readability notes:\s*$")
DECISION_HEADER = re.compile(r"^--\s*Decision notes:\s*$")
USAGE_PRODUCTION = re.compile(r"^--\s*Usage \(production\):", re.IGNORECASE)
USAGE_TEST = re.compile(r"^--\s*Usage \(test", re.IGNORECASE)
ENHANCED_DATE = re.compile(r"^--\s*Enhanced\s+20\d{2}", re.IGNORECASE)
CODEBUFF_MARKER = re.compile(r"@codebuff")
PRODUCTION_COMMENT = re.compile(r"^--.*[Pp]roduction")

def is_ai_sub_line(line):
    """Check if line is a sub-field under Readability/Decision notes."""
    stripped = line.lstrip()
    return stripped.startswith("--   ") and not stripped.startswith("-- ==")

def has_text_after_prefix(line):
    """Check if a '-- Readability notes:' line has text after it."""
    m = re.match(r"^--\s*Readability notes:\s*(.*)", line)
    if m and m.group(1).strip():
        return True
    return False

def strip_file(filepath):
    """Process a single .lua file, stripping AI slop patterns."""
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    original_len = len(lines)
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.rstrip("\n").rstrip("\r").rstrip()
        raw_line = line.rstrip("\n").rstrip("\r")

        # --- Strip Readability notes header + sub-lines ---
        if READABILITY_HEADER.match(raw_line):
            # Skip this line and all following sub-lines
            i += 1
            while i < len(lines):
                next_line = lines[i].rstrip("\n").rstrip("\r").rstrip()
                # Also handle inline: "-- Readability notes: some text"
                if not next_line.strip() or next_line.strip() == "--":
                    # blank/empty comment line — skip it too
                    i += 1
                elif is_ai_sub_line(next_line) or next_line.strip().startswith("-- Readability notes:"):
                    i += 1
                else:
                    break
            continue

        # --- Inline Readability notes with text ---
        if re.match(r"^--\s*Readability notes:\s", raw_line):
            i += 1
            while i < len(lines):
                next_line = lines[i].rstrip("\n").rstrip("\r").rstrip()
                if not next_line.strip() or next_line.strip() == "--":
                    i += 1
                elif is_ai_sub_line(next_line):
                    i += 1
                else:
                    break
            continue

        # --- Strip Decision notes header + sub-lines ---
        if DECISION_HEADER.match(raw_line):
            i += 1
            while i < len(lines):
                next_line = lines[i].rstrip("\n").rstrip("\r").rstrip()
                if not next_line.strip() or next_line.strip() == "--":
                    i += 1
                elif is_ai_sub_line(next_line):
                    i += 1
                else:
                    break
            continue

        # --- Strip "Usage (production):" and "Usage (test" blocks ---
        if USAGE_PRODUCTION.match(raw_line) or USAGE_TEST.match(raw_line):
            i += 1
            while i < len(lines):
                next_line = lines[i].rstrip("\n").rstrip("\r").rstrip()
                if not next_line.strip() or next_line.strip() == "--":
                    i += 1
                elif next_line.strip().startswith("--"):
                    i += 1
                else:
                    break
            continue

        # --- Strip "Enhanced 202" lines ---
        if ENHANCED_DATE.match(raw_line):
            i += 1
            continue

        # --- Strip "@codebuff" markers from lines ---
        if CODEBUFF_MARKER.search(raw_line):
            i += 1
            continue

        # --- Strip "Production " comment lines ---
        # Only strip if it's a standalone comment line about "Production", not inline
        if PRODUCTION_COMMENT.match(raw_line) and "Readability" not in raw_line and "Decision" not in raw_line:
            # Check if it's a standalone comment like "-- Production mode:"
            # But keep it if it's actually useful like "-- Production --" separators
            i += 1
            continue

        new_lines.append(lines[i])
        i += 1

    # === Clean up duplicate blank lines ===
    cleaned = []
    prev_blank = False
    for line in new_lines:
        is_blank = line.strip() == ""
        if is_blank and prev_blank:
            continue  # skip consecutive blank lines
        cleaned.append(line)
        prev_blank = is_blank

    # === Clean up leading blank lines ===
    while cleaned and cleaned[0].strip() == "":
        cleaned.pop(0)

    # === Write back ===
    new_content = "".join(cleaned)
    if new_content != "".join(lines):
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)
        return True, len(lines) - len(cleaned)
    return False, 0


def main():
    total_cleaned = 0
    total_removed = 0
    total_errors = 0
    error_files = []

    for root, dirs, files in os.walk(ROOT):
        # Skip backup dirs
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        if any(skip in root for skip in SKIP_DIRS):
            continue

        for fname in files:
            if not fname.endswith(".lua"):
                continue
            fpath = os.path.join(root, fname)
            try:
                changed, removed = strip_file(fpath)
                if changed:
                    total_cleaned += 1
                    total_removed += removed
                    print(f"  CLEANED: {fpath} (-{removed} lines)")
            except Exception as e:
                total_errors += 1
                error_files.append(fpath)
                print(f"  ERROR: {fpath}: {e}")

    print(f"\nDone: {total_cleaned} files cleaned, {total_removed} total lines removed, {total_errors} errors")
    if error_files:
        print(f"Errors on: {', '.join(error_files)}")


if __name__ == "__main__":
    main()
