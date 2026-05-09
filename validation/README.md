# Validation Targets

This directory contains reproducible validation targets for Statix.

Targets are split into two groups:

- `examples/` contains fast smoke tests that should eventually run in CI.
- `validation/` contains issue-backed or native-heavy targets that are more
  expensive and should be promoted to CI only after they are stable.

Run one target with:

```sh
docker build -t statix:latest .
scripts/validate-target.sh examples/hello-static
```

The validator builds with `x86_64-unknown-linux-musl`, checks `file(1)` and
`ldd` for static PIE output, then mounts the binary into
`alpine:latest` and runs `--version`. By default it applies
`-C relocation-model=pie -C link-arg=-static-pie` as target-specific Rust flags
for Statix's PIE-enabled musl sysroot.

Current target tiers:

| Tier | Target | Path | Status |
| --- | --- | --- | --- |
| P0 | hello-static | `examples/hello-static` | runtime passed |
| P0 | tokio-cli | `examples/tokio-cli` | runtime passed |
| P0 | reqwest-rustls | `examples/reqwest-rustls` | runtime passed |
| P0 | crypto-signing | `examples/crypto-signing` | runtime passed |
| P0 | rusqlite-bundled | `examples/rusqlite-bundled` | runtime passed |
| P1 | openssl-sys-demo | `validation/openssl-sys-demo` | runtime passed |
| P1 | rdkafka-vendored-ssl | `validation/rdkafka-vendored-ssl` | runtime passed |
| P1 | rust-rocksdb-demo | `validation/rust-rocksdb-demo` | runtime passed |
| P2 | optional snarkOS large workload | `validation/snarkos` | runtime passed, manual |
| P2 | diesel-sqlite | `validation/diesel-sqlite` | runtime passed |
| P2 | diesel-postgres | `validation/diesel-postgres` | runtime passed |

Issue context and prioritization live in
[docs/VALIDATION_TARGETS.md](../docs/VALIDATION_TARGETS.md).
