#!/usr/bin/env python3
"""Update README and GitHub Pages release metadata blocks."""

from __future__ import annotations

import argparse
import html
import re
import sys
import textwrap
from pathlib import Path


README = Path("README.md")
DOCS_INDEX = Path("docs/index.html")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update generated release metadata blocks in README.md and docs/index.html."
    )
    parser.add_argument("--version", required=True, help="Release tag, for example v0.1.0.")
    parser.add_argument(
        "--digest",
        default="",
        help="Published image digest, for example sha256:abc123. Required unless --pending is set.",
    )
    parser.add_argument(
        "--image",
        default="ghcr.io/minionsx-ai/statix",
        help="Container image name without tag or digest.",
    )
    parser.add_argument(
        "--repo",
        default="minionsx-ai/Statix",
        help="GitHub repository owner/name.",
    )
    parser.add_argument(
        "--pending",
        action="store_true",
        help="Write source-first pending GHCR text instead of published image text.",
    )
    return parser.parse_args()


def normalize_version(version: str) -> str:
    version = version.strip()
    if not version:
        raise ValueError("version must not be empty")
    return version if version.startswith("v") else f"v{version}"


def validate_digest(digest: str, pending: bool) -> str:
    digest = digest.strip()
    if pending:
        return digest
    if not digest.startswith("sha256:"):
        raise ValueError("--digest must start with sha256: unless --pending is set")
    return digest


def replace_block(text: str, name: str, body: str) -> str:
    start = f"<!-- {name}:start -->"
    end = f"<!-- {name}:end -->"
    pattern = re.compile(
        rf"^([ \t]*){re.escape(start)}.*?^[ \t]*{re.escape(end)}",
        re.DOTALL | re.MULTILINE,
    )

    def replacement(match: re.Match[str]) -> str:
        indent = match.group(1)
        return f"{indent}{start}\n{body.rstrip()}\n{indent}{end}"

    updated, count = pattern.subn(replacement, text)
    if count != 1:
        raise ValueError(f"expected exactly one {name} block, found {count}")
    return updated


def release_url(repo: str, version: str) -> str:
    return f"https://github.com/{repo}/releases/tag/{version}"


def build_readme_block(repo: str, image: str, version: str, digest: str, pending: bool) -> str:
    url = release_url(repo, version)
    if pending:
        return f"""The latest source release is [`{version}`]({url}).

The matching GHCR image is still pending public pull verification. Until the
release workflow publishes a pullable image, build the image locally:

```sh
docker build -t statix:local .
```"""

    return f"""The latest source release is [`{version}`]({url}).

Release images are published to GHCR from version tags after the release
workflow builds the image and the P0 smoke tests pass.

```sh
docker pull {image}:{version}
docker pull {image}@{digest}
```

For reproducible CI, prefer the digest form."""


def build_status_block(repo: str, image: str, version: str, pending: bool) -> str:
    version_html = html.escape(version)
    image_html = html.escape(image)
    url = html.escape(release_url(repo, version), quote=True)

    container_status = (
        '<span class="badge pending">pending</span> GHCR public pull verification'
        if pending
        else f'<span class="badge pass">published</span> <code>{image_html}:{version_html}</code>'
    )
    summary = (
        "The source repository and project page are public. The GHCR image is "
        "still treated as pending until the tag-driven release workflow "
        "finishes and the package is pullable without maintainer credentials."
        if pending
        else "The source repository, project page, and GHCR image are public. "
        "The release image below was published by the tag-driven workflow "
        "after P0 smoke tests passed."
    )
    summary = "\n          ".join(textwrap.wrap(summary, width=78))

    return f"""        <p>
          {summary}
        </p>
        <dl class="status-grid">
          <div>
            <dt>Repository</dt>
            <dd><span class="badge pass">public</span> <a href="https://github.com/{html.escape(repo, quote=True)}">{html.escape(repo)}</a></dd>
          </div>
          <div>
            <dt>Source release</dt>
            <dd><span class="badge pass">latest</span> <a href="{url}">{version_html}</a></dd>
          </div>
          <div>
            <dt>Checks</dt>
            <dd><span class="badge pass">protected</span> <a href="https://github.com/{html.escape(repo, quote=True)}/actions/workflows/docker-check.yml">dockerfile-check</a></dd>
          </div>
          <div>
            <dt>Container image</dt>
            <dd>{container_status}</dd>
          </div>
        </dl>"""


def build_quickstart_block(
    repo: str, image: str, version: str, digest: str, pending: bool
) -> str:
    version_html = html.escape(version)
    image_html = html.escape(image)
    digest_html = html.escape(digest)
    url = html.escape(release_url(repo, version), quote=True)

    if pending:
        return f"""        <h2>Quick start from source</h2>
        <pre><code>git clone https://github.com/{html.escape(repo)}.git
cd Statix
docker build -t statix:local .

docker run --rm -it -v "$PWD:/workspace" -w /workspace \\
  statix:local

cargo build --release --target x86_64-unknown-linux-musl</code></pre>
        <dl class="meta">
          <div>
            <dt>Version</dt>
            <dd><a href="{url}">{version_html}</a></dd>
          </div>
          <div>
            <dt>Image</dt>
            <dd><code>statix:local</code> until GHCR is public-pull verified</dd>
          </div>
          <div>
            <dt>Digest</dt>
            <dd>Published image digest pending release workflow completion.</dd>
          </div>
          <div>
            <dt>Target</dt>
            <dd><code>x86_64-unknown-linux-musl</code></dd>
          </div>
        </dl>"""

    return f"""        <h2>Quick start from GHCR</h2>
        <pre><code>docker pull {image_html}:{version_html}

docker run --rm -it -v "$PWD:/workspace" -w /workspace \\
  {image_html}:{version_html}

cargo build --release --target x86_64-unknown-linux-musl</code></pre>
        <dl class="meta">
          <div>
            <dt>Version</dt>
            <dd><a href="{url}">{version_html}</a></dd>
          </div>
          <div>
            <dt>Image</dt>
            <dd><code>{image_html}:{version_html}</code></dd>
          </div>
          <div>
            <dt>Digest</dt>
            <dd><code>{image_html}@{digest_html}</code></dd>
          </div>
          <div>
            <dt>Target</dt>
            <dd><code>x86_64-unknown-linux-musl</code></dd>
          </div>
        </dl>"""


def update_files(repo: str, image: str, version: str, digest: str, pending: bool) -> None:
    readme = README.read_text()
    readme = replace_block(
        readme,
        "release-metadata",
        build_readme_block(repo, image, version, digest, pending),
    )
    README.write_text(readme)

    docs = DOCS_INDEX.read_text()
    docs = replace_block(
        docs,
        "release-status",
        build_status_block(repo, image, version, pending),
    )
    docs = replace_block(
        docs,
        "release-quickstart",
        build_quickstart_block(repo, image, version, digest, pending),
    )
    DOCS_INDEX.write_text(docs)


def main() -> int:
    args = parse_args()
    try:
        version = normalize_version(args.version)
        digest = validate_digest(args.digest, args.pending)
        update_files(args.repo, args.image.rstrip("/"), version, digest, args.pending)
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
