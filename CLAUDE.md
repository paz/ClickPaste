# CLAUDE.md - ClickPaste Development Guide

## Project Overview

**ClickPaste** is a Windows 10/11 notification area (system tray) utility that pastes clipboard contents as keyboard keystrokes to any window you click. This solves the problem of pasting to applications that block normal clipboard operations, including:
- Citrix/RDP remote sessions
- Virtual machines
- UAC-elevated applications (when run elevated)
- Legacy applications with restricted paste

**Current Version**: 1.3.1.0
**Status**: Stable, production-ready
**Framework**: .NET Framework 4.7, Windows Forms

## Core Philosophy

1. **Stability First**: The application is mature and stable. Changes should be conservative and thoroughly tested.
2. **Single Purpose**: Do one thing well - convert clipboard text to keystrokes.
3. **Minimal Footprint**: Tray-only application with no main window.
4. **User Control**: Configurable delays, hotkeys, and typing methods accommodate different environments.

## Build Commands

```bash
# Build (requires Visual Studio or MSBuild)
msbuild ClickPaste.sln /p:Configuration=Release

# The solution targets .NET Framework 4.7
# AutoIt DLLs are bundled and copied to output automatically
```

## Architecture

### File Structure
```
ClickPaste/
├── Program.cs           # Entry point, TrayApplicationContext (main logic)
├── HotKeyManager.cs     # Global hotkey registration via Win32 API
├── Native.cs            # P/Invoke declarations for Windows API
├── SettingsForm.cs      # Settings dialog UI and logic
├── SettingsForm.Designer.cs  # WinForms designer (auto-generated)
├── Properties/
│   ├── Settings.Designer.cs  # User settings (auto-generated)
│   └── Resources.Designer.cs # Embedded resources (auto-generated)
├── Resources/           # Icons (Target, TargetDark, Typing)
└── AutoItX3*.dll        # AutoIt3 typing engine (bundled)
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

Two methods available for simulating keystrokes:

| Method | Implementation | Best For |
|--------|---------------|----------|
| `Forms_SendKeys` | `System.Windows.Forms.SendKeys.SendWait()` | Simple cases, standard Windows apps |
| `AutoIt_Send` | AutoIt3 COM interop | Difficult applications, games, RDP |

**Default is AutoIt** (TypeMethod=1) as it's more reliable.

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
| TypeMethod | int | 1 | 0=Forms.SendKeys, 1=AutoIt |
| KeyDelayMS | int | 15 | Delay between keystrokes (ms) |
| StartDelayMS | int | 0 | Delay before typing starts (ms) |
| HotKey | string | "V" | Hotkey letter |
| HotKeyModifier | int | 3 | Modifier bitmask (1=Alt, 2=Ctrl, 4=Shift, 8=Win) |
| HotKeyMode | int | 0 | 0=Target selection, 1=JustGo (type immediately) |
| Confirm | bool | false | Show confirmation for large pastes |
| ConfirmOver | int | 100 | Character threshold for confirmation |

## Known Limitations

### Unicode & International Keyboards (Issues #3, #15, #29)

Both SendKeys and AutoIt work at the **virtual key/scancode level**, not character level. This causes problems with:

1. **AltGr-based characters** (e.g., `@`, `#` on Swiss/German layouts) - these require AltGr modifier which SendKeys doesn't handle
2. **Dead keys** (e.g., `" + a = ä` on international layouts) - quotes trigger diacritical composition
3. **Unicode characters** outside current keyboard layout (e.g., Lithuanian ų, ą, š)

**Root Cause**: The Windows SendKeys API and AutoIt.Send simulate key presses, not character insertion. Microsoft's documentation explicitly warns: *"If your application is intended for international use with a variety of keyboards, the use of Send could yield unpredictable results and should be avoided."*

**Potential Solutions** (for future exploration):
1. Use `SendInput` with `KEYEVENTF_UNICODE` flag for direct Unicode character injection
2. Temporarily switch keyboard layout to US English before typing
3. Hybrid approach: use Unicode injection for non-ASCII, SendKeys for ASCII

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
- [ ] Both typing methods work in Notepad
- [ ] Settings persist after restart
- [ ] Large paste confirmation works
- [ ] Dark/light theme icon selection works
- [ ] Single instance enforcement works

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| MouseKeyHook | 5.6.0 | Global keyboard/mouse hooks (NuGet) |
| AutoIt3 | Bundled | Alternative typing engine (COM) |
| .NET Framework | 4.7 | Runtime |

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
| `Program.cs:224` | CancellationTokenSource not disposed | Low - small object | Dispose previous before creating new |
| `Program.cs:84-85` | `_typeMethods` and `_keyDelayMS` declared but unused | None - dead code | Can be removed for cleanliness |

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

**App.config Cleanup (Optional):**
Lines 46-57 contain unused `<system.web>` membership/roleManager sections (Visual Studio template remnants). These are harmless but could be removed.

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
| `Settings.cs` | Empty placeholder file | Remove or add documentation |
| `Program.cs:84-85` | Unused fields `_typeMethods`, `_keyDelayMS` | Remove dead code |
| `ClickPaste.csproj:54` | Reference to `System.Web.Extensions` | Remove if not needed |

**Verdict**: Code follows good practices. Minor cleanup opportunities exist but don't affect functionality.

### Modern Code Patterns Assessment

**Current State:**
The codebase uses .NET Framework 4.7 patterns, which is appropriate for the target framework. Some modernizations are possible but must be weighed against stability.

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

## Unicode Solution Analysis

### The Problem

Issues #3, #15, and #29 all stem from the same root cause: `SendKeys` and `AutoIt.Send()` work at the **virtual key code level**, not the character level.

**How Current Typing Works:**
```
Character 'a' → VK_A key code → Target app receives keypress → Interprets as 'a'
Character 'ą' → ??? → No direct virtual key mapping → Character lost
```

**Failure Scenarios:**
1. **AltGr characters** (`@` on Swiss keyboard): Requires Ctrl+Alt+2, but SendKeys sends just the key
2. **Dead keys** (`"` on international): Sent as dead key, combines with next character
3. **Unicode** (Lithuanian `ą`): No virtual key exists, character dropped

### The Solution: SendInput with KEYEVENTF_UNICODE

Windows provides `SendInput` with the `KEYEVENTF_UNICODE` flag, which sends Unicode characters directly without keyboard layout translation:

```csharp
[DllImport("user32.dll", SetLastError = true)]
static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

[StructLayout(LayoutKind.Sequential)]
struct INPUT {
    public uint type;        // INPUT_KEYBOARD = 1
    public KEYBDINPUT ki;
}

[StructLayout(LayoutKind.Sequential)]
struct KEYBDINPUT {
    public ushort wVk;       // 0 for Unicode
    public ushort wScan;     // The Unicode character
    public uint dwFlags;     // KEYEVENTF_UNICODE (0x0004)
    public uint time;
    public IntPtr dwExtraInfo;
}
```

**How Unicode Input Works:**
```
Character 'ą' → Unicode 0x0105 → SendInput with KEYEVENTF_UNICODE → Target app receives 'ą'
```

### Implementation Strategy

**Recommended Approach: Add Third Typing Method**

1. Add new enum value: `TypeMethod.SendInput_Unicode`
2. Implement new case in `StartTyping()` using P/Invoke SendInput
3. Add radio button to settings form
4. Default to AutoIt for backward compatibility

**Advantages:**
- Does not modify existing typing methods (stability preserved)
- Users can choose which method works best for their environment
- Full Unicode support without keyboard layout dependencies

**Potential Risks:**
- Some applications may not accept SendInput Unicode (rare)
- RDP/Citrix may still block it (same as other methods)
- Requires testing across Windows versions

### Code Sketch

```csharp
// In Native.cs - add these P/Invoke declarations:

public const int INPUT_KEYBOARD = 1;
public const uint KEYEVENTF_UNICODE = 0x0004;
public const uint KEYEVENTF_KEYUP = 0x0002;

[StructLayout(LayoutKind.Sequential)]
public struct KEYBDINPUT {
    public ushort wVk;
    public ushort wScan;
    public uint dwFlags;
    public uint time;
    public IntPtr dwExtraInfo;
}

[StructLayout(LayoutKind.Sequential)]
public struct INPUT {
    public int type;
    public KEYBDINPUT ki;
}

[DllImport("user32.dll", SetLastError = true)]
public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

public static void SendUnicodeChar(char c) {
    INPUT[] inputs = new INPUT[2];

    // Key down
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = 0;
    inputs[0].ki.wScan = c;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;

    // Key up
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.wVk = 0;
    inputs[1].ki.wScan = c;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;

    SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
}
```

```csharp
// In Program.cs - add new case in StartTyping():

case TypeMethod.SendInput_Unicode:
    Native.SendUnicodeChar(s[0]);
    break;
```

### Recommended Next Steps

1. **Implement** the SendInput Unicode method as a third option
2. **Test** on various applications: Notepad, Word, RDP, Citrix
3. **Test** with various Unicode characters: Lithuanian, Chinese, emoji
4. **Test** on Windows 10 and Windows 11
5. **Document** which method works best for which scenarios
6. **Release** as version 1.4.0 with new typing method option

---

## Unused Code to Clean Up (Optional)

These items can be safely removed without affecting functionality:

1. `Settings.cs` - Empty placeholder file
2. `Program.cs:84` - `MenuItem[] _typeMethods` - declared but never used
3. `Program.cs:85` - `Dictionary<int, MenuItem> _keyDelayMS` - declared but never used
4. `App.config:46-57` - Unused `<system.web>` section
5. `ClickPaste.csproj:54` - Unused `System.Web.Extensions` reference

**Note**: These are cosmetic cleanups. The current code works correctly.
