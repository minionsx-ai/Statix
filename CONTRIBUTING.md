# Contributing

Thanks for helping improve Statix.

By participating, follow the project
[Code of Conduct](CODE_OF_CONDUCT.md).

## Scope

Statix focuses on reproducible Rust musl cross-compilation environments with
native static dependencies. Please keep changes tied to that scope.

Good contributions include:

- fixing musl build failures for common Rust native dependencies
- adding support for another target triple with clear build instructions
- improving Docker build reproducibility
- reducing image size without removing required toolchain capability
- documenting known crate-specific fixes

## Development workflow

1. Create a topic branch.
2. Make the smallest change that solves the build problem.
3. Run Dockerfile checks where available:

   ```sh
   scripts/check-docs-sync.sh
   docker buildx build --check .
   ```

4. For functional changes, build the image and test it with a Rust project that
   exercises the affected dependency:

   ```sh
   docker build -t statix:test .
   docker run --rm -it -v "$PWD:/workspace" -w /workspace statix:test
   cargo build --release --target x86_64-unknown-linux-musl
   ```

5. Open a pull request with the exact error or use case that motivated the
   change.

## Reporting build failures

Please include:

- host OS and CPU architecture
- Docker or compatible runtime version
- Rust crate or project being built
- target triple
- the full failing command
- the relevant error output

Avoid screenshots of terminal output when text logs are available.
