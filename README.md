<p align="center">
  <img src="docs/logo.svg" alt="Statix" width="420">
</p>

<p align="center">
  <a href="https://github.com/minionsx-ai/Statix/actions/workflows/docker-check.yml"><img src="https://github.com/minionsx-ai/Statix/actions/workflows/docker-check.yml/badge.svg" alt="Dockerfile"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
</p>

# Statix

Statix is a Docker-based build environment for Rust projects that need
fully static `x86_64-unknown-linux-musl` Linux binaries with native C/C++
dependencies.

It is designed for projects where a plain Rust musl target is not enough:
native crates may need a working musl C/C++ toolchain, static system libraries,
CMake, `bindgen`, libclang, OpenSSL, RocksDB, SQLite, PostgreSQL/libpq, or other
native components.

Statix focuses on one practical goal:

> Make native-heavy Rust projects easier to build as reproducible static musl
> Linux binaries.

A static project page for public status, validation, and roadmap tracking is
published at [minionsx-ai.github.io/Statix](https://minionsx-ai.github.io/Statix/).
The page source lives in [docs/index.html](docs/index.html).

## Project status

Statix is currently in early public-tooling stage.

The current focus is:

- a reliable `x86_64-unknown-linux-musl` builder
- reproducible Docker builds
- static native dependency support for real Rust projects
- clear validation reports backed by actual build and runtime evidence
- practical examples for crates and projects that commonly fail under plain musl

<!-- release-metadata:start -->
The latest source release is [`v0.1.0`](https://github.com/minionsx-ai/Statix/releases/tag/v0.1.0).

Release images are published to GHCR from version tags after the release
workflow builds the image and the P0 smoke tests pass.

```sh
docker pull ghcr.io/minionsx-ai/statix:v0.1.0
docker pull ghcr.io/minionsx-ai/statix@sha256:0094c4db34228b652ea854d4daf5cb7e78915340cd5599c334d110626e38f9d2
```

For reproducible CI, prefer the digest form.
<!-- release-metadata:end -->

## What Statix provides

The image includes:

- `x86_64-linux-musl` GCC toolchain built with `musl-cross-make`
- Rust `1.95.0-x86_64-unknown-linux-musl` as the default toolchain
- static zlib
- static libffi
- static ncurses
- static OpenSSL
- static curl
- static PostgreSQL/libpq
- static CMake build
- LLVM/clang build for `bindgen`
- UPX for optional binary compression
- musl-oriented defaults for Cargo, pkg-config, OpenSSL, libpq, libclang, and
  CA certificates

## When to use Statix

Use Statix when:

- `cargo build --target x86_64-unknown-linux-musl` fails because a native crate
  cannot find a musl C compiler, static library, CMake, or libclang.
- You need a repeatable Docker environment for static Linux binaries.
- Your Rust project depends on native libraries such as OpenSSL, RocksDB,
  librdkafka, SQLite, PostgreSQL/libpq, zlib, libffi, or C/C++ bindings.
- You want the build environment to carry the native dependency setup instead
  of encoding it in every Rust project.
- You want a build image that is optimized for native-heavy musl builds rather
  than only pure Rust projects.

Statix is not intended to be:

- a general-purpose Rust CI image
- a replacement for `cross`
- a minimal production runtime image
- a small base image optimized for fast pulls
- a universal solution for every musl build failure

## Why Statix exists

Rust's musl target works well for many pure Rust projects. The difficult cases
usually start when a project depends on native C/C++ components.

Common failure points include:

- missing musl C/C++ compiler
- native crates detecting host glibc tools
- pkg-config resolving host libraries
- CMake using the wrong compiler or sysroot
- `bindgen` failing because libclang is unavailable
- OpenSSL requiring static configuration
- RocksDB, SQLite, librdkafka, or libpq requiring native builds
- build scripts or proc macros mixing GNU host assumptions with musl targets
- linker errors caused by host and target toolchain mismatch
- runtime verification failures after a seemingly successful build

Statix solves this by putting the Rust toolchain, musl GCC toolchain, static
native libraries, CMake, and LLVM/libclang into one reproducible Docker build
environment.

## Design rationale

Statix intentionally builds CMake and LLVM/libclang inside the musl-oriented
toolchain environment instead of relying only on host distribution packages.

This keeps the native build chain aligned with the static musl target and helps
avoid accidental glibc leakage in projects that need a fully musl-oriented
build path.

The trade-off is that the image is slower to build and larger than lightweight
Rust cross-compilation images. That trade-off is intentional: Statix favors
reproducibility and native-heavy compatibility over image minimalism.

See [docs/DESIGN.md](docs/DESIGN.md) for more details.

## Real-world validation

Statix validation is built around small smoke fixtures and issue-backed
native dependency targets that are easy to rerun and compare. These targets
exercise C/C++ toolchains, CMake, bindgen, libclang, OpenSSL, RocksDB, SQLite,
PostgreSQL/libpq, librdkafka, and other system-library paths that commonly
break under plain musl builds.

Statix also keeps an optional manual large-workload example using
[ProvableHQ/snarkOS](https://github.com/ProvableHQ/snarkOS) `v4.6.3`. It is
retained as a stress test for a complex native-heavy Rust application, not as
the primary use case or a promise that upstream snarkOS builds unmodified. The
example applies workload-specific compatibility patches before building.

This optional target is an independent compatibility exercise. Statix is not
affiliated with, endorsed by, sponsored by, or maintained by the upstream
project or related organizations.

Validation notes live in [docs/VALIDATION.md](docs/VALIDATION.md).

The issue-backed validation target list lives in
[docs/VALIDATION_TARGETS.md](docs/VALIDATION_TARGETS.md). It separates fast P0
smoke examples from heavier native dependency targets such as OpenSSL,
librdkafka, RocksDB, Diesel/SQLite, and Diesel/PostgreSQL.

## Validation matrix

The P0 smoke matrix currently has runtime-passed evidence for:

- `hello-static`
- `tokio-cli`
- `reqwest-rustls`
- `crypto-signing`
- `rusqlite-bundled`

Issue-backed native dependency validation currently includes runtime-passed
evidence for:

- OpenSSL
- rdkafka / librdkafka
- RocksDB
- Diesel SQLite
- Diesel PostgreSQL / libpq

Run a small validation target:

```sh
scripts/validate-target.sh examples/hello-static
```

Run an issue-backed native dependency target:

```sh
scripts/validate-target.sh validation/openssl-sys-demo
```

## Optional large workload validation

After building the Statix image, you can run the optional large workload
validation example:

```sh
docker build -t statix:latest .
examples/build-snarkos.sh
```

The example writes sources, build artifacts, and a validation report under:

```text
.work/snarkos-v4.6.3
```

by default.

Use dry-run mode to inspect the exact refs, target, image, and build settings
before starting the full build:

```sh
examples/build-snarkos.sh --dry-run
```

Re-runs preserve existing `target/` directories by default, so cloud or remote
build machines can reuse previous compilation work.

The final binary is compressed with UPX by default after the script first
verifies that the uncompressed binary is static PIE.

Disable compression with:

```sh
COMPRESS_WITH_UPX=0 examples/build-snarkos.sh
```

The large workload example is intentionally manual and slow. It applies
workload-specific patches before building so the upstream workspace, native
dependencies, allocator behavior, Rust flags, and musl toolchain stay aligned
for a static PIE musl build. Treat this as release-note evidence for a difficult
application, not as a required path for ordinary Statix users.

See [docs/VALIDATION.md](docs/VALIDATION.md) for the full validation notes and
patch explanation.

## Quick start

Build the image:

```sh
docker build -t statix:latest .
```

Enter the build environment from a Rust project:

```sh
docker run --rm -it \
  -v "$PWD:/workspace" \
  -w /workspace \
  statix:latest
```

Build a static musl binary:

```sh
cargo build --release --target x86_64-unknown-linux-musl
```

Verify the result:

```sh
file target/x86_64-unknown-linux-musl/release/<binary>
ldd target/x86_64-unknown-linux-musl/release/<binary>
```

For a fully static binary, `ldd` should report that the executable is not
dynamically linked.

## Rust and native dependency defaults

The image exports common environment variables used by native Rust crates:

```sh
STATIX_RUST_TOOLCHAIN=1.95.0-x86_64-unknown-linux-musl
CC=/opt/musl/bin/x86_64-linux-musl-gcc
CXX=/opt/musl/bin/x86_64-linux-musl-g++
CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=/opt/musl/bin/x86_64-linux-musl-gcc
PKG_CONFIG_ALLOW_CROSS=1
PKG_CONFIG_PATH=/opt/musl/x86_64-linux-musl/lib/pkgconfig
OPENSSL_DIR=/opt/musl/x86_64-linux-musl
OPENSSL_STATIC=1
PQ_LIB_STATIC=1
LIBPQ_STATIC=1
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
SSL_CERT_DIR=/etc/ssl/certs
CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
LLVM_CONFIG_PATH=/opt/musl/llvm-build/bin/llvm-config
LIBCLANG_PATH=/opt/musl/llvm-build/lib
```

Most projects can use the image without adding a `.cargo/config.toml`.

If your project overrides linkers, pkg-config settings, OpenSSL settings, or
bindgen/libclang paths, make sure those overrides do not point back to the host
system.

The default Rust toolchain uses the musl host triple. This keeps Cargo, rustc,
build scripts, proc macros, and the native linker on the musl path.

That avoids mixing GNU host `libstd` with Statix's musl linker, which can
otherwise lead to missing glibc symbols such as:

```text
mmap64
openat64
gnu_get_libc_version
```

## Version policy

The default image tracks the current stable Rust toolchain and the musl baseline
used by Rust's current musl targets.

Older combinations remain available through Docker build arguments for projects
that need reproducible builds while migrating.

See [docs/SUPPORT_MATRIX.md](docs/SUPPORT_MATRIX.md) for supported version
presets and compatibility notes.

## Build arguments

The Dockerfile is parameterized for maintainers and downstream users:

| Argument | Default |
| --- | --- |
| `DEBIAN_VERSION` | `bookworm` |
| `TARGET` | `x86_64-linux-musl` |
| `RUST_TARGET` | `x86_64-unknown-linux-musl` |
| `RUST_VERSION` | `1.95.0` |
| `BINUTILS_VERSION` | `2.33.1` |
| `GCC_VERSION` | `15.1.0` |
| `MUSL_CROSS_MAKE_REF` | `e5147dde912478dd32ad42a25003e82d4f5733aa` |
| `MUSL_VERSION` | `1.2.5` |
| `ZLIB_VERSION` | `1.3.2` |
| `LIBFFI_VERSION` | `3.5.2` |
| `NCURSES_VERSION` | `6.6` |
| `OPENSSL_VERSION` | `3.5.6` |
| `CURL_VERSION` | `8.7.1` |
| `POSTGRESQL_VERSION` | `17.2` |
| `CMAKE_REF` | `v4.3.2` |
| `LLVM_REF` | `llvmorg-22.1.4` |
| `UPX_VERSION` | `4.2.1` |

Example:

```sh
docker build \
  --build-arg RUST_VERSION=1.95.0 \
  --build-arg OPENSSL_VERSION=3.5.6 \
  -t statix:rust-1.95 .
```

## Known limitations

- The default image targets `x86_64-unknown-linux-musl` only.
- Building the image is CPU and network intensive because GCC, CMake, and LLVM
  are built from source.
- CMake and LLVM/libclang are source-built by design. Replacing them with host
  distribution packages is a separate compatibility decision, not the default.
- The image currently pins OpenSSL `3.5.6`. Change `OPENSSL_VERSION` if your
  project requires another OpenSSL line.
- Source archives and Git repositories are downloaded during `docker build`.
  For production release pipelines, publish a pinned image digest from a trusted
  CI run.
- Some upstream projects may still require workload-specific patches, especially
  when they assume a GNU/glibc host toolchain or use native dependencies in
  non-portable ways.
- Statix improves the build environment, but it cannot guarantee that every
  upstream project is musl-compatible without source-level changes.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned work and contribution areas.

Planned areas include:

- publishing validated prebuilt images
- expanding native dependency validation targets
- improving build cache support
- adding more real-world Rust workload reports
- documenting common musl failure patterns
- supporting additional target presets where practical

## Third-party components

Statix downloads and builds several upstream projects. Their licenses apply
to those projects and to any image artifacts that contain them.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) before distributing
prebuilt images.

## Contributing

Issues and pull requests are welcome.

When reporting a failing crate or target, please include:

- project or crate name
- upstream commit or version
- build command
- target triple
- relevant error logs
- binary verification output, if available

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for project participation rules.

## License

Statix is released under the MIT License. See [LICENSE](LICENSE).
