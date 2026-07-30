# Current Status

## Shared automation workspace

Path: `C:\Users\domes\OneDrive\Documentos\GitHub Release Work Flow`

- Branch: `main`
- Canonical repository: `https://github.com/LlamaMagic/plugin-release-automation`
- Visibility: public
- Initial commit: `bd577d56acc177e8f2575d905a8e172d0226f713`
- Local `main` tracks `origin/main`.
- GitHub Actions is enabled and currently permits all actions.

Implemented files:

- `.github/workflows/reusable-plugin-ci.yml`
- `config/products.json`
- `scripts/Build-PluginPackage.ps1`
- `scripts/Test-PluginPackage.ps1`
- `scripts/Set-AssemblyVersion.ps1`
- `docs/ARTIFACT_CONTRACT.md`
- `docs/REQUIRED_CONFIGURATION.md`
- `GITHUB_RELEASE_AUTOMATION_PLAN.md`
- `README.md`

The reusable workflow's callers require the automation repository and an immutable tag or commit
as inputs. The initial commit can be used for a pilot, but prefer a release tag after the first
GitHub-hosted validation succeeds.

## Manderville pilot

Path: `C:\Users\domes\OneDrive\Documentos\GitHub\MandervilleWeapons`

- Branch: `main`
- Remote: `https://github.com/DomesticWarlord/MandervilleWeapons.git`
- Modified, not staged: `MandervilleWeapons.csproj`
- Untracked: `.github/workflows/ci.yml`
- No commit or push has been made.

Changes in the project file:

- Replaced the machine-specific LlamaLibrary DLL reference with NuGet
  `LlamaLibrary` version `26.729.1252.39`.
- Updated `PandaAuth` from `4.0.7` to `4.1.0`.
- Updated `RebornBuddy.ReferenceAssemblies` from `1.0.882` to `1.0.886`.
- Enabled `CopyLocalLockFileAssemblies` for Release so `PandaAuth.dll` reaches the build output.
- Disabled the legacy local Reactor/staging post-build target only when `CI=true`.

The CI workflow restores from NuGet.org and the LlamaMagic Gitea feed, then builds Release on
`windows-latest`. It has read-only repository permissions and no secrets or deployment steps.

## Other local NuGet migrations

These files are modified but not staged, committed, or pushed:

- `C:\Users\domes\OneDrive\Documentos\GitHub\AnimaWeapons\AnimaWeapons.csproj`
- `C:\Users\domes\OneDrive\Documentos\GitHub\ZodiacWeapons\ZodiacWeapons.csproj`
- `C:\Users\domes\OneDrive\Documentos\GitHub\RelicWeapons\RelicWeapons.csproj`
- `C:\Users\domes\OneDrive\Documentos\GitHub\BeastTribesPlugin\BeastTribes.csproj`

Each replaces a machine-specific LlamaLibrary reference with NuGet version `26.729.1252.39`.
They were compilation-validated earlier, but full CI-mode workflow changes have not yet been
applied to them.

The other four plugin repositories were clean at checkpoint time.

## Access state

- The connected GitHub app returned 404 for the private repositories during the initial inventory.
- The local `gh` CLI was reauthenticated as `DomesticWarlord` with `read:org`, `repo`, and
  `workflow` access.
- The VPS is reachable as `ssh panda-vps`; no production changes were made.
