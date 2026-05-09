# Changelog

All notable changes to Statix will be documented in this file.

The format is based on Keep a Changelog, and this project uses semantic version
tags once releases begin.

## [Unreleased]

## [0.1.0] - 2026-05-09

First public release of Statix.

Statix is a Docker build environment for Rust projects that need static
`x86_64-unknown-linux-musl` binaries with native C/C++ dependencies. It builds
GCC, CMake, and LLVM/libclang from source inside the musl-oriented build path,
so crates that require a C compiler, static system libraries, CMake, or
`bindgen`/libclang work without project-level workarounds.

### Validated targets

All results are static-PIE `x86_64-unknown-linux-musl` binaries verified with
`file`, `ldd`, and runtime execution inside `alpine:latest`. Full evidence is in
[`docs/VALIDATION.md`](docs/VALIDATION.md).

| Priority | Target | Issue context | Status | Build time |
| --- | --- | --- | --- | --- |
| P0 | hello-static | — | `runtime passed` | — |
| P0 | tokio-cli | — | `runtime passed` | — |
| P0 | reqwest-rustls | — | `runtime passed` | — |
| P0 | crypto-signing | — | `runtime passed` | — |
| P0 | rusqlite-bundled | — | `runtime passed` | — |
| P1 | openssl-sys-demo | [cross-rs/cross#400](https://github.com/cross-rs/cross/issues/400) | `runtime passed` | 13 s |
| P1 | rdkafka-vendored-ssl | [rust-rdkafka#446](https://github.com/fede1024/rust-rdkafka/issues/446) | `runtime passed` | 3 m 33 s |
| P1 | rust-rocksdb-demo | [rust-rocksdb#174](https://github.com/rust-rocksdb/rust-rocksdb/issues/174) | `runtime passed` | 11 m 21 s |
| P2 | diesel-sqlite | [rusqlite#914](https://github.com/rusqlite/rusqlite/issues/914) | `runtime passed` | 1 m 44 s |
| P2 | diesel-postgres | [clux/diesel-cli#1](https://github.com/clux/diesel-cli/issues/1) | `runtime passed` | 27 s |
| P2 | snarkOS v4.6.3 | Optional large workload; patched/manual | `runtime passed` | 64 m 18 s |

The optional snarkOS `v4.6.3` large-workload run produced a static-PIE binary;
UPX reduced it from 153 MB to 31 MB. The binary runs in `alpine:latest` with no
shared library dependencies. This is retained as manual release evidence, not
as a primary compatibility claim.

### Added

- Docker build environment targeting `x86_64-unknown-linux-musl` with a
  complete musl-oriented toolchain: GCC via musl-cross-make, static zlib,
  libffi, ncurses, OpenSSL, CMake, LLVM/libclang, curl, and PostgreSQL/libpq.
- Parameterized Dockerfile for all major component versions via `--build-arg`.
- Default Rust toolchain uses the musl host triple so build scripts and proc
  macros are linked against musl, avoiding `mmap64`/`openat64`/glibc symbol
  mixing errors.
- Static PIE defaults: `-C relocation-model=pie -C link-arg=-static-pie`.
- `scripts/validate-target.sh` and issue-backed fixture structure for
  reproducible P0/P1/P2 validation targets.
- `examples/build-snarkos.sh` for optional large-workload validation, including
  musl compatibility patch, jemalloc exclusion, RocksDB static-bindgen fix, and
  `snarkVM` local workspace pin.
- GitHub Actions release workflow: builds image with BuildKit registry cache,
  publishes to GHCR with semver tags, creates release with component version
  table and image digest, runs P0 smoke tests.
- Legacy Rust `1.81.0` / musl `1.2.3` preset via Dockerfile build arguments.
- Docs: `DESIGN.md`, `VALIDATION.md`, `VALIDATION_TARGETS.md`,
  `SUPPORT_MATRIX.md`, `ROADMAP.md`.
- Community files: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  five GitHub issue templates (bug, build failure, feature, question, target).

### Known limitations

- `x86_64-unknown-linux-musl` only. `aarch64` and other targets are not
  yet supported.
- Image build takes 2–3 hours on a 4-core machine; GCC, CMake, and LLVM
  are built from source by design.
- Source archives are downloaded at build time without checksum verification.
  Pin image digests in production CI for reproducibility (see container image
  section below).
- `musl-cross-make` is pinned to a fixed commit that predates GCC 15; this has
  been tested and works, but the combination has not been independently audited.
