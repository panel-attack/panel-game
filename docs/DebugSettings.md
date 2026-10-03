# Debug Settings System Documentation

## Overview
The Debug Settings system provides runtime-configurable debug features through a UI overlay. Settings are persisted to `config.debug` and can be accessed anywhere via the `DebugSettings` singleton.

## Architecture

### Components
- **DebugSettings** (`client/src/debug/DebugSettings.lua`) - Singleton managing all debug settings
- **OverlayContainer** (`client/src/ui/OverlayContainer.lua`) - Full-screen overlay UI for settings menu
- **Debug Button** (`client/src/Game.lua`) - Bottom-right button that opens the overlay (only visible when `DEBUG_ENABLED`)

## How Debug-Only Settings Work

Settings can be marked as `debugBuildOnly = true` to control their availability:

### Debug Builds (`DEBUG_ENABLED = true`)
- Setting appears in the UI overlay
- Can be toggled on/off by the user
- Value persists to config file
- Returns actual user-configured value

### Release Builds (`DEBUG_ENABLED = false`)
- Setting is hidden from the UI overlay
- Always returns the default value (typically `false`)
- Persisted value is ignored
- Cannot be changed at runtime

This is implemented through two mechanisms:

**1. UI Filtering** - `DebugSettings.getDefinitions()` filters out `debugBuildOnly` settings in release builds

**2. Value Locking** - `DebugSettings.get()` returns the default value for debug-only settings in release builds

## Adding New Debug Settings

### Step 1: Add Setting Definition

Add a new entry to the `settingDefinitions` table in `DebugSettings.lua`:

```lua
{
  key = "myNewSetting",
  type = "boolean",  -- or "number"
  default = false,
  label = "My New Feature",
  debugBuildOnly = true  -- false if should be available in release builds
}
```

For number settings, add `min` and `max`:
```lua
{
  key = "myNumberSetting",
  type = "number",
  default = 0,
  label = "My Number Setting",
  min = 0,
  max = 100,
  debugBuildOnly = true
}
```

### Step 2: Add Accessor Methods

Add getter and optional setter methods following the naming convention:

```lua
-- Getter
function DebugSettings.myNewSetting()
  return DebugSettings.get("myNewSetting") --[[@as boolean]]
end

-- Setter (if needed for programmatic access)
function DebugSettings.setMyNewSetting(value)
  DebugSettings.set("myNewSetting", value)
end
```

### Step 3: Use in Code

Replace existing debug checks with the new method:

```lua

if DebugSettings.myNewSetting() then
  -- debug behavior
end
```

## Setting Definition Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `key` | string | Yes | Unique key used in config.debug |
| `type` | "boolean" \| "number" | Yes | Data type of the setting |
| `default` | boolean \| number | Yes | Default value when not configured |
| `label` | string | Yes | Display label shown in UI overlay |
| `min` | number | No | Minimum value (number types only) |
| `max` | number | No | Maximum value (number types only) |
| `debugBuildOnly` | boolean | No | If true, only available in DEBUG_ENABLED builds (defaults to false) |

## Persistence

Settings are automatically saved to `config.debug` in the user's config file:

```lua
config.debug = {
  showStackDebugInfo = false,
  showUIElementBorders = true,
  vsFramesBehind = 0,
  -- ... other settings
}
```

- Settings load on startup via `DebugSettings.init()`
- Settings save immediately when changed via `DebugSettings.set()`
