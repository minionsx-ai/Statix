#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
script_path="${script_dir}/$(basename -- "${BASH_SOURCE[0]}")"

log() {
  printf '[statix-snarkos] %s\n' "$*"
}

die() {
  printf '[statix-snarkos] error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Build ProvableHQ/snarkOS with Statix and produce static-binary evidence.

Usage:
  examples/build-snarkos.sh [--dry-run]

Environment:
  STATIX_IMAGE              Docker image to use. Default: statix:latest
  STATIX_SNARKOS_WORKDIR    Host work directory. Default: .work/snarkos-v4.6.3
  SNARKOS_REF                  snarkOS tag, branch, or commit. Default: v4.6.3
  SNARKVM_REF                  snarkVM tag, branch, or commit. Default: v4.6.3
  RUST_TARGET                  Cargo target triple. Default: x86_64-unknown-linux-musl
  CARGO_PROFILE                Cargo profile. Default: release
  CARGO_FEATURES               Optional cargo feature list.
  CARGO_EXTRA_ARGS             Optional extra cargo arguments, split by shell words.
  CARGO_LOCKED                 Set to 1 to pass --locked after refreshing Cargo.lock.
  REFRESH_LOCKFILE             Set to 0 to skip cargo update. Default: 1
  PRESERVE_TARGET_CACHE        Keep existing target directories during source refresh. Default: 1
  SNARKOS_BIN                  Binary name to verify. Default: snarkos
  SNARKOS_PACKAGE              Cargo package used for dependency preflight. Default: snarkos
  SNARKOS_RUST_TOOLCHAIN       Rust toolchain used for snarkOS. Default: 1.88.0-x86_64-unknown-linux-musl
  ROCKSDB_VERSION              rocksdb crate version for musl patch. Default: 0.23.0
  STATIX_RUSTFLAGS          Target-specific Rust flags. Default: -C relocation-model=pie -C link-arg=-static-pie
  STATIX_CARGO_TARGET_DIR   Container target directory. Default: /workspace/target
  COMPRESS_WITH_UPX            Compress the final binary with UPX. Default: 1

The script is intended to run from the host. It starts the Statix container,
then clones and builds snarkOS inside the mounted work directory.
USAGE
}

dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

statix_image="${STATIX_IMAGE:-statix:latest}"
work_dir="${STATIX_SNARKOS_WORKDIR:-${repo_root}/.work/snarkos-v4.6.3}"
snarkos_repo="${SNARKOS_REPO:-https://github.com/ProvableHQ/snarkOS.git}"
snarkvm_repo="${SNARKVM_REPO:-https://github.com/ProvableHQ/snarkVM.git}"
snarkos_ref="${SNARKOS_REF:-v4.6.3}"
snarkvm_ref="${SNARKVM_REF:-v4.6.3}"
rust_target="${RUST_TARGET:-x86_64-unknown-linux-musl}"
cargo_profile="${CARGO_PROFILE:-release}"
cargo_features="${CARGO_FEATURES:-}"
cargo_extra_args="${CARGO_EXTRA_ARGS:-}"
cargo_locked="${CARGO_LOCKED:-0}"
refresh_lockfile="${REFRESH_LOCKFILE:-1}"
preserve_target_cache="${PRESERVE_TARGET_CACHE:-1}"
snarkos_bin="${SNARKOS_BIN:-snarkos}"
snarkos_package="${SNARKOS_PACKAGE:-snarkos}"
snarkos_rust_toolchain="${SNARKOS_RUST_TOOLCHAIN:-1.88.0-x86_64-unknown-linux-musl}"
rocksdb_version="${ROCKSDB_VERSION:-0.23.0}"
rustflags="${STATIX_RUSTFLAGS:-${RUSTFLAGS:--C relocation-model=pie -C link-arg=-static-pie}}"
cargo_target_dir="${STATIX_CARGO_TARGET_DIR:-/workspace/target}"
compress_with_upx="${COMPRESS_WITH_UPX:-1}"
case "${compress_with_upx}" in
  0|1) ;;
  *) die "COMPRESS_WITH_UPX must be 0 or 1" ;;
esac
if [[ "${STATIX_IN_CONTAINER:-0}" == "1" && -z "${STATIX_SNARKOS_WORKDIR:-}" ]]; then
  work_dir="/workspace"
fi

print_config() {
  cat <<EOF
Statix snarkOS validation configuration:
  image: ${statix_image}
  work dir: ${work_dir}
  snarkOS ref: ${snarkos_ref}
  snarkVM ref: ${snarkvm_ref}
  target: ${rust_target}
  cargo profile: ${cargo_profile}
  cargo features: ${cargo_features:-<default>}
  cargo extra args: ${cargo_extra_args:-<none>}
  rustflags: ${rustflags:-<none>}
  refresh lockfile: ${refresh_lockfile}
  preserve target cache: ${preserve_target_cache}
  locked build: ${cargo_locked}
  binary: ${snarkos_bin}
  package: ${snarkos_package}
  rust toolchain: ${snarkos_rust_toolchain}
  compress with UPX: ${compress_with_upx}
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

source_cargo_env() {
  if [[ -f "${HOME}/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    . "${HOME}/.cargo/env"
  fi
}

target_rustflags_env_name() {
  local normalized="${rust_target^^}"
  normalized="${normalized//-/_}"
  printf 'CARGO_TARGET_%s_RUSTFLAGS\n' "${normalized}"
}

file_size() {
  if stat -c '%s' "$1" >/dev/null 2>&1; then
    stat -c '%s' "$1"
  else
    stat -f '%z' "$1"
  fi
}

statix_repo_commit() {
  if [[ -n "${STATIX_REPO_COMMIT:-}" ]]; then
    printf '%s\n' "${STATIX_REPO_COMMIT}"
    return
  fi

  if git -C "${repo_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "${repo_root}" rev-parse --short=12 HEAD
  else
    printf 'unknown\n'
  fi
}

ensure_musl_loader() {
  case "${snarkos_rust_toolchain}" in
    *-linux-musl) ;;
    *) return ;;
  esac

  local loader
  local libc
  local sysroot

  case "${rust_target}" in
    x86_64-unknown-linux-musl)
      loader="/lib/ld-musl-x86_64.so.1"
      ;;
    *)
      die "no musl loader path is configured for target ${rust_target}"
      ;;
  esac

  sysroot="${SYSROOT:-/opt/musl/${TARGET:-x86_64-linux-musl}}"
  libc="${sysroot}/lib/libc.so"
  [[ -e "${libc}" ]] || die "musl libc was not found at ${libc}"

  if [[ -L "${loader}" && ! -e "${loader}" ]]; then
    rm -f "${loader}"
  fi

  if [[ ! -e "${loader}" ]]; then
    log "linking musl loader ${loader} -> ${libc}"
    mkdir -p "$(dirname -- "${loader}")"
    ln -s "${libc}" "${loader}"
  else
    log "musl loader is available at ${loader}"
  fi
}

configure_rust_toolchain() {
  log "configuring Rust toolchain ${snarkos_rust_toolchain}"
  ensure_musl_loader
  rustup override unset >/dev/null 2>&1 || true
  rustup toolchain install "${snarkos_rust_toolchain}" --profile minimal --force-non-host
  rustup default "${snarkos_rust_toolchain}" --force-non-host
  rustup override set "${snarkos_rust_toolchain}"
  rustup target add "${rust_target}"

  log "active Rust toolchain:"
  rustc -vV | sed 's/^/[statix-snarkos]   /'
}

run_on_host() {
  print_config

  if [[ "${dry_run}" == "1" ]]; then
    log "dry run only; not starting Docker"
    return
  fi

  require_command docker
  docker image inspect "${statix_image}" >/dev/null 2>&1 || die "Docker image '${statix_image}' was not found. Build it first with: docker build -t ${statix_image} ."
  mkdir -p "${work_dir}"

  local image_id
  image_id="$(docker image inspect --format '{{.Id}}' "${statix_image}")"

  local repo_commit
  repo_commit="$(statix_repo_commit)"

  docker run --rm \
    -e STATIX_IN_CONTAINER=1 \
    -e STATIX_IMAGE="${statix_image}" \
    -e STATIX_IMAGE_ID="${image_id}" \
    -e STATIX_REPO_COMMIT="${repo_commit}" \
    -e SNARKOS_REPO="${snarkos_repo}" \
    -e SNARKVM_REPO="${snarkvm_repo}" \
    -e SNARKOS_REF="${snarkos_ref}" \
    -e SNARKVM_REF="${snarkvm_ref}" \
    -e RUST_TARGET="${rust_target}" \
    -e CARGO_PROFILE="${cargo_profile}" \
    -e CARGO_FEATURES="${cargo_features}" \
    -e CARGO_EXTRA_ARGS="${cargo_extra_args}" \
    -e CARGO_LOCKED="${cargo_locked}" \
    -e REFRESH_LOCKFILE="${refresh_lockfile}" \
    -e PRESERVE_TARGET_CACHE="${preserve_target_cache}" \
    -e SNARKOS_BIN="${snarkos_bin}" \
    -e SNARKOS_PACKAGE="${snarkos_package}" \
    -e SNARKOS_RUST_TOOLCHAIN="${snarkos_rust_toolchain}" \
    -e ROCKSDB_VERSION="${rocksdb_version}" \
    -e STATIX_RUSTFLAGS="${rustflags}" \
    -e STATIX_CARGO_TARGET_DIR="${cargo_target_dir}" \
    -e COMPRESS_WITH_UPX="${compress_with_upx}" \
    -v "${work_dir}:/workspace" \
    -v "${script_path}:/usr/local/bin/build-snarkos:ro" \
    -w /workspace \
    "${statix_image}" \
    /usr/local/bin/build-snarkos
}

checkout_repo() {
  local name="$1"
  local url="$2"
  local ref="$3"

  if [[ -d "${name}/.git" ]]; then
    log "refreshing ${name} at ${ref}"
    git -C "${name}" remote set-url origin "${url}"
    git -C "${name}" fetch --tags --force --depth 1 origin "${ref}"
    git -C "${name}" checkout --force FETCH_HEAD
    if [[ "${preserve_target_cache}" == "1" ]]; then
      git -C "${name}" clean -fdx -e target/
    else
      git -C "${name}" clean -fdx
    fi
  else
    log "cloning ${name} at ${ref}"
    rm -rf "${name}"
    git init "${name}"
    git -C "${name}" remote add origin "${url}"
    git -C "${name}" fetch --tags --force --depth 1 origin "${ref}"
    git -C "${name}" checkout --force FETCH_HEAD
  fi
}

apply_snarkos_musl_patch() {
  log "applying snarkOS musl compatibility patch"
  python3 - <<'PY'
import os
import re
from pathlib import Path


def replace_once(path, old, new):
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{path}: expected text not found")
    path.write_text(text.replace(old, new, 1))


def replace_table(path, table, new):
    text = path.read_text()
    pattern = re.compile(rf"(?ms)^\[{re.escape(table)}\]\n.*?(?=^\[|\Z)")
    if not pattern.search(text):
        raise SystemExit(f"{path}: table [{table}] not found")
    path.write_text(pattern.sub(new, text, count=1))


def replace_all(path, old, new):
    text = path.read_text()
    if old in text:
        path.write_text(text.replace(old, new))
        return
    if new in text:
        return
    raise SystemExit(f"{path}: expected text not found")


def ensure_crates_io_patches(snarkos_manifest, snarkvm_manifest):
    snarkvm_text = snarkvm_manifest.read_text()
    entries = {"snarkvm": "../snarkVM"}

    dependency_tables = re.finditer(
        r"(?ms)^\[workspace\.dependencies\.([^\]]+)\]\n(.*?)(?=^\[|\Z)",
        snarkvm_text,
    )
    for match in dependency_tables:
        name, body = match.group(1), match.group(2)
        path_match = re.search(r'(?m)^path\s*=\s*"([^"]+)"', body)
        if name.startswith("snarkvm") and path_match:
            entries[name] = f"../snarkVM/{path_match.group(1)}"

    if "snarkvm-ledger-store" not in entries:
        raise SystemExit("snarkVM workspace manifest did not expose snarkvm-ledger-store as a path dependency")

    patch_lines = ["[patch.crates-io]"]
    for name in sorted(entries):
        patch_lines.append(f'{name} = {{ path = "{entries[name]}" }}')
    patch_block = "\n".join(patch_lines) + "\n"

    text = snarkos_manifest.read_text()
    text = re.sub(r"(?ms)^\[patch\.crates-io\]\n.*?(?=^\[|\Z)", "", text)
    snarkos_manifest.write_text(text.rstrip() + "\n\n" + patch_block)


snarkvm_store = Path("snarkVM/ledger/store/Cargo.toml")
snarkvm_manifest = Path("snarkVM/Cargo.toml")
rocksdb_version = os.environ.get("ROCKSDB_VERSION", "0.23.0")
replace_table(
    snarkvm_store,
    "dependencies.rocksdb",
    f"""[dependencies.rocksdb]
version = "{rocksdb_version}"
default-features = false
features = [ "bindgen-static", "lz4" ]
optional = true
""",
)

snarkos_manifest = Path("snarkOS/Cargo.toml")
replace_once(
    snarkos_manifest,
    '#path = "../snarkVM"',
    'path = "../snarkVM"',
)
replace_once(
    snarkos_manifest,
    """[target.'cfg(all(target_os = "linux", target_arch = "x86_64"))'.dependencies]
tikv-jemallocator = "0.6"
""",
    """[target.'cfg(all(target_os = "linux", target_arch = "x86_64", target_env = "gnu"))'.dependencies]
tikv-jemallocator = "0.6"
""",
)
ensure_crates_io_patches(snarkos_manifest, snarkvm_manifest)

snarkos_main = Path("snarkOS/snarkos/main.rs")
replace_all(
    snarkos_main,
    '#[cfg(all(target_os = "linux", target_arch = "x86_64"))]',
    '#[cfg(all(target_os = "linux", target_arch = "x86_64", target_env = "gnu"))]',
)
PY
}

verify_snarkos_musl_patch() {
  local cargo_toml="/workspace/snarkOS/Cargo.toml"
  local main_rs="/workspace/snarkOS/snarkos/main.rs"
  local snarkvm_store="/workspace/snarkVM/ledger/store/Cargo.toml"

  log "verifying snarkOS musl compatibility patch"

  grep -Fq 'path = "../snarkVM"' "${cargo_toml}" || die "snarkOS Cargo.toml is not using the local ../snarkVM path"
  grep -Fq 'snarkvm-ledger-store = { path = "../snarkVM/ledger/store" }' "${cargo_toml}" || die "snarkOS Cargo.toml is missing the snarkVM crates.io patch table"
  grep -Fq "target_env = \"gnu\"" "${cargo_toml}" || die "snarkOS Cargo.toml still exposes jemalloc to musl"
  grep -Fq "target_env = \"gnu\"" "${main_rs}" || die "snarkOS main.rs still exposes jemalloc global allocator to musl"
  grep -Fq "version = \"${rocksdb_version}\"" "${snarkvm_store}" || die "snarkVM ledger store still requires the old rocksdb version"
  grep -Fq '"bindgen-static"' "${snarkvm_store}" || die "snarkVM ledger store is missing the rocksdb bindgen-static feature"

  if grep -Fq '#[cfg(all(target_os = "linux", target_arch = "x86_64"))]' "${main_rs}"; then
    die "snarkOS main.rs still contains the generic Linux x86_64 jemalloc cfg"
  fi

  log "patch summary:"
  grep -n "path = \"../snarkVM\"\\|tikv-jemallocator\\|target_env = \"gnu\"\\|Jemalloc" "${cargo_toml}" "${main_rs}" || true
  grep -n "snarkvm = \\|snarkvm-ledger-store" "${cargo_toml}" || true
  grep -n "rocksdb\\|bindgen-static\\|lz4" "${snarkvm_store}" || true
}

verify_rocksdb_resolution() {
  local metadata="/tmp/snarkos-cargo-metadata.json"

  log "checking cargo resolution for rocksdb ${rocksdb_version}"
  cargo metadata --format-version 1 --locked >"${metadata}"

  python3 - "${metadata}" "${rocksdb_version}" <<'PY'
import json
import sys

metadata_path, expected_rocksdb = sys.argv[1], sys.argv[2]
metadata = json.load(open(metadata_path))

packages = metadata["packages"]
nodes = {node["id"]: node for node in metadata["resolve"]["nodes"]}


def matching_packages(name):
    return [package for package in packages if package["name"] == name]


rocksdb = matching_packages("rocksdb")
if not any(package["version"] == expected_rocksdb for package in rocksdb):
    versions = ", ".join(sorted({package["version"] for package in rocksdb})) or "<missing>"
    raise SystemExit(f"expected rocksdb {expected_rocksdb}, resolved: {versions}")

snarkvm_ledger_store = matching_packages("snarkvm-ledger-store")
if not snarkvm_ledger_store:
    raise SystemExit("snarkvm-ledger-store was not resolved")
if not any("/workspace/snarkVM/ledger/store/Cargo.toml" in package["manifest_path"] for package in snarkvm_ledger_store):
    paths = ", ".join(sorted(package["manifest_path"] for package in snarkvm_ledger_store))
    raise SystemExit(f"snarkvm-ledger-store is not resolved from local ../snarkVM: {paths}")

old_librocksdb = [
    package["version"]
    for package in matching_packages("librocksdb-sys")
    if package["version"].startswith("0.11.")
]
if old_librocksdb:
    raise SystemExit(f"resolved old librocksdb-sys versions: {', '.join(old_librocksdb)}")

librocksdb = matching_packages("librocksdb-sys")
if not librocksdb:
    raise SystemExit("librocksdb-sys was not resolved")

for package in librocksdb:
    node = nodes.get(package["id"])
    features = set(node.get("features", [])) if node else set()
    missing = {"bindgen-static", "static", "lz4"} - features
    if missing:
        raise SystemExit(
            f"{package['name']} {package['version']} is missing features: {', '.join(sorted(missing))}; "
            f"resolved features: {', '.join(sorted(features)) or '<none>'}"
        )
    if "bindgen-runtime" in features:
        raise SystemExit(f"{package['name']} {package['version']} still has bindgen-runtime enabled")

print("[statix-snarkos] resolved rocksdb packages:")
for package in sorted(rocksdb + librocksdb, key=lambda item: item["name"]):
    node = nodes.get(package["id"])
    features = ", ".join(sorted(node.get("features", []))) if node else "<unknown>"
    print(f"[statix-snarkos]   {package['name']} {package['version']} features=[{features}]")
PY
}

build_snarkos() {
  print_config

  if [[ "${dry_run}" == "1" ]]; then
    log "dry run only; not cloning or building"
    return
  fi

  source_cargo_env
  require_command git
  require_command python3
  require_command cargo
  require_command file
  require_command rustup
  if [[ "${compress_with_upx}" == "1" ]]; then
    require_command upx
  fi

  cd /workspace
  checkout_repo snarkVM "${snarkvm_repo}" "${snarkvm_ref}"
  checkout_repo snarkOS "${snarkos_repo}" "${snarkos_ref}"
  apply_snarkos_musl_patch
  verify_snarkos_musl_patch

  cd /workspace/snarkOS
  configure_rust_toolchain

  export CARGO_TARGET_DIR="${cargo_target_dir}"
  export LIBCLANG_STATIC_PATH="${LIBCLANG_STATIC_PATH:-/opt/musl/llvm-build/lib}"
  local target_rustflags_env
  target_rustflags_env="$(target_rustflags_env_name)"
  export "${target_rustflags_env}=${rustflags}"
  unset RUSTFLAGS

  if [[ "${refresh_lockfile}" == "1" ]]; then
    log "refreshing Cargo.lock from patched manifests"
    cargo generate-lockfile
  fi

  verify_rocksdb_resolution

  log "checking musl dependency graph for jemalloc"
  if ! cargo tree --target "${rust_target}" --package "${snarkos_package}" --edges normal --prefix none >/tmp/snarkos-musl-cargo-tree.txt 2>&1; then
    cat /tmp/snarkos-musl-cargo-tree.txt >&2
    die "cargo tree check failed before build"
  fi
  if grep -Eq '^tikv-jemallocator v|^tikv-jemalloc-sys v' /tmp/snarkos-musl-cargo-tree.txt; then
    grep -E '^tikv-jemallocator v|^tikv-jemalloc-sys v' /tmp/snarkos-musl-cargo-tree.txt >&2
    die "tikv-jemallocator is still active for ${rust_target}; the musl patch did not apply cleanly"
  fi

  local cargo_args=(build --target "${rust_target}" --bin "${snarkos_bin}")
  case "${cargo_profile}" in
    release)
      cargo_args+=(--release)
      ;;
    dev|debug)
      ;;
    *)
      cargo_args+=(--profile "${cargo_profile}")
      ;;
  esac

  if [[ -n "${cargo_features}" ]]; then
    cargo_args+=(--features "${cargo_features}")
  fi

  if [[ "${cargo_locked}" == "1" ]]; then
    cargo_args+=(--locked)
  fi

  if [[ -n "${cargo_extra_args}" ]]; then
    # shellcheck disable=SC2206
    local split_extra_args=(${cargo_extra_args})
    cargo_args+=("${split_extra_args[@]}")
  fi

  log "running: cargo ${cargo_args[*]}"
  cargo "${cargo_args[@]}"

  local profile_dir
  case "${cargo_profile}" in
    release) profile_dir=release ;;
    dev|debug) profile_dir=debug ;;
    *) profile_dir="${cargo_profile}" ;;
  esac

  local binary="${cargo_target_dir}/${rust_target}/${profile_dir}/${snarkos_bin}"
  [[ -x "${binary}" ]] || die "expected binary was not produced: ${binary}"

  local size_before_upx
  local size_after_upx
  local file_before_upx
  local file_after_upx
  size_before_upx="$(file_size "${binary}")"
  file_before_upx="$(file "${binary}")"

  if [[ "${file_before_upx}" != *"pie executable"* && "${file_before_upx}" != *"static-pie linked"* ]]; then
    printf '%s\n' "${file_before_upx}" >&2
    die "binary was built but file(1) did not report a static PIE executable before UPX compression"
  fi

  if [[ "${compress_with_upx}" == "1" ]]; then
    log "compressing ${snarkos_bin} with UPX"
    upx --best --lzma "${binary}"
  else
    log "skipping UPX compression"
  fi
  size_after_upx="$(file_size "${binary}")"
  file_after_upx="$(file "${binary}")"

  local report="/workspace/snarkos-validation-report.txt"
  {
    printf 'Project: ProvableHQ/snarkOS\n'
    printf 'snarkOS ref: %s\n' "${snarkos_ref}"
    printf 'snarkOS commit: %s\n' "$(git rev-parse HEAD)"
    printf 'snarkVM ref: %s\n' "${snarkvm_ref}"
    printf 'snarkVM commit: %s\n' "$(git -C /workspace/snarkVM rev-parse HEAD)"
    printf 'Statix commit: %s\n' "$(statix_repo_commit)"
    printf 'Statix image: %s\n' "${STATIX_IMAGE:-unknown}"
    printf 'Statix image id: %s\n' "${STATIX_IMAGE_ID:-unknown}"
    printf 'Rust toolchain: %s\n' "${snarkos_rust_toolchain}"
    printf 'Target triple: %s\n' "${rust_target}"
    printf '%s: %s\n' "${target_rustflags_env}" "${rustflags}"
    printf 'Build command: cargo %s\n' "${cargo_args[*]}"
    printf 'UPX compression: %s\n' "${compress_with_upx}"
    printf 'Binary size before UPX: %s bytes\n' "${size_before_upx}"
    printf 'Final binary size: %s bytes\n' "${size_after_upx}"
    printf '\n[file before UPX]\n'
    printf '%s\n' "${file_before_upx}"
    printf '\n[file final]\n'
    printf '%s\n' "${file_after_upx}"
    printf '\n[ldd]\n'
    ldd "${binary}" 2>&1 || true
  } | tee "${report}"

  log "validation report written to ${report}"
}

if [[ "${STATIX_IN_CONTAINER:-0}" == "1" ]]; then
  build_snarkos
else
  run_on_host
fi
