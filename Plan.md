# Input Device Selection Overhaul Plan

## Goals
- Ensure Character Select automatically triggers the input device overlay whenever local human slots lack device assignments.
- Provide a reusable overlay that supports controller/keyboard/touch assignment with hold-to-confirm/cancel interactions routed through existing `inputManager` timers.
- Surface a temporary "Change Input Device" button that works with controller navigation and reflects current assignments.

## Architecture & Components
1. **BattleRoom helpers (`client/src/BattleRoom.lua`)**
   - Maintain caches for local human players and expose helpers:
     - `getLocalHumanPlayers()`, `areLocalPlayersAssigned()`.
     - `claimDeviceForPlayer(player, deviceRef)`, `clearPlayerAssignment(player)`, `releaseAllLocalAssignments()`.
   - Leverage `player:restrictInputs()/unrestrictInputs()`, always syncing `player:setInputMethod()` and clearing the new tracking table.
   - Remove legacy auto-assignment (`tryLockInputs`, `wantsReadyChanged` listener) so overlay controls device claiming exclusively.

2. **Device metadata utilities (`client/src/input/InputDeviceUtils.lua`)**
   - Generate ordered collections of assignable devices (each config + touch pseudo-device).
   - Derive stable IDs (configuration index or `"touch"`).
   - Compute display info:
     - `type = keyboard|controller|touch`.
     - `label` using `love.joystick.getJoysticks()[id]:getName()` and GUID index, keyboard → "Keyboard", mouse/touch → "Touch".
   - Provide formatting helpers for UI strings (per-player assignment lines).

3. **Input Device Overlay (`client/src/scenes/components/InputDeviceOverlay.lua`)**
   - **Visual Design (Updated)**:
     - Horizontal row of player slots (only show required number of players)
     - Use `client/assets/themes/Panel Attack Modern/p1@2x.png` and `p2@2x.png` for player numbers
     - Assert p3@2x.png and p4@2x.png exist for future 3-4 player support
     - Device type icons: controller icon for controllers, keyboard icon for keyboards, pointer icon for touch
     - Progressive visual feedback: device icons become more visible as hold threshold approaches
   - **Interaction Model (Updated)**:
     - Hold any device → assigns to next available player slot
     - Touch and hold specific player tile → assigns touch to that specific slot
     - Progressive fill effect shows hold progress
     - **No cancel support** (removed as specified)
     - Wait 1 second after all players assigned before auto-closing
   - **Component Architecture**:
     - Replace Grid with horizontal StackPanel for player slots
     - New PlayerSlot component with device icon, player number image, and progress feedback
     - Remove complex device descriptor grid
     - Use ImageContainer for player number graphics and device icons

4. **Scene integration (`client/src/scenes/CharacterSelect*.lua`)**
   - Instantiate overlay in `load()` and attach to `uiRoot`.
   - On scene activation/refresh:
     - If any required assignments missing, open overlay without clearing existing claims.
   - In `updateSelf`, pause core UI input while overlay is active; still update overlay each frame.
   - Listen for assignment changes to refresh per-player info boxes and change-input button text.

5. **“Change Input Device” button**
   - Add `createChangeInputDeviceButton()` in base CharacterSelect generating a `ui.TextButton` with:
     - Title "Change Input Device".
     - Body listing `Player {n}: <device label>` lines via utility helper.
   - Button press:
     - Calls `BattleRoom.releaseAllLocalAssignments()`.
     - Opens overlay in reset mode (all devices unassigned at start).
   - Place within the character select grid (left of the existing leave button) across all character select variants; ensure focus order works for controllers.

6. **Localization & UI polish**
   - Add new localization keys if needed.
   - Ensure overlay and button respect theme fonts/colors; hook up SFX for confirm/cancel.

7. **Testing plan**
   - Manual scenarios:
     - Keyboard only, controller only, mixed devices, touch selection via mouse.
     - Multiple controllers to confirm naming and unique assignments.
   - Online/local modes to verify assignments persist and don’t conflict with server expectations.
   - Run `love ./testLauncher.lua` post-implementation.

## Implementation Order
1. BattleRoom helper refactor.
2. Device utility module (consumed by both overlay and button).
3. Overlay component creation with hold detection.
4. Character select integration and overlay wiring.
5. Change-input button placement & grid adjustments.
6. Polish, localization, and validation tests.
