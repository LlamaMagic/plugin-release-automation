# GitHub Release Work Flow

Shared automation for building and publishing the Panda/Llama RebornBuddy plugins.

Canonical repository: <https://github.com/LlamaMagic/plugin-release-automation>

The current implementation is intentionally limited to build and package validation. It does not
upload to Cloudflare R2 or Tencent COS, create a GitHub Release, or call the admin webhook.

## Current checkpoint

- The updater-compatible ZIP layouts have been recovered from the live VPS.
- `scripts/Build-PluginPackage.ps1` creates a deterministic package layout from an already-built
  assembly.
- `scripts/Test-PluginPackage.ps1` rejects missing or unexpected ZIP entries.
- `.github/workflows/reusable-plugin-ci.yml` is a reusable, non-deploying CI workflow.
- Manderville Weapons is the first pilot repository.

See [GITHUB_RELEASE_AUTOMATION_PLAN.md](GITHUB_RELEASE_AUTOMATION_PLAN.md) for the complete rollout
plan and [docs/ARTIFACT_CONTRACT.md](docs/ARTIFACT_CONTRACT.md) for the compatibility contract.

## Local package test

```powershell
.\scripts\Build-PluginPackage.ps1 `
  -ConfigPath .\config\products.json `
  -ProductId MandervilleWeapons `
  -RepositoryRoot C:\path\to\MandervilleWeapons `
  -BuildOutputDirectory C:\path\to\MandervilleWeapons\MandervilleWeapons\bin\Release\net8.0-windows `
  -Version 1.2.3 `
  -ReleaseOutputDirectory .\artifacts
```

The packaging step deliberately accepts the compiled assembly as an input boundary. The release
workflow can later provide the .NET Reactor output without changing the updater-facing ZIP format.
