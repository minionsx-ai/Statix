# Third-Party Notices

Statix is MIT-licensed, but the Docker image built from this repository
downloads and builds third-party software under their own licenses.

This file is a practical summary for maintainers and downstream users. It is
not a complete legal inventory. If you distribute a prebuilt Statix image,
review the upstream license files and provide corresponding source or notices
as required by those licenses.

## Major components

| Component | Source | License notes |
| --- | --- | --- |
| Debian base image | `debian:bookworm` | Debian packages carry their own licenses. |
| musl-cross-make | `github.com/richfelker/musl-cross-make` | Build tooling is MIT/Expat; generated toolchain artifacts retain upstream licenses. |
| musl libc | `musl.libc.org` via musl-cross-make | MIT. |
| GNU binutils | `ftp.gnu.org` via musl-cross-make | GPL family licenses. |
| GCC | `gcc.gnu.org` via musl-cross-make | GPL family licenses with GCC runtime library exception considerations. |
| Rust toolchain | `rustup.rs` | Rust project components are primarily MIT or Apache-2.0, with component-specific notices. |
| zlib | `zlib.net/fossils` | zlib license. |
| libffi | `github.com/libffi/libffi` | MIT-style license. |
| ncurses | `ftp.gnu.org` | MIT/X11-style license for ncurses. |
| OpenSSL 3.5.6 | `openssl.org/source` | Apache License 2.0 for the OpenSSL 3.x series. |
| CMake | `github.com/Kitware/CMake` | BSD-style license. |
| LLVM/clang | `github.com/llvm/llvm-project` | Apache-2.0 with LLVM exceptions. |
| UPX | `github.com/upx/upx` | GPL-2.0-or-later with a special exception for compressed executables. |

## Distribution guidance

If you only use this repository internally to build your own project, the main
thing to track is whether your produced binary satisfies your project's
dependency licenses.

If you publish a Statix Docker image, treat the image as a binary
distribution of the included third-party software:

- keep the Dockerfile and version arguments public
- retain upstream copyright and license notices
- provide or reference corresponding source where required
- publish the image digest used by releases
- rebuild when the Debian base image or bundled upstream components receive
  relevant security fixes

## Maintainer checklist for dependency changes

- Update the version argument in `Dockerfile`.
- Update `README.md` if the default version changes.
- Update this file if the component license or source location changes.
- Include the changed component and version in release notes.
