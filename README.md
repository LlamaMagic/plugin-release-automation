# GitHub Release Work Flow

Shared automation for building and publishing the Panda/Llama RebornBuddy plugins.

Canonical repository: <https://github.com/LlamaMagic/plugin-release-automation>

## Release gates

The shared release components expose four deliberately separate stages:

1. `validate` builds, runs licensed .NET Reactor, validates the protected DLL, and saves a rollback
   artifact. It cannot deploy.
2. `staging` publishes immutable artifacts to the staging R2 bucket and a staging prefix in Tencent
   COS, then downloads both copies and verifies their SHA-256.
3. `production` publishes production objects and a GitHub Release but cannot call the webhook.
4. `production-with-webhook` performs the same verified production release and calls the update
   webhook only for products enabled in both configuration and environment variables.

Production stages are rejected unless the workflow is running from a `v<version>` tag. Panda Farmer
WPF is disabled at the shared product-configuration layer and cannot notify the update service.
Repository-local jobs select the protected environment, then invoke pinned shared composite actions.
This is required because GitHub does not pass environment secrets through cross-repository reusable
workflow calls.

See [DEPLOYMENT_CONFIGURATION.md](docs/DEPLOYMENT_CONFIGURATION.md) for environment setup,
[GITHUB_RELEASE_AUTOMATION_PLAN.md](GITHUB_RELEASE_AUTOMATION_PLAN.md) for the rollout plan, and
[ARTIFACT_CONTRACT.md](docs/ARTIFACT_CONTRACT.md) for updater compatibility.

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
workflow provides the validated .NET Reactor output without changing the updater-facing ZIP format.
