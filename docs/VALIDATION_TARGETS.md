# Validation Targets

Statix validation targets should be grounded in real build and runtime
failure modes, not synthetic success cases alone. A target is marked
`runtime passed` only after it builds for `x86_64-unknown-linux-musl`, passes
static-link checks, and runs inside `alpine:latest`.

This page intentionally describes issue-backed contexts as public reports, not
as claims that any other project or tool can never solve the problem.

## How To Run A Target

```sh
docker build -t statix:latest .
scripts/validate-target.sh examples/hello-static
scripts/validate-target.sh validation/openssl-sys-demo
```

The validator can be inspected without Docker:

```sh
scripts/validate-target.sh --dry-run validation/rust-rocksdb-demo
```

The validator switches Cargo to `STATIX_RUST_TOOLCHAIN`, defaulting to
`1.95.0-x86_64-unknown-linux-musl`, before building. That keeps host build
scripts and proc macros on the same musl path as the final target binary. For
older images, the validator also creates the standard musl loader symlink before
executing the musl-host `rustc`. It also sets target-specific
`STATIX_RUSTFLAGS`, defaulting to
`-C relocation-model=pie -C link-arg=-static-pie`, so native dependency targets
stay on Statix's static PIE link path.

## Status Vocabulary

| Status | Meaning |
| --- | --- |
| `not tested` | Target exists but has no current run evidence. |
| `build passed` | Cargo build completed for the musl target. |
| `static check passed` | `file` reports static PIE output, and `ldd` reports `statically linked` or `not a dynamic executable`. |
| `runtime passed` | The binary also runs inside `alpine:latest`. |
| `blocked` | Current failure is documented and needs a targeted fix. |
| `manual` | Too slow or too broad for normal CI. |

## P0 Smoke Targets

These targets are not issue-backed. They exist to keep basic Statix behavior
observable before harder native dependency cases run.

All P0 smoke targets currently have `runtime passed` evidence.

| Target | Path | Validates |
| --- | --- | --- |
| `hello-static` | `examples/hello-static` | Basic Rust CLI, clap derive, static musl runtime. Status: `runtime passed`. |
| `tokio-cli` | `examples/tokio-cli` | Tokio runtime, async scheduling, JSON serialization. Status: `runtime passed`. |
| `reqwest-rustls` | `examples/reqwest-rustls` | HTTPS client path using rustls rather than OpenSSL. Status: `runtime passed`. |
| `crypto-signing` | `examples/crypto-signing` | Common crypto crates used by infra and blockchain tools. Status: `runtime passed`. |
| `rusqlite-bundled` | `examples/rusqlite-bundled` | Bundled SQLite native dependency and runtime query correctness. Status: `runtime passed`. |

## Issue-Backed Targets

| Priority | Target | Path | Public issue context | Statix validation point | Status |
| --- | --- | --- | --- | --- | --- |
| P1 | OpenSSL sys crate | `validation/openssl-sys-demo` | `cross-rs/cross#400` reports `openssl-sys` build failure where cross compilation could not locate OpenSSL and pkg-config rejected cross compilation. | Whether image-provided OpenSSL, `OPENSSL_DIR`, `OPENSSL_STATIC`, and `PKG_CONFIG_ALLOW_CROSS` can produce a static musl binary. | `runtime passed` |
| P1 | rdkafka with vendored SSL | `validation/rdkafka-vendored-ssl` | `rust-rdkafka#446`, `rust-rdkafka#524`, and `cross-rs/cross#1529` report musl or cross build failures around `rdkafka`, OpenSSL symbols, and CMake/toolchain setup. | Whether librdkafka source build, CMake, OpenSSL, and final static runtime work in Alpine. | `runtime passed` |
| P1 | RocksDB C++ dependency | `validation/rust-rocksdb-demo` | `rust-rocksdb#174` reports musl binding generation failures; `rust-rocksdb#440` reports `cross` musl failures for a project using `rust-rocksdb`. | Whether clang/libclang, C++ static link behavior, and RocksDB runtime put/get work together. | `runtime passed` |
| P2 | Optional snarkOS large workload | `validation/snarkos` and `examples/build-snarkos.sh` | Optional manual regression case for a large upstream Rust application; retained for broad native-dependency stress coverage, not as an upstream support claim. | Static musl build, workload-specific compatibility patch, and Alpine runtime verification for a slow real-world application. | `runtime passed`, `manual` |
| P2 | Diesel SQLite runtime | `validation/diesel-sqlite` | `rusqlite#914` reports a diesel SQLite musl cross-compile that segfaulted at runtime and notes that bundled `libsqlite3-sys` resolved the issue. | Runtime correctness, not just successful linking. | `runtime passed` |
| P2 | CKB | future `validation/ckb` | `nervosnetwork/ckb#903` reports trying `rust-musl-builder` and failing on RocksDB. | Large blockchain node with RocksDB after the smaller RocksDB target is stable. | `manual` |
| P2 | Diesel PostgreSQL/libpq | `validation/diesel-postgres` | `clux/diesel-cli#1` reports muslrust failures with many unresolved OpenSSL symbols through `libpq_sys`. | libpq, OpenSSL, pkg-config, and static link order. | `runtime passed` |
| P3 | tracy-client-sys | future `validation/tracy-client-sys` | `houseabsolute/actions-rust-cross#22` reports missing `musl-g++` for a C++ sys crate path. | C++ compiler availability and C++ runtime linkage. | `tracking` |
| P3 | nautilus rdkafka-sys | future `validation/nautilus-rdkafka` | `MystenLabs/nautilus#19` reports StageX/TEE build failures around `rdkafka-sys` and SSL symbol conflicts. | Deterministic/containerized native dependency path after P1 rdkafka is stable. | `tracking` |

## Recorded Smoke Results

### hello-static

- Path: `examples/hello-static`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/hello-static: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
hello-static 0.1.0
```

### tokio-cli

- Path: `examples/tokio-cli`
- Rust target: `x86_64-unknown-linux-musl`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/tokio-cli: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
[{"index":0,"label":"item-0"},{"index":1,"label":"item-1"}]
```

### reqwest-rustls

- Path: `examples/reqwest-rustls`
- Rust target: `x86_64-unknown-linux-musl`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/reqwest-rustls: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
200 OK https://example.com
```

### crypto-signing

- Path: `examples/crypto-signing`
- Rust target: `x86_64-unknown-linux-musl`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/crypto-signing: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
sha256=862f2b5a68cc7d874b46065a5b44312886c20e77f2307b20c0e7865a67b6546c blake3=e3ab66f85d3a4de2713a4b9c7542be6cf09ec902def2d88191284896e32bf76b bs58=2XSv4V3dEyREvyVkySQuULiuJPGh
```

### rusqlite-bundled

- Path: `examples/rusqlite-bundled`
- Rust target: `x86_64-unknown-linux-musl`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/rusqlite-bundled: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
sqlite=ok
```

## Recorded Issue-Backed Results

### openssl-sys-demo

- Path: `validation/openssl-sys-demo`
- Public issue context: `cross-rs/cross#400`
- Statix image id: `sha256:1906eac32724b43f83b4c1745fdb4b35dc30a81252651eb32030e9cbb0ef3426`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`; release build completed in `12.72s`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/openssl-sys-demo: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
openssl-sys-demo 0.1.0
```

### diesel-sqlite

- Path: `validation/diesel-sqlite`
- Public issue context: `rusqlite#914`
- Statix image id: `sha256:0d9be76af02dd85e56c7f28463a82599529c525c373b01e41c61680aff4fed23`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`; release build completed in `1m 44s`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/diesel-sqlite: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
diesel-sqlite=runtime passed
```

### rust-rocksdb-demo

- Path: `validation/rust-rocksdb-demo`
- Public issue context: `rust-rocksdb#174`, `rust-rocksdb#440`
- Statix image id: `sha256:0d9be76af02dd85e56c7f28463a82599529c525c373b01e41c61680aff4fed23`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`; release build completed in `11m 21s`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/rust-rocksdb-demo: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
rocksdb=passed
```

### rdkafka-vendored-ssl

- Path: `validation/rdkafka-vendored-ssl`
- Public issue context: `rust-rdkafka#446`, `rust-rdkafka#524`, `cross-rs/cross#1529`
- Statix image id: `sha256:0d9be76af02dd85e56c7f28463a82599529c525c373b01e41c61680aff4fed23`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`; release build completed in `3m 33s`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/rdkafka-vendored-ssl: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
librdkafka=2.12.1
```

### diesel-postgres

- Path: `validation/diesel-postgres`
- Public issue context: `clux/diesel-cli#1`
- Statix image id: `sha256:1906eac32724b43f83b4c1745fdb4b35dc30a81252651eb32030e9cbb0ef3426`
- Rust toolchain: `1.95.0-x86_64-unknown-linux-musl`
- Rust target: `x86_64-unknown-linux-musl`
- Rust flags: `-C relocation-model=pie -C link-arg=-static-pie`
- Build command: `cargo build --target x86_64-unknown-linux-musl --release`
- Result: `runtime passed`; release build completed in `27.43s`

Static verification:

```text
target/x86_64-unknown-linux-musl/release/diesel-postgres: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV), static-pie linked, not stripped
        statically linked
```

Alpine runtime verification:

```text
diesel-postgres 0.1.0
```

## Source Links

- [cross-rs/cross#400](https://github.com/cross-rs/cross/issues/400)
- [rust-rdkafka#446](https://github.com/fede1024/rust-rdkafka/issues/446)
- [rust-rdkafka#524](https://github.com/fede1024/rust-rdkafka/issues/524)
- [cross-rs/cross#1529](https://github.com/cross-rs/cross/issues/1529)
- [rust-rocksdb#174](https://github.com/rust-rocksdb/rust-rocksdb/issues/174)
- [rust-rocksdb#440](https://github.com/rust-rocksdb/rust-rocksdb/issues/440)
- [nervosnetwork/ckb#903](https://github.com/nervosnetwork/ckb/issues/903)
- [rusqlite#914](https://github.com/rusqlite/rusqlite/issues/914)
- [clux/diesel-cli#1](https://github.com/clux/diesel-cli/issues/1)
- [houseabsolute/actions-rust-cross#22](https://github.com/houseabsolute/actions-rust-cross/issues/22)
- [MystenLabs/nautilus#19](https://github.com/MystenLabs/nautilus/issues/19)
