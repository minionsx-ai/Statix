# Support Matrix

Statix defaults to the current stable Rust release and the musl baseline used
by Rust's current musl targets. Older combinations can still be selected with
Docker build arguments when a project needs reproducible legacy builds.

## Current defaults

| Preset | Rust | musl | musl-cross-make ref | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| `current` | `1.95.0` | `1.2.5` | `e5147dde912478dd32ad42a25003e82d4f5733aa` | Default | Tracks the current stable Rust musl baseline. Release-prep image validation is recorded for smoke and native-dependency fixtures; optional large-workload runs may use workload-specific Rust settings. |
| `legacy-rust-1.81` | `1.81.0` | `1.2.3` | `fe915821b652a7fa37b34a596f47d8e20bc72338` | Compatibility preset | Matches the musl version used by Rust `1.81.0`'s official musl toolchain script. Use this when a project is pinned to old Rust behavior. |

## Why the default is Rust 1.95.0 and musl 1.2.5

Rust `1.95.0` is the current stable release as of April 16, 2026. Rust's musl
targets moved to musl `1.2.5` starting with the Rust `1.93` line, and current
Rust musl targets document musl `1.2.5` as their baseline.

The musl-cross-make ref used by Statix is pinned separately because this
image also builds native C/C++ libraries and a GCC-based target toolchain. That
ref must remain explicit so image rebuilds are reproducible.

## Build with a preset

Current default:

```sh
docker build -t statix:rust-1.95 .
```

Explicit current preset:

```sh
docker build \
  --build-arg RUST_VERSION=1.95.0 \
  --build-arg MUSL_VERSION=1.2.5 \
  --build-arg MUSL_CROSS_MAKE_REF=e5147dde912478dd32ad42a25003e82d4f5733aa \
  -t statix:rust-1.95 .
```

Rust 1.81 compatibility preset:

```sh
docker build \
  --build-arg RUST_VERSION=1.81.0 \
  --build-arg MUSL_VERSION=1.2.3 \
  --build-arg MUSL_CROSS_MAKE_REF=fe915821b652a7fa37b34a596f47d8e20bc72338 \
  -t statix:rust-1.81 .
```

## Validation expectations

Each supported preset should eventually have:

- full image build result
- at least one native-heavy Rust fixture
- optional manual large-workload validation where useful
- `file` and `ldd` output for the produced binary

See [VALIDATION.md](VALIDATION.md).
