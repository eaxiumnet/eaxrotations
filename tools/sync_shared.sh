#!/usr/bin/env bash

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SHARED_DIR="$ROOT_DIR/eax_shared"

AUTOSYNC_HEADER_PREFIX='-- AUTOSYNC: do not edit directly, edit eax_shared/'

normalize_file() {
  local file="$1"
  awk -v prefix="$AUTOSYNC_HEADER_PREFIX" 'NR==1 && index($0, prefix) == 1 { next } { print }' "$file"
}

hash_file() {
  local file="$1"

  if command -v md5sum >/dev/null 2>&1; then
    normalize_file "$file" | md5sum | awk '{print $1}'
    return 0
  fi

  if command -v md5 >/dev/null 2>&1; then
    local tmp
    tmp=$(mktemp) || return 1
    normalize_file "$file" > "$tmp"
    md5 -q "$tmp" 2>/dev/null || md5 "$tmp" | awk '{print $NF}'
    rm -f "$tmp"
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    normalize_file "$file" | shasum -a 256 | awk '{print $1}'
    return 0
  fi

  if command -v openssl >/dev/null 2>&1; then
    normalize_file "$file" | openssl md5 | awk '{print $2}'
    return 0
  fi

  return 1
}

have_diff_u=0
if command -v diff >/dev/null 2>&1; then
  have_diff_u=1
fi

is_interactive=0
if [ -t 0 ] && [ -t 1 ]; then
  is_interactive=1
fi

drift_found=0

for shared_file in "$SHARED_DIR"/*.lua; do
  [ -f "$shared_file" ] || continue

  shared_name=$(basename "$shared_file")
  shared_hash=$(hash_file "$shared_file") || {
    printf 'Skipping %s: no supported hash tool found\n' "$shared_file" >&2
    continue
  }

  for spec_file in "$ROOT_DIR"/EAX*/"$shared_name"; do
    [ -f "$spec_file" ] || continue

    spec_hash=$(hash_file "$spec_file") || {
      printf 'Skipping %s: no supported hash tool found\n' "$spec_file" >&2
      drift_found=1
      continue
    }

    if [ "$shared_hash" = "$spec_hash" ]; then
      continue
    fi

    drift_found=1
    printf '%s\n' "$spec_file"
    if [ "$have_diff_u" -eq 1 ]; then
      diff -u "$shared_file" "$spec_file" || true
    fi

    if [ "$is_interactive" -eq 1 ]; then
      printf 'Overwrite with shared version? [y/N] '
      read -r answer || answer="n"
      case "$answer" in
        y|Y|yes|YES)
          tmp_file=$(mktemp) || exit 1
          {
            printf '%s\n' "${AUTOSYNC_HEADER_PREFIX}${shared_name} instead"
            normalize_file "$shared_file"
          } > "$tmp_file"
          mv "$tmp_file" "$spec_file"
          ;;
      esac
    fi
  done
done

if [ "$drift_found" -ne 0 ]; then
  exit 1
fi

exit 0
