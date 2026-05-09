# Design

Statix is a full musl-oriented builder for Rust projects with native
dependencies. It favors correctness and reproducibility for difficult musl
static builds over minimal image size.

## Full musl-oriented build chain

The image builds the target GCC/musl toolchain first, then uses that toolchain
to build static native libraries and build tools that native-heavy Rust crates
often depend on.

CMake and LLVM/libclang are intentionally built in this environment. They are
not duplicated by accident:

- CMake is available inside the musl sysroot used by native build scripts.
- LLVM/libclang is available for `bindgen` users without depending on host
  distribution libclang packages.
- The build chain is kept aligned with the static musl target instead of mixing
  glibc host packages into the dependency path.

This design is more expensive than using `apt install cmake libclang-dev`, but
it keeps Statix focused on the projects that motivated it: native-heavy Rust
workloads that fail under simpler musl cross-compilation setups.

## Optimization boundary

Future optimizations should preserve the full builder as the default until the
native-dependency fixtures and any optional manual large-workload run prove
otherwise.

Acceptable low-risk optimizations:

- pinning source versions and checksums
- improving Docker cache boundaries
- adding build arguments for reproducibility
- adding validation fixtures

Riskier optimizations that require separate validation:

- replacing source-built CMake with a host package
- replacing source-built LLVM/libclang with a host package
- removing native libraries from the default image
- changing the Rust/musl support preset used by a validation case

## Variant direction

A future `fast` or `host-tools` variant may use host distribution packages for
CMake or libclang, but it should be validated separately from the full builder.
The default image should remain the conservative full builder until that variant
passes the same fixture set and an optional large-workload pass where useful.
