# Next Actions

Proceed in this order.

## 1. Validate the shared repository

The approved destination is the public repository
`LlamaMagic/plugin-release-automation`. Confirm its initial Actions run, repository visibility,
default branch, and absence of secrets before creating the first immutable release tag.

## 2. Review and publish the non-deploying Manderville pilot

Review the two uncommitted Manderville files, create a `codex/` branch, commit, push, and open a
draft PR only after user approval. Watch the first `Plugin CI` run and fix any runner-specific
restore or SDK issue.

Do not add tag triggers, Reactor, cloud credentials, or webhook steps to this first PR.

## 3. Publish and pin shared CI

After the shared repository is published:

1. Commit its current files.
2. Create an immutable bootstrap tag, for example `v0.1.0`.
3. Replace the standalone Manderville CI workflow with a small caller of
   `.github/workflows/reusable-plugin-ci.yml`.
4. Pass the exact automation repository and immutable tag.
5. Run the PR workflow again and compare its ZIP entry list to the local validation.

## 4. Establish the Reactor boundary

Obtain the installer URL/file, checksum, license delivery method, license terms for hosted runners,
and a working non-interactive Manderville command. Add an obfuscation job that produces the
assembly consumed by `Build-PluginPackage.ps1`.

The first tag-shaped test must only upload an Actions artifact. It must not touch R2, COS, or the
webhook.

## 5. Gather external configuration

Use `docs/REQUIRED_CONFIGURATION.md` as the exact checklist. The user still needs to supply:

- Cloudflare account ID, bucket name, public hostname, and permission to provision.
- Tencent bucket including APPID, region, public URL, object prefix, and credential approach.
- A rotated webhook key entered directly into GitHub.
- An HTTPS webhook endpoint and confirmed stable product names from Kayla.

## 6. Add deployment in gated stages

1. Upload to non-production R2 prefix and verify.
2. Upload the same bytes to non-production COS prefix and verify.
3. Compare downloaded SHA-256 values.
4. Create a draft/prerelease GitHub Release.
5. Add a protected production environment.
6. Run one production release with webhook disabled.
7. Enable the HTTPS webhook only after Kayla confirms the endpoint and product mapping.

## 7. Roll out repository by repository

After Manderville is proven, apply the same CI-only post-build guard, package-version normalization,
and caller workflow to:

1. Anima Weapons
2. Zodiac Weapons
3. Relic Weapons
4. Beast Tribes
5. Splendorous Tools
6. Panda Triple Triad
7. Panda Farmer
8. Panda Farmer WPF beta, with webhook permanently disabled

Validate each repository independently. Do not bulk-enable release tags across all repositories.
