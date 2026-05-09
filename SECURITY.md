# Security Policy

## Supported versions

Security fixes target the current `main` branch until the project starts
maintaining multiple supported release lines. For the current early public
stage, use the latest release tag and `main` as the supported baseline.

## Reporting a vulnerability

Do not open a public issue for vulnerabilities.

Use GitHub private vulnerability reporting for this repository if it is enabled.
If it is not available, contact the repository owner privately and include:

- affected image or commit
- vulnerable component and version
- reproduction steps
- expected impact
- any known workaround

## Dependency posture

Statix builds compiler and native dependency sources inside Docker. Treat the
resulting image as build infrastructure:

- pin image digests in production CI
- rebuild regularly for patched base images
- review upstream source URLs before changing versions
- publish release notes when compiler or native library versions change
