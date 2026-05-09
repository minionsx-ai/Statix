#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build and runtime-check a Statix validation target.

Usage:
  scripts/validate-target.sh [--dry-run] <target-dir> [binary-name]

Environment:
  STATIX_IMAGE          Builder image. Default: statix:latest
  STATIX_RUNTIME_IMAGE  Runtime image. Default: alpine:latest
  RUST_TARGET              Cargo target triple. Default: x86_64-unknown-linux-musl
  STATIX_RUST_TOOLCHAIN Rust toolchain used inside the builder.
                           Default: 1.95.0-x86_64-unknown-linux-musl
  STATIX_RUSTFLAGS      Target-specific Rust flags.
                           Default: -C relocation-model=pie -C link-arg=-static-pie
  PQ_LIB_STATIC            Force pq-sys to link libpq statically. Default: 1
  LIBPQ_STATIC             Force pkg-config to include libpq private static deps.
                           Default: 1
  LIBPQ_EXTRA_RUSTFLAGS    Extra flags for older libpq images. Default for
                           validation/diesel-postgres: auto-detect static
                           PostgreSQL/OpenSSL archives from the musl sysroot.
  STATIX_DISABLE_LIBPQ_FALLBACK
                           Set to 1 to disable the diesel-postgres fallback.
  CARGO_PROFILE            Cargo profile. Default: release
  CARGO_EXTRA_ARGS         Optional extra cargo build arguments, split by shell words.
  RUNTIME_ARGS             Arguments passed to the binary in Alpine. Default: --version
USAGE
}

log() {
  printf '[statix-validate] %s\n' "$*"
}

die() {
  printf '[statix-validate] error: %s\n' "$*" >&2
  exit 1
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
    --)
      shift
      break
      ;;
    -*)
      die "unknown argument: $1"
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -ge 1 ]] || die "missing target directory"

repo_root="$(git rev-parse --show-toplevel)"
target_dir="${1%/}"
binary_name="${2:-$(basename -- "${target_dir}")}"
target_path="${repo_root}/${target_dir}"

statix_image="${STATIX_IMAGE:-statix:latest}"
runtime_image="${STATIX_RUNTIME_IMAGE:-alpine:latest}"
rust_target="${RUST_TARGET:-x86_64-unknown-linux-musl}"
rust_toolchain="${STATIX_RUST_TOOLCHAIN:-1.95.0-x86_64-unknown-linux-musl}"
rustflags="${STATIX_RUSTFLAGS:-${RUSTFLAGS:--C relocation-model=pie -C link-arg=-static-pie}}"
pq_lib_static="${PQ_LIB_STATIC:-1}"
libpq_static="${LIBPQ_STATIC:-1}"
libpq_extra_rustflags="${LIBPQ_EXTRA_RUSTFLAGS:-}"
auto_libpq_openssl_archives=0
disable_libpq_fallback="${STATIX_DISABLE_LIBPQ_FALLBACK:-0}"
if [[ -z "${libpq_extra_rustflags}" && "${disable_libpq_fallback}" != "1" && "${target_dir}" == "validation/diesel-postgres" ]]; then
  auto_libpq_openssl_archives=1
fi
if [[ -n "${libpq_extra_rustflags}" ]]; then
  rustflags="${rustflags} ${libpq_extra_rustflags}"
fi
libpq_extra_display="${libpq_extra_rustflags:-<none>}"
if [[ "${auto_libpq_openssl_archives}" == "1" ]]; then
  libpq_extra_display="<auto static PostgreSQL/OpenSSL archives>"
fi
cargo_profile="${CARGO_PROFILE:-release}"
cargo_extra_args="${CARGO_EXTRA_ARGS:-}"
runtime_args="${RUNTIME_ARGS:---version}"

[[ -f "${target_path}/Cargo.toml" ]] || die "${target_dir} does not contain Cargo.toml"

profile_dir="${cargo_profile}"
case "${cargo_profile}" in
  release) profile_dir=release ;;
  dev|debug) profile_dir=debug ;;
esac

host_binary="${target_path}/target/${rust_target}/${profile_dir}/${binary_name}"

cat <<EOF
Statix validation target:
  builder image: ${statix_image}
  runtime image: ${runtime_image}
  target dir: ${target_dir}
  binary: ${binary_name}
  rust target: ${rust_target}
  rust toolchain: ${rust_toolchain}
  rustflags: ${rustflags:-<none>}
  PQ_LIB_STATIC: ${pq_lib_static:-<unset>}
  LIBPQ_STATIC: ${libpq_static:-<unset>}
  LIBPQ_EXTRA_RUSTFLAGS: ${libpq_extra_display}
  STATIX_DISABLE_LIBPQ_FALLBACK: ${disable_libpq_fallback}
  cargo profile: ${cargo_profile}
  cargo extra args: ${cargo_extra_args:-<none>}
  runtime args: ${runtime_args:-<none>}
EOF

if [[ "${dry_run}" == "1" ]]; then
  log "dry run only; not starting Docker"
  exit 0
fi

command -v docker >/dev/null 2>&1 || die "missing required command: docker"
docker image inspect "${statix_image}" >/dev/null 2>&1 || die "Docker image '${statix_image}' was not found"

container_workdir="/workspace/${target_dir}"

cmake_bin="${CMAKE:-/opt/musl/x86_64-linux-musl/bin/cmake}"

docker run --rm \
  -e RUST_TARGET="${rust_target}" \
  -e STATIX_RUST_TOOLCHAIN="${rust_toolchain}" \
  -e STATIX_RUSTFLAGS="${rustflags}" \
  -e PQ_LIB_STATIC="${pq_lib_static}" \
  -e LIBPQ_STATIC="${libpq_static}" \
  -e LIBPQ_EXTRA_RUSTFLAGS="${libpq_extra_rustflags}" \
  -e STATIX_LIBPQ_AUTO_OPENSSL_ARCHIVES="${auto_libpq_openssl_archives}" \
  -e STATIX_DISABLE_LIBPQ_FALLBACK="${disable_libpq_fallback}" \
  -e CARGO_PROFILE="${cargo_profile}" \
  -e CARGO_EXTRA_ARGS="${cargo_extra_args}" \
  -e BINARY_NAME="${binary_name}" \
  -e CMAKE="${cmake_bin}" \
  -v "${repo_root}:/workspace" \
  -w "${container_workdir}" \
  "${statix_image}" \
  bash -lc '
set -euo pipefail

if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

case "${STATIX_RUST_TOOLCHAIN}" in
  *-linux-musl)
    case "${RUST_TARGET}" in
      x86_64-unknown-linux-musl)
        loader="/lib/ld-musl-x86_64.so.1"
        sysroot="${SYSROOT:-/opt/musl/${TARGET:-x86_64-linux-musl}}"
        libc="${sysroot}/lib/libc.so"
        test -e "${libc}"
        if [[ -L "${loader}" && ! -e "${loader}" ]]; then
          rm -f "${loader}"
        fi
        if [[ ! -e "${loader}" ]]; then
          printf "[statix-validate] linking musl loader %s -> %s\n" "${loader}" "${libc}"
          mkdir -p "$(dirname -- "${loader}")"
          ln -s "${libc}" "${loader}"
        fi
        ;;
      *)
        printf "[statix-validate] error: no musl loader path is configured for target %s\n" "${RUST_TARGET}" >&2
        exit 1
        ;;
    esac
    ;;
esac

printf "[statix-validate] configuring Rust toolchain %s\n" "${STATIX_RUST_TOOLCHAIN}"
rustup override unset >/dev/null 2>&1 || true
rustup toolchain install "${STATIX_RUST_TOOLCHAIN}" --profile minimal --force-non-host
rustup default "${STATIX_RUST_TOOLCHAIN}" --force-non-host
rustup override set "${STATIX_RUST_TOOLCHAIN}"
rustup target add "${RUST_TARGET}"
rustc -vV | sed "s/^/[statix-validate]   /"

if [[ "${STATIX_DISABLE_LIBPQ_FALLBACK:-0}" == "1" && "${BINARY_NAME}" == "diesel-postgres" ]]; then
  libpq_static_libs="$(pkg-config --static --libs libpq)"
  printf "[statix-validate] pkg-config --static --libs libpq: %s\n" "${libpq_static_libs}"
  if [[ "${libpq_static_libs}" != *"-lpgcommon_shlib"* || "${libpq_static_libs}" != *"-lpgport_shlib"* || "${libpq_static_libs}" != *"-lcrypto"* ]]; then
    printf "[statix-validate] error: rebuilt image libpq.pc does not include the expected static libpq dependencies\n" >&2
    printf "[statix-validate]        rebuild without Docker cache or run without STATIX_DISABLE_LIBPQ_FALLBACK=1 for the old-image fallback\n" >&2
    exit 1
  fi
  cargo clean -p pq-sys >/dev/null 2>&1 || true
fi

libpq_extra_rustflags="${LIBPQ_EXTRA_RUSTFLAGS:-}"
if [[ "${STATIX_LIBPQ_AUTO_OPENSSL_ARCHIVES:-0}" == "1" ]]; then
  pgcommon_archive=""
  pgport_archive=""
  ssl_archive=""
  crypto_archive=""
  libc_archive=""
  musl_sysroot="${SYSROOT:-/opt/musl/${TARGET:-x86_64-linux-musl}}"
  for libdir in "${musl_sysroot}/lib" "${musl_sysroot}/lib64"; do
    if [[ -f "${libdir}/libpgcommon_shlib.a" && -f "${libdir}/libpgport_shlib.a" ]]; then
      pgcommon_archive="${libdir}/libpgcommon_shlib.a"
      pgport_archive="${libdir}/libpgport_shlib.a"
    fi
    if [[ -f "${libdir}/libssl.a" && -f "${libdir}/libcrypto.a" ]]; then
      ssl_archive="${libdir}/libssl.a"
      crypto_archive="${libdir}/libcrypto.a"
    fi
    if [[ -f "${libdir}/libc.a" ]]; then
      libc_archive="${libdir}/libc.a"
    fi
    if [[ -n "${pgcommon_archive}" && -n "${pgport_archive}" && -n "${ssl_archive}" && -n "${crypto_archive}" && -n "${libc_archive}" ]]; then
      break
    fi
  done
  if [[ -z "${pgcommon_archive}" || -z "${pgport_archive}" ]]; then
    printf "[statix-validate] error: could not find PostgreSQL shlib archives under %s/{lib,lib64}\n" "${musl_sysroot}" >&2
    exit 1
  fi
  if [[ -z "${ssl_archive}" || -z "${crypto_archive}" ]]; then
    printf "[statix-validate] error: could not find static OpenSSL archives under %s/{lib,lib64}\n" "${musl_sysroot}" >&2
    exit 1
  fi
  if [[ -z "${libc_archive}" ]]; then
    printf "[statix-validate] error: could not find musl libc archive under %s/{lib,lib64}\n" "${musl_sysroot}" >&2
    exit 1
  fi
  libpq_extra_rustflags="-C link-arg=${pgcommon_archive} -C link-arg=${pgport_archive} -C link-arg=${ssl_archive} -C link-arg=${crypto_archive} -C link-arg=${libc_archive}"
fi
if [[ -n "${libpq_extra_rustflags}" ]]; then
  STATIX_RUSTFLAGS="${STATIX_RUSTFLAGS} ${libpq_extra_rustflags}"
  printf "[statix-validate] libpq extra rustflags=%s\n" "${libpq_extra_rustflags}"
fi

normalized_target="${RUST_TARGET^^}"
normalized_target="${normalized_target//-/_}"
target_rustflags_env="CARGO_TARGET_${normalized_target}_RUSTFLAGS"
export "${target_rustflags_env}=${STATIX_RUSTFLAGS}"
unset RUSTFLAGS
printf "[statix-validate] %s=%s\n" "${target_rustflags_env}" "${STATIX_RUSTFLAGS}"

cargo_args=(build --target "${RUST_TARGET}")
case "${CARGO_PROFILE}" in
  release) cargo_args+=(--release) ;;
  dev|debug) ;;
  *) cargo_args+=(--profile "${CARGO_PROFILE}") ;;
esac

if [[ -n "${CARGO_EXTRA_ARGS}" ]]; then
  # shellcheck disable=SC2206
  split_extra_args=(${CARGO_EXTRA_ARGS})
  cargo_args+=("${split_extra_args[@]}")
fi

printf "[statix-validate] running: cargo %s\n" "${cargo_args[*]}"
cargo "${cargo_args[@]}"

binary="target/${RUST_TARGET}/"
case "${CARGO_PROFILE}" in
  release) binary+="release" ;;
  dev|debug) binary+="debug" ;;
  *) binary+="${CARGO_PROFILE}" ;;
esac
binary+="/${BINARY_NAME}"

test -x "${binary}"
file_output="$(file "${binary}")"
printf "%s\n" "${file_output}"
ldd_output="$(ldd "${binary}" 2>&1 || true)"
printf "%s\n" "${ldd_output}"
if [[ "${file_output}" != *"pie executable"* && "${file_output}" != *"static-pie linked"* ]]; then
  printf "[statix-validate] error: file(1) did not report a static PIE executable\n" >&2
  exit 1
fi
if [[ "${ldd_output}" != *"statically linked"* && "${ldd_output}" != *"not a dynamic executable"* ]]; then
  printf "[statix-validate] error: ldd did not report a static executable\n" >&2
  exit 1
fi
'

[[ -x "${host_binary}" ]] || die "host binary was not produced: ${host_binary}"

log "running Alpine runtime check"
# shellcheck disable=SC2086
docker run --rm \
  -v "${host_binary}:/app:ro" \
  "${runtime_image}" \
  /app ${runtime_args}
