# Validation Evidence

## Production contract recovery

The live repository used by `ProfileResourceManager` was inspected read-only on the VPS. The exact
ZIP members are recorded in `docs/ARTIFACT_CONTRACT.md`. The production repository checkout was
clean during inspection.

## Manderville build

The pilot was restored from:

- `https://api.nuget.org/v3/index.json`
- `https://gitea.llamamagic.net/api/packages/DomesticWarlord/nuget/index.json`

The full command-equivalent Release build ran with `CI=true` and completed:

```text
Build succeeded.
2434 Warning(s)
0 Error(s)
```

The warning count is pre-existing legacy/nullability/platform analyzer output. It is intentionally
not treated as errors in this first migration.

The local validation used Rider's bundled .NET SDK 10.0.201 because the machine-wide `dotnet`
installation has no SDK. The Actions workflow installs .NET SDK 8.x because the project targets
`net8.0-windows`.

## Package generation

The shared packager created:

```text
MandervilleWeapons-0.0.1.zip
SHA-256: 252b9c99b7f2cee960bf20c5a19ae88d5bff4866203da64dfcade1490d605744
```

That file is a disposable local validation artifact and is ignored by Git.

The validator confirmed exactly four root entries:

```text
MandervilleWeapons.dll
MandervilleWeaponsLoader.cs
PandaAuth.dll
Version.txt
```

It also confirmed that the loader has no remaining `__TARGET__` or `__VERSION__` placeholders and
that `Version.txt` contains `0.0.1`.

## Script validation

- All three PowerShell scripts passed parser validation.
- `config/products.json` parsed successfully.
- Every configured project, loader, changelog, and extra-file source path exists in its local
  checkout.
- `Set-AssemblyVersion.ps1` replaced wildcard assembly metadata with an explicit numeric version in
  a disposable copy.
- The packaging scripts work under Windows PowerShell 5.1 using `-ExecutionPolicy Bypass`, as well
  as being written for `pwsh` in GitHub Actions.

## GitHub-hosted validation

The public automation repository's Windows self-test passed:

- Run: `https://github.com/LlamaMagic/plugin-release-automation/actions/runs/30510345385`
- Duration: 19 seconds
- Versioning: passed
- Nine-product configuration and WPF webhook guard: passed
- Compatibility package generation and validation: passed
- GitHub Actions artifact upload: passed

## Not yet validated

- A plugin build through the shared reusable workflow.
- .NET Reactor installation, license activation, and obfuscation on a runner.
- R2 or COS upload and public download.
- Byte identity between R2 and COS.
- GitHub Release creation.
- HTTPS webhook behavior and product names.
