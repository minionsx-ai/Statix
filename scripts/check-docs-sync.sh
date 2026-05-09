#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

arg_default() {
  local name="$1"
  local line

  line="$(grep -E "^ARG ${name}=" Dockerfile || true)"
  if [[ -z "$line" ]]; then
    printf 'Dockerfile is missing ARG %s\n' "$name" >&2
    exit 1
  fi

  printf '%s\n' "${line#ARG ${name}=}"
}

require_readme_arg() {
  local name="$1"
  local value="$2"
  local expected="| \`${name}\` | \`${value}\` |"

  if ! grep -Fq "$expected" README.md; then
    printf 'README.md build-argument table is missing: %s\n' "$expected" >&2
    exit 1
  fi
}

require_support_matrix_value() {
  local value="$1"
  local current_row="$2"

  if [[ "$current_row" != *"\`${value}\`"* ]]; then
    printf 'docs/SUPPORT_MATRIX.md current preset is missing Dockerfile default: %s\n' "$value" >&2
    exit 1
  fi
}

readme_args=(
  DEBIAN_VERSION
  TARGET
  RUST_TARGET
  RUST_VERSION
  BINUTILS_VERSION
  GCC_VERSION
  MUSL_CROSS_MAKE_REF
  MUSL_VERSION
  ZLIB_VERSION
  LIBFFI_VERSION
  NCURSES_VERSION
  OPENSSL_VERSION
  CURL_VERSION
  POSTGRESQL_VERSION
  CMAKE_REF
  LLVM_REF
  UPX_VERSION
)

for name in "${readme_args[@]}"; do
  require_readme_arg "$name" "$(arg_default "$name")"
done

current_row="$(grep -E '^\| `current` ' docs/SUPPORT_MATRIX.md || true)"
if [[ -z "$current_row" ]]; then
  printf 'docs/SUPPORT_MATRIX.md is missing the current preset row\n' >&2
  exit 1
fi

require_support_matrix_value "$(arg_default RUST_VERSION)" "$current_row"
require_support_matrix_value "$(arg_default MUSL_VERSION)" "$current_row"
require_support_matrix_value "$(arg_default MUSL_CROSS_MAKE_REF)" "$current_row"

printf 'Dockerfile defaults are documented in README.md and docs/SUPPORT_MATRIX.md.\n'
