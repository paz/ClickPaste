# CLAUDE.md - ClickPaste Development Guide

## Project Overview

**ClickPaste** is a Windows 10/11 notification area (system tray) utility that pastes clipboard contents as keyboard keystrokes to any window you click. This solves the problem of pasting to applications that block normal clipboard operations, including:
- Citrix/RDP remote sessions
- Virtual machines
- UAC-elevated applications (when run elevated)
- Legacy applications with restricted paste

**Current Version**: 1.4.0.0
**Status**: Stable, production-ready
**Framework**: .NET Framework 4.8, Windows Forms
**Output**: Single-file executable (via Costura.Fody)

## Core Philosophy

1. **Stability First**: The application is mature and stable. Changes should be conservative and thoroughly tested.
2. **Single Purpose**: Do one thing well - convert clipboard text to keystrokes.
3. **Minimal Footprint**: Tray-only application with no main window.
4. **User Control**: Configurable delays, hotkeys, and typing methods accommodate different environments.

## Build Commands

```bash
# Build Debug (requires Visual Studio or MSBuild)
msbuild ClickPaste.sln /p:Configuration=Debug

# Build Release (with code signing - requires certificate)
msbuild ClickPaste.sln /p:Configuration=Release

# Build Release without code signing (for CI/testing)
msbuild ClickPaste.sln /p:Configuration=Release /p:SkipCodeSigning=true

# Build Release-NoAutoIt (smaller build without AutoIt dependency)
msbuild ClickPaste.sln /p:Configuration=Release-NoAutoIt /p:SkipCodeSigning=true
```

### Build Configurations

| Configuration | Output | AutoIt | Description |
|--------------|--------|--------|-------------|
| Debug | bin\Debug\ | Yes | Development build with debug symbols |
| Release | bin\Release\ | Yes | Production build with all typing methods |
| Release-NoAutoIt | bin\Release-NoAutoIt\ | No | Smaller build without AutoIt dependency |

The **Release-NoAutoIt** configuration produces a smaller executable by excluding AutoIt. It only supports Forms.SendKeys and SendInput Unicode typing methods. The AutoIt option is hidden in Settings for this build.

**Requirements:**
- Windows (WinForms project)
- MSBuild / Visual Studio 2017+
- .NET Framework 4.8 SDK
- Code signing certificate (Release builds only, optional)

## Continuous Integration

GitHub Actions workflow (`.github/workflows/build.yml`) automatically:
- Builds Debug, Release, and Release-NoAutoIt configurations on every push/PR
- Skips code signing in CI (uses `/p:SkipCodeSigning=true`)
- Uploads build artifacts for download

**Artifacts are retained:**
- Debug builds: 7 days
- Release builds: 30 days
- Release-NoAutoIt builds: 30 days

## Architecture

### File Structure
```
ClickPaste/
├── .github/
│   └── workflows/
│       └── build.yml            # GitHub Actions CI workflow
├── Program.cs                   # Entry point, ThemeHelper, TrayApplicationContext
├── HotKeyManager.cs             # Global hotkey registration via Win32 API
├── Native.cs                    # P/Invoke declarations for Windows API
├── SettingsForm.cs              # Settings dialog UI and logic
├── SettingsForm.Designer.cs     # WinForms designer (auto-generated)
├── FodyWeavers.xml              # Costura.Fody config (Release with AutoIt)
├── FodyWeavers.NoAutoIt.xml     # Costura.Fody config (Release-NoAutoIt)
├── Properties/
│   ├── Settings.Designer.cs     # User settings (auto-generated)
│   └── Resources.Designer.cs    # Embedded resources (auto-generated)
├── Resources/                   # Icons (Target, TargetDark, Typing)
└── AutoItX3*.dll                # AutoIt3 typing engine (embedded by Costura)
```

### Key Components

1. **TrayApplicationContext** (`Program.cs:80-363`)
   - Main application state machine
   - Manages tray icon, context menu, mouse/keyboard hooks
   - Orchestrates the target selection → typing workflow
   - Key methods: `StartTrack()`, `EndTrack()`, `StartTyping()`, `PrepareKeystrokes()`

2. **HotKeyManager** (`HotKeyManager.cs`)
   - Static utility for global Windows hotkey registration
   - Uses hidden MessageWindow on background thread for WM_HOTKEY
   - Thread-safe registration/unregistration

3. **Native** (`Native.cs`)
   - P/Invoke wrappers for Win32 APIs
   - Cursor management, keyboard state, window functions

4. **Settings** (`Properties/Settings.Designer.cs`)
   - User-scoped settings persisted to Windows registry
   - TypeMethod, KeyDelayMS, HotKey, HotKeyModifier, etc.

### Typing Methods

Three methods available for simulating keystrokes:

| Method | Implementation | Best For |
|--------|---------------|----------|
| `Forms_SendKeys` | `System.Windows.Forms.SendKeys.SendWait()` | Simple cases, standard Windows apps |
| `AutoIt_Send` | AutoIt3 COM interop | Difficult applications, games |
| `SendInput_ScanCode` | Scan codes + ALT code fallback | Universal - works everywhere including VM consoles |

**Default is SendInput** (TypeMethod=3) - uses scan codes with ALT code fallback for unmappable characters. Works with all applications including browser-based VM consoles.

**AutoIt** (TypeMethod=1) is available as a fallback for specific applications where it works better (e.g., some games).

#### How SendInput Works

1. **Tries scan codes first**: Uses `VkKeyScanEx` to find the character on any installed keyboard layout
2. **Falls back to ALT codes**: For characters not on any keyboard, uses ALT + numpad (e.g., ALT+0225 for á)

This approach works with browser-based VM consoles (Hyper-V, VMware) where `KEYEVENTF_UNICODE` fails because browsers receive `keyCode=0` for VK_PACKET events.

**Limitations:**
- Emoji and characters > U+FFFF cannot be sent (outside BMP)
- ALT code support depends on target application's codepage

### Application Workflow

```
Normal → [Click tray / Hotkey] → Target Selection → [Click window] → Typing → Normal
                                      ↑                    |
                                      └─ [Escape] ─────────┘
```

## Critical Code Paths

### PrepareKeystrokes (Program.cs:276-293)
Converts raw clipboard text to keystroke sequences:
- Normalizes `\r\n` to `\r` (both methods treat `\r` as Enter)
- Escapes special characters for Forms.SendKeys: `{}[]+^%~()`
- Returns list of individual keystrokes for cancellable loop

### StartTyping (Program.cs:206-274)
The main typing loop:
- Gets clipboard text
- Optional confirmation dialog for large pastes
- Spawns async task for non-blocking UI
- Per-keystroke delay with cancellation support
- Icon swaps to show typing in progress

## Settings Reference

| Setting | Type | Default | Purpose |
|---------|------|---------|---------|
| TypeMethod | int | 3 | 0=Forms.SendKeys, 1=AutoIt, 3=SendInput (2,4 are legacy aliases) |
| KeyDelayMS | int | 15 | Delay between keystrokes (ms) |
| StartDelayMS | int | 0 | Delay before typing starts (ms) |
| HotKey | string | "V" | Hotkey letter |
| HotKeyModifier | int | 3 | Modifier bitmask (1=Alt, 2=Ctrl, 4=Shift, 8=Win) |
| HotKeyMode | int | 0 | 0=Target selection, 1=JustGo (type immediately) |
| Confirm | bool | false | Show confirmation for large pastes |
| ConfirmOver | int | 100 | Character threshold for confirmation |

## Known Limitations

### Unicode & International Keyboards (Issues #3, #15, #29) - SOLVED

The original SendKeys and AutoIt methods work at the **virtual key/scancode level**, not character level. This caused problems with AltGr characters, dead keys, and Unicode characters.

**Solution**: The **SendInput Unicode** typing method (TypeMethod=2) was added in v1.4.0. It uses `SendInput` with the `KEYEVENTF_UNICODE` flag to inject characters directly, bypassing keyboard layout translation entirely.

**Recommendation**: International users should select "SendInput Unicode (international)" in Settings.

## Development Guidelines

### Do's
- Test on both typing methods before releasing
- Test with large clipboard contents (>1000 chars)
- Test hotkey functionality after settings changes
- Preserve cursor cleanup in exception handlers
- Keep the single-instance mutex check

### Don'ts
- Don't add features without clear use cases
- Don't break the existing typing methods
- Don't remove cancellation (Escape key) support
- Don't introduce dependencies that require installation
- Don't change the tray icon workflow without careful testing

### Testing Checklist
- [ ] Tray icon click → target selection → typing works
- [ ] Hotkey triggers target selection
- [ ] Escape cancels target selection
- [ ] Escape cancels mid-typing
- [ ] All three typing methods work in Notepad
- [ ] SendInput Unicode works with international characters
- [ ] Settings persist after restart
- [ ] Large paste confirmation works
- [ ] Dark/light theme icon selection works
- [ ] Settings dialog adapts to dark/light mode
- [ ] Version label displays correctly in Settings
- [ ] Single instance enforcement works
- [ ] Single-file build contains all dependencies

## Dependencies

### Runtime Dependencies

| Dependency | Type | Version | Purpose |
|------------|------|---------|---------|
| MouseKeyHook | NuGet | 5.7.1 | Global keyboard/mouse hooks |
| AutoIt3 | Embedded | 3.3.14.5 | Legacy typing method (unmaintained since 2021) |
| .NET Framework | Runtime | 4.8 | Application runtime |

### Build Dependencies

| Dependency | Type | Version | Purpose |
|------------|------|---------|---------|
| Costura.Fody | NuGet | 6.0.0 | Single-file build (embeds DLLs) |

### Framework References (Minimal)

| Reference | Purpose |
|-----------|---------|
| System | Core .NET types |
| System.Configuration | Settings persistence |
| System.Core | LINQ support |
| System.Drawing | Icon handling, theme colors |
| System.Windows.Forms | UI framework |

### AutoIt Dependency Notes

AutoIt DLLs are embedded into the executable by Costura.Fody (Release configuration only):
- `AutoItX3.Assembly.dll` - .NET wrapper
- `AutoItX3.dll` - 32-bit native
- `AutoItX3_x64.dll` - 64-bit native

**License**: Custom EULA (see `AutoIt_License.html`) - allows redistribution.

**Status**: AutoIt3 is unmaintained (last updated 2021). The **Release-NoAutoIt** build configuration excludes AutoIt entirely, producing a smaller executable. Use `NO_AUTOIT` define symbol to compile without AutoIt support.

**Note**: With the SendInput Unicode method now available and set as default, AutoIt is only needed for users who prefer its specific behavior with certain applications.

## Code Style

- Private fields: `_camelCase`
- Properties/Methods: `PascalCase`
- Minimal comments (code is self-documenting)
- WinForms patterns for UI
- P/Invoke for system integration
- Async/Task for non-blocking operations

## Common Modifications

### Adding a New Setting
1. Add to `Properties/Settings.settings` in Visual Studio
2. Update `SettingsForm.cs` to load/save the setting
3. Use in `TrayApplicationContext` via `Properties.Settings.Default.SettingName`

### Adding a New Typing Method
1. Add enum value to `TypeMethod` in `Program.cs`
2. Add case in `StartTyping()` switch statement
3. Add radio button in `SettingsForm.Designer.cs`
4. Update `_methods` array in `SettingsForm.cs`

## Security Considerations

- The app simulates keystrokes to any window - this is its core purpose
- When run elevated, it can type to elevated windows
- Clipboard contents are not persisted or logged
- No network communication
- Release builds should be code-signed

## Performance Notes

- Minimal memory footprint (tray app, hooks released when not in use)
- Per-keystroke delay is configurable (default 15ms)
- Icon size calculations done once at startup
- Async typing prevents UI blocking

---

## Code Review (December 2024)

### Performance Assessment

**Good Practices Already in Place:**
- Icons resized once at startup, not on each use
- Mouse/keyboard hooks properly disposed when not in target-selection mode
- Async Task.Run() for typing prevents UI thread blocking
- CancellationToken enables early exit from typing loop
- Minimal object allocations in hot paths

**Minor Optimization Opportunities:**
| Location | Issue | Impact | Recommendation |
|----------|-------|--------|----------------|
| `Program.cs:127-129` | `Thread.Sleep(300)` in loop waiting for modifier keys | Low - only runs on hotkey | Could use smaller sleep (50ms) for faster response |
| `Program.cs:87` | CancellationTokenSource not disposed | Low - small object | Dispose previous before creating new |

**Verdict**: Performance is excellent for this type of utility. No critical issues.

### Security Assessment

**Strengths:**
- No network communication
- No file I/O except standard .NET settings persistence
- Clipboard contents not logged or persisted
- Single-instance enforcement prevents duplicate processes
- Code signing for release builds (sign.bat)

**Observations:**
| Item | Status | Notes |
|------|--------|-------|
| Input Validation | N/A | No user input except settings (validated by .NET) |
| Sensitive Data Handling | Good | Clipboard read-only, not persisted |
| Privilege Escalation | By Design | App can paste to elevated windows when run elevated |
| Attack Surface | Minimal | Tray app with no exposed services |

**Verdict**: No security vulnerabilities identified. The app's purpose (keystroke injection) is inherently sensitive, but it's implemented safely.

### Best Practices Assessment

**Good Practices:**
- Proper exception handling around hotkey registration with user notification
- Cursor state cleanup in both ProcessExit and UnhandledException handlers
- Event handlers unsubscribed before hook disposal
- Settings saved on dialog close

**Minor Issues:**
| Location | Issue | Recommendation |
|----------|-------|----------------|
| `Settings.cs` | Boilerplate placeholder file | Could add documentation or custom logic if needed |

**Verdict**: Code follows good practices. Unused fields and references have been cleaned up.

### Modern Code Patterns Assessment

**Current State:**
The codebase uses .NET Framework 4.8 patterns, which is appropriate for the target framework. Some modernizations are possible but must be weighed against stability.

**Safe Modernizations (Low Risk):**
```csharp
// Current (Program.cs:39-40):
HotKeyManager.HotKeyPressed += _currentHotKeyHandler;
if (HotKeyManager.HotKeyPressed != null)
    HotKeyManager.HotKeyPressed(null, e);

// Could use null-conditional:
HotKeyManager.HotKeyPressed?.Invoke(null, e);
```

**Not Recommended:**
- Switching to .NET Core/5+ (would break AutoIt COM interop and require significant testing)
- Major refactoring (stability is the priority)

**Verdict**: Code is appropriately styled for its framework. Modernization should be minimal and conservative.

---

## Changelog

### v1.4.0 (December 2024)

**New Features:**
- **SendInput Unicode typing method** - Solves international keyboard issues (#3, #15, #29)
- **Single-file build** - All DLLs embedded via Costura.Fody
- **Dark/light mode support** - Settings dialog adapts to Windows theme
- **Dynamic tray icon** - Updates when Windows theme changes
- **Version label** - Displays in Settings dialog

**Improvements:**
- GitHub Actions CI/CD workflow
- Conditional code signing for CI builds
- Cleaned up unused framework references
- Fixed AutoIt reference path for portable builds

### v1.3.1 and earlier

See git history for previous changes.
