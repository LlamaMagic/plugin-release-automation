# Updater Artifact Contract

This document records the exact root-level ZIP entries observed in the production repository on
2026-07-29. The first automation rollout must preserve these layouts.

All ZIPs contain `PandaAuth.dll`, the plugin assembly, its generated loader, and `Version.txt`.
No ZIP currently contains `LlamaLibrary.dll` or RebornBuddy reference assemblies.

| Product ID | ZIP root entries |
|---|---|
| `PandaFarmer` | `PandaAuth.dll`, `PandaFarmer.dll`, `PandaFarmerLoader.cs`, `Version.txt` |
| `PandaFarmerWPF` | `changelog.txt`, `PandaAuth.dll`, `PandaFarmerWPF.dll`, `PandaFarmerWPFLoader.cs`, `Version.txt` |
| `PandaTripleTriad` | `changelog.txt`, `PandaAuth.dll`, `PandaTripleTriad.dll`, `PandaTripleTriadLoader.cs`, `Version.txt` |
| `AnimaWeapons` | `AnimaWeapons.dll`, `AnimaWeaponsLoader.cs`, `PandaAuth.dll`, `Version.txt` |
| `MandervilleWeapons` | `MandervilleWeapons.dll`, `MandervilleWeaponsLoader.cs`, `PandaAuth.dll`, `Version.txt` |
| `ZodiacWeapons` | `PandaAuth.dll`, `Version.txt`, `ZodiacWeapons.dll`, `ZodiacWeaponsLoader.cs` |
| `RelicWeapons` | `PandaAuth.dll`, `RelicWeapons.dll`, `RelicWeaponsLoader.cs`, `Version.txt` |
| `SplendorousTools` | `PandaAuth.dll`, `SplendorousTools.dll`, `SplendorousToolsLoader.cs`, `SplendorousToolsSettings.cs`, `Version.txt` |
| `BeastTribes` | `BeastTribes.dll`, `BeastTribesLoader.cs`, `changelog.txt`, `PandaAuth.dll`, `Version.txt` |

Files that currently exist beside a ZIP in the repository, such as Anima Weapons start profiles,
are not automatically ZIP members. Adding them would be a separate compatibility decision.

## Loader generation

Loader templates use `__TARGET__` for the product name. Some legacy scripts also attempt to replace
`__VERSION__`, although not every current loader template contains that token. Packaging replaces
both tokens when present and writes `<ProductId>Loader.cs` at the archive root.

## Version contract

`Version.txt` contains the explicit release version passed to the workflow. It is not inferred from
the runner clock. The same version must be used for:

- assembly metadata;
- the Git tag after removing an optional leading `v`;
- `Version.txt`;
- object names and release metadata.

## Promotion rule

Panda Farmer WPF is a beta and must not invoke the admin webhook. When it replaces Panda Farmer,
its release configuration must be promoted deliberately to the Panda Farmer stable product slot.
