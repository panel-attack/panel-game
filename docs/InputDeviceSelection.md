# Input Device Selection

## Requirements
- Ensure character select automatically triggers the input device overlay whenever local human slots lack device assignments.
- The overlay does not dismiss until all local players have an input configuration assigned.
- You can't start the game until the overlay is dismissed.
- The overlay should supports all created input configurations plus touch.
- The overlay shows a box for each local player, online players box is not shown.
- Touch is assigned by tapping on the player box you want to use touch with.
- Each player box shows the player number
- When you touch or use a controller the device used shows in the box and becomes active.
- The overlay dismisses once every assignment is made.
- A"Change Input Device" button is on character select to allow you to reselect, triggering the overlay again with all local assignments reset.
- The change input device button shows all assignments in a compact form.
- Any input config should be able to navigate the menus outside of character select.
- When an input configuration is used that isn't assigned, release configs and bring up the overlay again
- When more than one input configuration of a device type are assigned, they should be numbered by order they are in the input configuration, so second keyboard configuration says "2"
- An attempt should be made to show an image close to the input method used. Touch, keyboard, controller shape

## Architecture

## Testing Plan
- Manual scenarios:
  - Keyboard only, controller only, mixed devices, touch selection via mouse.
  - Multiple controllers to confirm naming and unique assignments.
  - Works in endless, time attack, training, challenge mode, online, 2p vs
- Online/local modes to verify assignments persist and don’t conflict with server expectations.
- Run `love ./testLauncher.lua` post-implementation.
