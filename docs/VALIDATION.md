# Validation

This page tracks real projects that have been built with Statix.

The goal is not to claim broad compatibility from a single successful build.
The goal is to collect reproducible evidence for native-heavy Rust projects
that usually stress musl cross-compilation.

## Validation model

Statix validation should not depend on one upstream project. Evidence is
split across:

- fast smoke fixtures that can eventually run in CI
- native dependency fixtures tied to public build failure modes
- optional manual large-workload runs for release-note confidence

The optional large-workload example currently uses
[ProvableHQ/snarkOS](https://github.com/ProvableHQ/snarkOS) because early
Statix work found useful RocksDB, bindgen, jemalloc, and static-PIE edge
cases there. That example requires workload-specific compatibility patches and
uses its own Rust toolchain setting, so it should not be read as upstream
snarkOS support or as proof of unmodified upstream compatibility.

Validation entries should include the exact upstream commit, Statix commit
or image digest, build command, feature flags, and binary verification output.
Use `scripts/validate-target.sh` for normal fixture validation and
`examples/build-snarkos.sh` only when you intentionally want the optional large
workload evidence.

Issue-backed validation targets are tracked in
[VALIDATION_TARGETS.md](VALIDATION_TARGETS.md). That list is intentionally split
between fast smoke targets and heavier native dependency cases so CI does not
hide long-running manual validation behind a single green check.

The current default image tracks the latest stable Rust toolchain. If an
optional large-workload run needs an older Rust/musl combination, keep that
entry scoped to that workload and add separate fixture evidence for the current
default.

## Current validation cases

| Project or target set | Why it matters | Status |
| --- | --- | --- |
| P0/P1/P2 fixtures in [VALIDATION_TARGETS.md](VALIDATION_TARGETS.md) | Primary compatibility evidence for smoke builds and native dependencies such as OpenSSL, librdkafka, RocksDB, SQLite, and PostgreSQL/libpq. | `runtime passed` entries recorded in the target matrix. |
| Optional large workload using [ProvableHQ/snarkOS](https://github.com/ProvableHQ/snarkOS) | Slow manual stress test for a complex native-heavy Rust application. Requires workload-specific patches. | `runtime passed` with snarkOS `v4.6.3` and snarkVM `v4.6.3`; static-link and Alpine runtime evidence recorded below. |

## Optional snarkOS validation script

Run this from the repository root after building the image:

```sh
docker build -t statix:latest .
examples/build-snarkos.sh
```

The script uses `ProvableHQ/snarkOS` and `ProvableHQ/snarkVM` tag `v4.6.3` by
default, applies the musl compatibility patch, builds the `snarkos` binary for
`x86_64-unknown-linux-musl`, and writes
`.work/snarkos-v4.6.3/snarkos-validation-report.txt`. Re-runs preserve existing
`target/` directories unless `PRESERVE_TARGET_CACHE=0` is set. The script
verifies the uncompressed binary is static PIE, then compresses the final
binary with UPX by default and reports both pre-UPX and final sizes. Set
`COMPRESS_WITH_UPX=0` to skip compression.

The compatibility patch keeps the workload close to upstream while avoiding
musl linking traps:

- RocksDB is moved to a version/features combination that can use static
  bindgen support. After lockfile refresh, the script checks Cargo metadata so
  stale `rocksdb 0.21` / `librocksdb-sys 0.11` resolution fails before the full
  build starts. snarkOS also receives a `[patch.crates-io]` table for local
  snarkVM workspace crates so the build cannot silently fall back to published
  `snarkvm-*` crates that still depend on the old RocksDB chain.
- The GNU-only jemalloc global allocator path is excluded for musl, and
  target-specific Rust flags keep Rust on Statix's static PIE link path.
- snarkOS is switched to the `1.88.0-x86_64-unknown-linux-musl` Rust toolchain
  after checkout, and `x86_64-unknown-linux-musl` is installed for that
  toolchain. This keeps Cargo, rustc, build scripts, and the native C/LLVM
  toolchain on the musl path.
- The standard musl loader path `/lib/ld-musl-x86_64.so.1` is made available
  before rustup tries to execute musl-host Rust binaries. Without this loader
  symlink, rustup may install the toolchain but fail to read the `rustc`
  version with `No such file or directory`.

The script prints the patched jemalloc lines and runs a `cargo tree` preflight
before the full build. If `tikv-jemallocator` is still present for
`x86_64-unknown-linux-musl`, the script exits before spending time on the full
link.

Common overrides:

```sh
STATIX_IMAGE=statix:rust-1.95 \
SNARKOS_REF=v4.6.3 \
SNARKVM_REF=v4.6.3 \
SNARKOS_RUST_TOOLCHAIN=1.88.0-x86_64-unknown-linux-musl \
examples/build-snarkos.sh
```

## Optional snarkOS v4.6.3 validation result

- Upstream repository: `https://github.com/ProvableHQ/snarkOS`
- snarkOS ref: `v4.6.3`
- snarkOS commit: `187f9830b6491b640fa3fa9832658f4de6665f08`
- snarkVM ref: `v4.6.3`
- snarkVM commit: `4cc886c08142280665338b26544cbcc80aed5fe6`
- Statix commit: `3f861fdc08212b6bf36875539e4fb2974f945dd3`
- Statix image: `statix:latest`
- Statix image id:
  `sha256:1906eac32724b43f83b4c1745fdb4b35dc30a81252651eb32030e9cbb0ef3426`
- Rust toolchain: `1.88.0-x86_64-unknown-linux-musl`
- Target triple: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --bin snarkos --release`
- Result: `runtime passed`; `release` build completed in `64m 18s`
- UPX compression: enabled; `153422096` bytes before UPX, `31115368` bytes final

Binary verification:

```text
[file before UPX]
/workspace/target/x86_64-unknown-linux-musl/release/snarkos: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped

[file final]
/workspace/target/x86_64-unknown-linux-musl/release/snarkos: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, no section header

[ldd]
        not a dynamic executable
```

Alpine runtime verification:

```sh
docker run --rm \
  -v "$PWD/snarkos:/snarkos:ro" \
  alpine:latest \
  /snarkos --version
```

```text
snarkos unknown_branch 187f9830b6491b640fa3fa9832658f4de6665f08 features=[default,snarkos_node_metrics]
```

## Report format

Add a short entry for each validated project:

```md
## Project name

- Upstream repository:
- Upstream commit:
- Statix commit or image digest:
- Host platform:
- Target triple:
- Build command:
- Relevant feature flags:
- Result:
- Binary verification:
```

Use `file` and `ldd` output for binary verification when possible.

## Remote build server evidence

It is acceptable to run release validation on a remote build server. Record the
server-side command output so the result can be traced back to a Statix commit
and Docker image id:

```sh
git rev-parse HEAD
docker version
docker buildx version || true
docker buildx build --check .
docker build -t statix:local .
docker image inspect statix:local --format '{{.Id}}'
scripts/validate-target.sh examples/hello-static
scripts/validate-target.sh validation/openssl-sys-demo
scripts/validate-target.sh validation/diesel-postgres
```

If the release notes include optional large-workload evidence, capture the
snarkOS report produced by:

```sh
STATIX_IMAGE=statix:local examples/build-snarkos.sh
```

The generated `.work/snarkos-v4.6.3/snarkos-validation-report.txt` file can be
copied into the release notes or summarized in this document with the exact
snarkOS commit, snarkVM commit, Statix commit, image id, build command,
binary verification, and Alpine runtime output.

## Example binary verification

```sh
file target/x86_64-unknown-linux-musl/release/<binary>
ldd target/x86_64-unknown-linux-musl/release/<binary>
```

For a static musl binary, `ldd` should report that the executable is not
dynamically linked.
