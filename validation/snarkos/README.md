# Optional snarkOS Validation

This target is an optional manual large-workload validation case. It is heavier
than the small sample crates and native dependency fixtures, and it is not a
normal CI target or a required path for most Statix users. Use the
repository-level script when you intentionally want this extra release-note
evidence:

```sh
examples/build-snarkos.sh
```

The current recorded result is snarkOS `v4.6.3` / snarkVM `v4.6.3` with a
workload-specific compatibility patch, `x86_64-unknown-linux-musl`, static-link
verification, and an Alpine `/snarkos --version` runtime check. See
`docs/VALIDATION.md` for the evidence.
