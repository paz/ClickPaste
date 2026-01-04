# TODO for Future PRs

## Release Workflow (Separate PR)

The paz branch contains `.github/workflows/release.yml` which provides automated release functionality:

- Manual workflow dispatch for creating releases
- Version validation against AssemblyInfo.cs
- Automated changelog generation from commits
- Tag creation and GitHub release publishing
- Build artifact uploads to releases

This should be split into a separate PR focused on release automation.

## Build Tests (Separate PR)

The paz branch contains `tests/Test-Build.ps1` which provides build verification:

- Validates executables exist in all configurations
- Checks for single-file builds (no loose DLLs)
- Verifies version numbers match
- Tests file sizes

These tests need to be rewritten and improved before including in the main branch.

## Installer Scripts (Separate Feature Branch)

The paz branch contains `Install.cmd` and `Uninstall.cmd` for portable installation:

- User-level or system-level installation
- Registry startup integration
- Start menu shortcuts
- Clean uninstallation

This is a complete feature that deserves its own PR and review cycle.

## Release-NoAutoIt Configuration (Separate Feature Branch)

The paz branch includes a Release-NoAutoIt build configuration:

- 50% smaller executable (no AutoIt DLLs)
- Conditional compilation (#if NO_AUTOIT)
- Separate Fody configuration
- Reduced feature set

This is an advanced optimization that can be added after the core features are merged.
