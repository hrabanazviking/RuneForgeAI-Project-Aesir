# Versioning and build identity

## Current state

The `pixi.toml` value `0.1.0` identifies the Pixi workspace package. It is not
an application release declaration. The Aesir CLI intentionally reports
`aesir development snapshot (unversioned)` because this repository has no
published CLI release version in its executable build path. Do not present the
workspace value, a branch name, or a commit count as a released CLI version.

At the time this policy was written, the checkout has no Git release tags.
Current source identity is the full Git commit SHA; built executable identity
is its SHA-256 digest; model identity is the admitted GGUF SHA-256 digest. These
identities answer different questions and must remain separate in evidence.

## Release version contract

When a release is deliberately prepared:

1. Select a semantic version `MAJOR.MINOR.PATCH` and publish the corresponding
   annotated tag `vMAJOR.MINOR.PATCH` on the reviewed release commit.
2. The release process must place that exact tag-derived version in the CLI
   artifact and require the artifact's `--version` output to match the tag.
3. A build without an exact release tag remains an unversioned development
   snapshot, even when built from a release branch or with a clean worktree.
4. Publish the source commit, tag, executable SHA-256, frozen toolchain identity
   and supported evidence/fixtures with the release. Never infer model identity
   from the application version.
5. Do not move or reuse a published version tag. Corrections require a new patch
   version and tag.

This is a repository policy only. It does not sign artifacts, certify supply
chain provenance, promise ABI compatibility, or claim an existing release.

## Acceptance checks

```sh
git tag --list 'v[0-9]*'
pixi run --frozen mojo --version
<built-aesir> --version
```

Before the first release, the tag list is expected to be empty and the CLI is
expected to say `unversioned`. A future release implementation must add a CI
gate that compares the executable version to the exact release tag.
