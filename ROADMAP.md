# Roadmap

Statix aims to become a dependable Rust musl build environment for projects
with native dependencies. This roadmap is intentionally conservative: the first
priority is trust and repeatability, then broader target coverage.

## v0.1.0: First public baseline

- Validate a full local Docker build from a clean checkout.
- Publish reproducible validation details for smoke fixtures and native
  dependency targets.
- Test at least one Rust project that uses `openssl-sys`.
- Test at least one Rust project that uses `bindgen`.
- Keep optional large-workload validation separate from the release gate unless
  it adds clear release confidence.
- Keep `docs/SUPPORT_MATRIX.md` aligned with the Dockerfile defaults.
- Publish a release tag with the pinned Rust, GCC, musl, OpenSSL, CMake, and
  LLVM versions.
- Decide whether prebuilt images will be published to GHCR.

## v0.2.0: Reproducibility and supply chain

- Add checksums for downloaded source archives where practical.
- Generate a basic SBOM for release images.
- Document how to pin image digests in downstream CI.
- Add a release workflow once the full build has been validated.
- Keep source-built CMake and LLVM/libclang in the default full builder unless a
  separately validated variant proves host tools are sufficient.

## v0.3.0: More crate coverage

- Add documented recipes or fixtures for common native dependency crates:
  `openssl-sys`, `libz-sys`, `ring`, `rusqlite`, and `bindgen` users.
- Capture known failure modes and fixes in docs.
- Add issue labels for target support, native dependency support, and
  reproducibility.

## Later

- Evaluate `aarch64-unknown-linux-musl` support.
- Consider a smaller runtime-free build image variant.
- Consider a `fast` or `host-tools` variant that uses distribution CMake or
  libclang, validated separately from the default full builder.
- Consider scheduled rebuilds against patched base images.

## Non-goals

- Replacing `cross` for general Rust cross-compilation.
- Providing a minimal runtime container image.
- Supporting every Linux target before the default x86_64 musl workflow is
  proven stable.
