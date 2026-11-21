---@meta

---Version: 12.0
---
---[Open in Browser](https://love2d.org/wiki/love)
---
---@class love
love = {}

---Called when the active audio playback device is disconnected (e.g. physically unplugging headphones). All audio is stopped and loses its playback position when this callback is called.
---
---If the callback returns a falsy value or isn't defined, love.audio.setPlaybackDevice() is called to switch to the system's default device.
---
---[Open in Browser](https://love2d.org/wiki/love.audiodisconnected)
---
---@param sources (love.audio.Source)[] List of sources that were playing.
---@return boolean handled True to skip switching to the default playback device, for example because the callback already chose a device.
love.audiodisconnected = function(sources)
end

---If a file called conf.lua is present in your game folder (or .love file), it is run before the LÖVE modules are loaded. You can use this file to overwrite the love.conf function, which is later called by the LÖVE 'boot' script. Using the love.conf function, you can set some configuration options, and change things like the default size of the window, which modules are loaded, and other stuff.
---
---[Open in Browser](https://love2d.org/wiki/love.conf)
---
---@param t {title: (string)?, identity: (string)?, appendidentity: (boolean)?, version: (string)?, console: (boolean)?, externalstorage: (boolean)?, highdpi: (boolean)?, trackpadtouch: (boolean)?, gammacorrect: (boolean)?, renderers: ((love.graphics.Renderer)[])?, excluderenderers: ((love.graphics.Renderer)[])?, audio: {mic: (boolean)?, mixwithsystem: (boolean)?}, graphics: {excluderenderers: ((love.graphics.Renderer)[])?, gammacorrect: (boolean)?, lowpower: (boolean)?, renderers: ((love.graphics.Renderer)[])?}, window: {title: (string)?, icon: (string)?, width: (number)?, height: (number)?, borderless: (boolean)?, resizable: (boolean)?, centered: (boolean)?, minwidth: (number)?, minheight: (number)?, fullscreen: (boolean)?, fullscreentype: (love.window.FullscreenType)?, usedpiscale: (boolean)?, vsync: (number|boolean)?, depth: (boolean)?, stencil: (boolean)?, msaa: (number)?, displayindex: (number)?, x: (number)?, y: (number)?, display: (number)?, highdpi: (boolean)?}, modules: {audio: (boolean)?, data: (boolean)?, event: (boolean)?, font: (boolean)?, graphics: (boolean)?, image: (boolean)?, joystick: (boolean)?, keyboard: (boolean)?, math: (boolean)?, mouse: (boolean)?, physics: (boolean)?, sensor: (boolean)?, sound: (boolean)?, system: (boolean)?, thread: (boolean)?, timer: (boolean)?, touch: (boolean)?, video: (boolean)?, window: (boolean)?}} The love.conf function takes one argument: a table filled with all the default values which you can overwrite to your liking. If you want to change the default window size, for instance, do:
love.conf = function(t)
end

---Callback function triggered when a directory is dragged and dropped onto the window.
---
---Paths passed into this callback are able to be used with love.filesystem.mount, which is the only way to get read access via love.filesystem to the dropped directory. love.filesystem.mount does not generally accept other full platform-dependent directory paths that haven't been dragged and dropped onto the window.
---
---[Open in Browser](https://love2d.org/wiki/love.directorydropped)
---
---@param path string The full platform-dependent path to the directory. It can be used as an argument to love.filesystem.mount, in order to gain read access to the directory with love.filesystem.
---@param x number The x-coordinate of the drop position in the window, in the same units as mouse positions.
---@param y number The y-coordinate of the drop position in the window, in the same units as mouse positions.
love.directorydropped = function(path, x, y)
end

---Called when the device display orientation changed, for example, user rotated their phone 180 degrees.
---
---[Open in Browser](https://love2d.org/wiki/love.displayrotated)
---
---@param index number The index of the display that changed orientation.
---@param orientation love.window.DisplayOrientation The new orientation.
love.displayrotated = function(index, orientation)
end

---Callback function used to draw on the screen every frame.
---
---[Open in Browser](https://love2d.org/wiki/love.draw)
---
love.draw = function()
end

---Called when a new drag and drop onto the window begins.
---
---[Open in Browser](https://love2d.org/wiki/love.dropbegan)
---
love.dropbegan = function()
end

---Called when a drag and drop onto the window has finished.
---
---[Open in Browser](https://love2d.org/wiki/love.dropcompleted)
---
---@param x number The x-coordinate of the drop position in the window, in the same units as mouse positions.
---@param y number The y-coordinate of the drop position in the window, in the same units as mouse positions.
love.dropcompleted = function(x, y)
end

---Called when something being dragged moves over the window.
---
---[Open in Browser](https://love2d.org/wiki/love.dropmoved)
---
---@param x number The x-coordinate of the drop position in the window, in the same units as mouse positions.
---@param y number The y-coordinate of the drop position in the window, in the same units as mouse positions.
love.dropmoved = function(x, y)
end

---Legacy name of love.errorhandler. LÖVE uses love.errhand only if love.errorhandler is nil; since LÖVE defines a default love.errorhandler, defining love.errhand alone has no effect unless love.errorhandler is set to nil.
---
---[Open in Browser](https://love2d.org/wiki/love.errhand)
---
---@param msg string The error message.
---@return fun():(any) mainLoop Function which handles one frame, including events and rendering, when called. If this is nil then LÖVE exits immediately.
love.errhand = function(msg)
end

---The error handler, used to display error messages. It is called with the error when love.load, love.run or the main loop raise an error.
---
---[Open in Browser](https://love2d.org/wiki/love.errorhandler)
---
---@param msg string The error message.
---@return fun():(any) mainLoop Function which handles one frame, including events and rendering, when called. If this is nil then LÖVE exits immediately.
love.errorhandler = function(msg)
end

---Called when the window has been exposed and should be redrawn, for example after being uncovered.
---
---[Open in Browser](https://love2d.org/wiki/love.exposed)
---
love.exposed = function()
end

---Callback function triggered when a file is dragged and dropped onto the window.
---
---The dropped file's path can also be mounted with love.filesystem.mount, for example to read a dropped zip file.
---
---[Open in Browser](https://love2d.org/wiki/love.filedropped)
---
---@param file love.filesystem.File The unopened File object representing the file that was dropped.
---@param x number The x-coordinate of the drop position in the window, in the same units as mouse positions.
---@param y number The y-coordinate of the drop position in the window, in the same units as mouse positions.
love.filedropped = function(file, x, y)
end

---Callback function triggered when window receives or loses focus.
---
---[Open in Browser](https://love2d.org/wiki/love.focus)
---
---@param focus boolean True if the window gains focus, false if it loses focus. 
love.focus = function(focus)
end

---Called when a Joystick's virtual gamepad axis is moved.
---
---[Open in Browser](https://love2d.org/wiki/love.gamepadaxis)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param axis love.joystick.GamepadAxis The virtual gamepad axis.
---@param value number The new axis value.
love.gamepadaxis = function(joystick, axis, value)
end

---Called when a Joystick's virtual gamepad button is pressed.
---
---[Open in Browser](https://love2d.org/wiki/love.gamepadpressed)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param button love.joystick.GamepadButton The virtual gamepad button.
love.gamepadpressed = function(joystick, button)
end

---Called when a Joystick's virtual gamepad button is released.
---
---[Open in Browser](https://love2d.org/wiki/love.gamepadreleased)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param button love.joystick.GamepadButton The virtual gamepad button.
love.gamepadreleased = function(joystick, button)
end

---Called when a Joystick is connected.
---
---This callback is also triggered after love.load for every Joystick which was already connected when the game started up.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickadded)
---
---@param joystick love.joystick.Joystick The newly connected Joystick object.
love.joystickadded = function(joystick)
end

---Called when a joystick axis moves.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickaxis)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param axis number The axis number.
---@param value number The new axis value.
love.joystickaxis = function(joystick, axis, value)
end

---Called when a joystick hat direction changes.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickhat)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param hat number The hat number.
---@param direction love.joystick.JoystickHat The new hat direction.
love.joystickhat = function(joystick, hat, direction)
end

---Called when a joystick button is pressed.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickpressed)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param button number The button number.
love.joystickpressed = function(joystick, button)
end

---Called when a joystick button is released.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickreleased)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param button number The button number.
love.joystickreleased = function(joystick, button)
end

---Called when a Joystick is disconnected.
---
---[Open in Browser](https://love2d.org/wiki/love.joystickremoved)
---
---@param joystick love.joystick.Joystick The now-disconnected Joystick object.
love.joystickremoved = function(joystick)
end

---Called when a Joystick's sensor is updated with new values.
---Only Joystick sensors enabled with Joystick:setSensorEnabled will trigger this event.
---
---[Open in Browser](https://love2d.org/wiki/love.joysticksensorupdated)
---
---@param joystick love.joystick.Joystick The joystick object.
---@param sensorType love.sensor.SensorType The type of sensor.
---@param x number The new sensor 1st value.
---@param y number The new sensor 2nd value.
---@param z number The new sensor 3rd value.
love.joysticksensorupdated = function(joystick, sensorType, x, y, z)
end

---Callback function triggered when a key is pressed.
---
---Scancodes are keyboard layout-independent, so the scancode 'w' will be generated if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---Key repeat needs to be enabled with love.keyboard.setKeyRepeat for repeat keypress events to be received. This does not affect love.textinput.
---
---[Open in Browser](https://love2d.org/wiki/love.keypressed)
---
---@param key love.keyboard.KeyConstant Character of the pressed key.
---@param scancode love.keyboard.Scancode The scancode representing the pressed key.
---@param isrepeat boolean Whether this keypress event is a repeat. The delay between key repeats depends on the user's system settings.
love.keypressed = function(key, scancode, isrepeat)
end

---Callback function triggered when a keyboard key is released.
---
---Scancodes are keyboard layout-independent, so the scancode 'w' will be used if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---[Open in Browser](https://love2d.org/wiki/love.keyreleased)
---
---@param key love.keyboard.KeyConstant Character of the released key.
---@param scancode love.keyboard.Scancode The scancode representing the released key.
love.keyreleased = function(key, scancode)
end

---This function is called exactly once at the beginning of the game.
---
---The default love.run passes love.parsedGameArguments and love.rawGameArguments.
---
---[Open in Browser](https://love2d.org/wiki/love.load)
---
---@param arg table Command-line arguments given to the game, without the command-line options LÖVE itself handles (love.parsedGameArguments).
---@param unfilteredArg table Unfiltered command-line arguments given to the executable (love.rawGameArguments).
love.load = function(arg, unfilteredArg)
end

---Callback function triggered when the user's system locale preferences have changed.
---
---[Open in Browser](https://love2d.org/wiki/love.localechanged)
---
love.localechanged = function()
end

---Callback function triggered when the system is running out of memory on mobile devices.
---
---Mobile operating systems may forcefully kill the game if it uses too much memory, so any non-critical resource should be removed if possible (by setting all variables referencing the resources to '''nil'''), when this event is triggered. Sounds and images in particular tend to use the most memory.
---
---[Open in Browser](https://love2d.org/wiki/love.lowmemory)
---
love.lowmemory = function()
end

---Callback function triggered when window receives or loses mouse focus.
---
---[Open in Browser](https://love2d.org/wiki/love.mousefocus)
---
---@param focus boolean Whether the window has mouse focus or not.
love.mousefocus = function(focus)
end

---Callback function triggered when the mouse is moved.
---
---If Relative Mode is enabled for the mouse, the '''dx''' and '''dy''' arguments of this callback will update but '''x''' and '''y''' are not guaranteed to.
---
---[Open in Browser](https://love2d.org/wiki/love.mousemoved)
---
---@param x number The mouse position on the x-axis.
---@param y number The mouse position on the y-axis.
---@param dx number The amount moved along the x-axis since the last time love.mousemoved was called.
---@param dy number The amount moved along the y-axis since the last time love.mousemoved was called.
---@param istouch boolean True if the mouse button press originated from a touchscreen touch-press.
love.mousemoved = function(x, y, dx, dy, istouch)
end

---Callback function triggered when a mouse button is pressed.
---
---Use love.wheelmoved to detect mouse wheel motion. It will not register as a button press in version 0.10.0 and newer.
---
---[Open in Browser](https://love2d.org/wiki/love.mousepressed)
---
---@param x number Mouse x position, in the same units as love.mouse.getPosition.
---@param y number Mouse y position, in the same units as love.mouse.getPosition.
---@param button number The button index that was pressed. 1 is the primary mouse button, 2 is the secondary mouse button and 3 is the middle button. Further buttons are mouse dependent.
---@param istouch boolean True if the mouse button press originated from a touchscreen touch-press.
---@param presses number The number of presses in a short time frame and small area, used to simulate double, triple clicks
love.mousepressed = function(x, y, button, istouch, presses)
end

---Callback function triggered when a mouse button is released.
---
---[Open in Browser](https://love2d.org/wiki/love.mousereleased)
---
---@param x number Mouse x position, in the same units as love.mouse.getPosition.
---@param y number Mouse y position, in the same units as love.mouse.getPosition.
---@param button number The button index that was released. 1 is the primary mouse button, 2 is the secondary mouse button and 3 is the middle button. Further buttons are mouse dependent.
---@param istouch boolean True if the mouse button release originated from a touchscreen touch-release.
---@param presses number The number of presses in a short time frame and small area, used to simulate double, triple clicks
love.mousereleased = function(x, y, button, istouch, presses)
end

---Called when the window becomes fully covered by other windows. love.window.isOccluded tells whether it still is.
---
---[Open in Browser](https://love2d.org/wiki/love.occluded)
---
love.occluded = function()
end

---Callback function triggered when the game is closed.
---
---[Open in Browser](https://love2d.org/wiki/love.quit)
---
---@return boolean r Abort quitting. If true, do not close the game.
love.quit = function()
end

---Called when the window is resized, for example if the user resizes the window, or if love.window.setMode is called with an unsupported width or height in fullscreen and the window chooses the closest appropriate size.
---
---Calls to love.window.setMode will '''only''' trigger this event if the width or height of the window after the call doesn't match the requested width and height. This can happen if a fullscreen mode is requested which doesn't match any supported mode, or if the fullscreen type is 'desktop' and the requested width or height don't match the desktop resolution.
---
---Since 11.0, this function returns width and height in DPI-scaled units rather than pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.resize)
---
---@param w number The new width.
---@param h number The new height.
love.resize = function(w, h)
end

---The main function, containing the main loop. A sensible default is used when left out.
---
---[Open in Browser](https://love2d.org/wiki/love.run)
---
---@return fun():(any) mainLoop Function which handlers one frame, including events and rendering when called.
love.run = function()
end

---Called when the in-device sensor is updated with new values.
---Only sensors enabled with love.sensor.setEnabled will trigger this event.
---
---[Open in Browser](https://love2d.org/wiki/love.sensorupdated)
---
---@param sensorType love.sensor.SensorType The type of sensor.
---@param x number The new sensor 1st value.
---@param y number The new sensor 2nd value.
---@param z number The new sensor 3rd value.
love.sensorupdated = function(sensorType, x, y, z)
end

---Called when the candidate text for an IME (Input Method Editor) has changed.
---
---The candidate text is not the final text that the user will eventually choose. Use love.textinput for that.
---
---[Open in Browser](https://love2d.org/wiki/love.textedited)
---
---@param text string The UTF-8 encoded unicode candidate text.
---@param start number The start cursor of the selected candidate text.
---@param length number The length of the selected candidate text. May be 0.
love.textedited = function(text, start, length)
end

---Called when text has been entered by the user. For example if shift-2 is pressed on an American keyboard layout, the text '@' will be generated.
---
---Although Lua strings can store UTF-8 encoded unicode text just fine, many functions in Lua's string library will not treat the text as you might expect. For example, #text (and string.len(text)) will give the number of ''bytes'' in the string, rather than the number of unicode characters. The Lua wiki and a presentation by one of Lua's creators give more in-depth explanations, with some tips.
---
---The utf8 library can be used to operate on UTF-8 encoded unicode text (such as the text argument given in this function.)
---
---On Android and iOS, textinput is disabled by default; call love.keyboard.setTextInput to enable it.
---
---[Open in Browser](https://love2d.org/wiki/love.textinput)
---
---@param text string The UTF-8 encoded unicode text.
love.textinput = function(text)
end

---Called when the operating system switches between a light and a dark theme. love.window.getSystemTheme gets the new theme.
---
---[Open in Browser](https://love2d.org/wiki/love.themechanged)
---
love.themechanged = function()
end

---Callback function triggered when a Thread encounters an error.
---
---[Open in Browser](https://love2d.org/wiki/love.threaderror)
---
---@param thread love.thread.Thread The thread which produced the error.
---@param errorstr string The error message.
love.threaderror = function(thread, errorstr)
end

---Callback function triggered when a touch press moves on a touch screen or touchpad.
---
---The identifier is only guaranteed to be unique for the specific touch press until love.touchreleased is called with that identifier, at which point it may be reused for new touch presses.
---
---Positions and movements are inside the window, in the same units as mouse positions, for a touch screen, and normalized to the range [0, 1] for a touchpad.
---
---[Open in Browser](https://love2d.org/wiki/love.touchmoved)
---
---@param id lightuserdata The identifier for the touch press.
---@param x number The x-axis position of the touch.
---@param y number The y-axis position of the touch.
---@param dx number The x-axis movement of the touch.
---@param dy number The y-axis movement of the touch.
---@param pressure number The amount of pressure being applied. Most touch screens aren't pressure sensitive, in which case the pressure will be 1.
---@param devicetype love.touch.TouchDeviceType The kind of device the touch comes from.
---@param mouse boolean True if the touch was generated from a mouse rather than a touch device.
love.touchmoved = function(id, x, y, dx, dy, pressure, devicetype, mouse)
end

---Callback function triggered when a touch screen or touchpad is touched.
---
---The identifier is only guaranteed to be unique for the specific touch press until love.touchreleased is called with that identifier, at which point it may be reused for new touch presses.
---
---Positions and movements are inside the window, in the same units as mouse positions, for a touch screen, and normalized to the range [0, 1] for a touchpad.
---
---[Open in Browser](https://love2d.org/wiki/love.touchpressed)
---
---@param id lightuserdata The identifier for the touch press.
---@param x number The x-axis position of the touch.
---@param y number The y-axis position of the touch.
---@param dx number The x-axis movement of the touch.
---@param dy number The y-axis movement of the touch.
---@param pressure number The amount of pressure being applied. Most touch screens aren't pressure sensitive, in which case the pressure will be 1.
---@param devicetype love.touch.TouchDeviceType The kind of device the touch comes from.
---@param mouse boolean True if the touch was generated from a mouse rather than a touch device.
love.touchpressed = function(id, x, y, dx, dy, pressure, devicetype, mouse)
end

---Callback function triggered when a touch screen or touchpad stops being touched, or the touch is canceled.
---
---The identifier is only guaranteed to be unique for the specific touch press until love.touchreleased is called with that identifier, at which point it may be reused for new touch presses.
---
---Positions and movements are inside the window, in the same units as mouse positions, for a touch screen, and normalized to the range [0, 1] for a touchpad.
---
---[Open in Browser](https://love2d.org/wiki/love.touchreleased)
---
---@param id lightuserdata The identifier for the touch press.
---@param x number The x-axis position of the touch.
---@param y number The y-axis position of the touch.
---@param dx number The x-axis movement of the touch.
---@param dy number The y-axis movement of the touch.
---@param pressure number The amount of pressure being applied. Most touch screens aren't pressure sensitive, in which case the pressure will be 1.
---@param devicetype love.touch.TouchDeviceType The kind of device the touch comes from.
---@param mouse boolean True if the touch was generated from a mouse rather than a touch device.
love.touchreleased = function(id, x, y, dx, dy, pressure, devicetype, mouse)
end

---Callback function used to update the state of the game every frame.
---
---[Open in Browser](https://love2d.org/wiki/love.update)
---
---@param dt number Time since the last update in seconds.
love.update = function(dt)
end

---Callback function triggered when window is minimized/hidden or unminimized by the user.
---
---[Open in Browser](https://love2d.org/wiki/love.visible)
---
---@param visible boolean True if the window is visible, false if it isn't.
love.visible = function(visible)
end

---Callback function triggered when the mouse wheel is moved.
---
---[Open in Browser](https://love2d.org/wiki/love.wheelmoved)
---
---@param x number Amount of horizontal mouse wheel movement. Positive values indicate movement to the right.
---@param y number Amount of vertical mouse wheel movement. Positive values indicate upward movement.
---@param dir string "flipped" if the system reports flipped (natural) scrolling, "standard" otherwise.
love.wheelmoved = function(x, y, dir)
end

---Kinds of API that love.markDeprecated can mark.
---
---[Open in Browser](https://love2d.org/wiki/APIType)
---
---@alias love.APIType
---A function. The warning reads "Using deprecated function <name>".
---| "function"
---A variant of a function. The warning reads "Using deprecated function variant in <name>".
---| "functionvariant"
---A method. The warning reads "Using deprecated method <name>".
---| "method"
---A variant of a method. The warning reads "Using deprecated method variant in <name>".
---| "methodvariant"
---A callback. The warning reads "Using deprecated callback <name>".
---| "callback"
---A field, such as a love.conf option. The warning reads "Using deprecated field <name>".
---| "field"
---An enum constant. The warning reads "Using deprecated constant <name>".
---| "constant"
---Anything else. The warning reads "Using deprecated <name>".
---| "custom"

---How deprecated functionality was deprecated, as given to love.markDeprecated.
---
---[Open in Browser](https://love2d.org/wiki/DeprecationType)
---
---@alias love.DeprecationType
---Deprecated with nothing replacing it.
---| "noreplacement"
---Replaced by other functionality. The warning adds "(replaced by <replacement>)".
---| "replaced"
---Renamed. The warning adds "(renamed to <replacement>)".
---| "renamed"

---The superclass of all data.
---
---[Open in Browser](https://love2d.org/wiki/Data)
---
---@class love.Data: love.Object
local Data = {}

---Reads 64-bit floating point numbers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getDouble)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getDouble(offset, count)
end

---Gets an FFI pointer to the Data.
---
---This function should be preferred instead of Data:getPointer because the latter uses light userdata which can't store all possible memory addresses on some new ARM64 architectures, when LuaJIT is used.
---
---[Open in Browser](https://love2d.org/wiki/Data:getFFIPointer)
---
---@return ffi.cdata*|nil pointer A raw void* pointer to the Data, or nil if FFI is unavailable.
function Data:getFFIPointer()
end

---Reads 32-bit floating point numbers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getFloat)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getFloat(offset, count)
end

---Reads signed 16-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getInt16)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getInt16(offset, count)
end

---Reads signed 32-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getInt32)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getInt32(offset, count)
end

---Reads signed 8-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getInt8)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getInt8(offset, count)
end

---Gets a pointer to the Data. Can be used with libraries such as LuaJIT's FFI.
---
---[Open in Browser](https://love2d.org/wiki/Data:getPointer)
---
---@return lightuserdata pointer A raw pointer to the Data.
function Data:getPointer()
end

---Gets the Data's size in bytes.
---
---[Open in Browser](https://love2d.org/wiki/Data:getSize)
---
---@return number size The size of the Data in bytes.
function Data:getSize()
end

---Gets the Data, or a part of it, as a string. Raises an error if the part doesn't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getString)
---
---@param offset (number)? The offset in bytes from the start of the Data.
---@param size (number)? The number of bytes to get. Must be greater than 0.
---@return string data The raw data.
function Data:getString(offset, size)
end

---Reads unsigned 16-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getUInt16)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getUInt16(offset, count)
end

---Reads unsigned 32-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getUInt32)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getUInt32(offset, count)
end

---Reads unsigned 8-bit integers from the Data, in the native byte order, starting at a byte offset. Raises an error if the values don't fit within the Data.
---
---[Open in Browser](https://love2d.org/wiki/Data:getUInt8)
---
---@param offset number The offset in bytes from the start of the Data to read from.
---@param count (number)? How many values to read. Must be greater than 0.
---@return number ... The values read, one per count.
function Data:getUInt8(offset, count)
end

---Calls a function while holding the Data's lock, so other threads that lock the same Data (for example with performAtomic) wait until it returns. Errors raised by the function are passed on.
---
---[Open in Browser](https://love2d.org/wiki/Data:performAtomic)
---
---@param func function The function to call.
---@param ... any Arguments to pass to the function.
---@return any ... The values the function returns.
function Data:performAtomic(func, ...)
end

---The superclass of all LÖVE types.
---
---[Open in Browser](https://love2d.org/wiki/Object)
---
---@class love.Object
local Object = {}

---Destroys the object's Lua reference. The object will be completely deleted if it's not referenced by any other LÖVE object or thread.
---
---This method can be used to immediately clean up resources without waiting for Lua's garbage collector.
---
---[Open in Browser](https://love2d.org/wiki/Object:release)
---
---@return boolean success True if the object was released by this call, false if it had been previously released.
function Object:release()
end

---Gets the type of the object as a string.
---
---[Open in Browser](https://love2d.org/wiki/Object:type)
---
---@return string type The type as a string.
function Object:type()
end

---Checks whether an object is of a certain type. If the object has the type with the specified name in its hierarchy, this function will return true.
---
---[Open in Browser](https://love2d.org/wiki/Object:typeOf)
---
---@param name string The name of the type to check for.
---@return boolean b True if the object is of the specified type, false otherwise.
function Object:typeOf(name)
end

---The superclass of readable or writable byte streams, such as File and DataStream. It has no methods of its own in Lua.
---
---[Open in Browser](https://love2d.org/wiki/Stream)
---
---@class love.Stream: love.Object
local Stream = {}

---Gets the current running version of LÖVE.
---
---[Open in Browser](https://love2d.org/wiki/love.getVersion)
---
---@return number major The major version of LÖVE, i.e. 12 for version 12.0.
---@return number minor The minor version of LÖVE, i.e. 0 for version 12.0.
---@return number revision The revision version of LÖVE, i.e. 0 for version 12.0.0.
---@return string codename The codename of the current version, i.e. 'Bestest Friend' for version 12.0.
function love.getVersion()
end

---Gets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise.
---
---When deprecation output is enabled, the first use of a formally deprecated LÖVE API prints a warning to the console.
---
---[Open in Browser](https://love2d.org/wiki/love.hasDeprecationOutput)
---
---@return boolean enabled Whether deprecation output is enabled.
function love.hasDeprecationOutput()
end

---Gets whether the given version is compatible with the current running version of LÖVE.
---
---[Open in Browser](https://love2d.org/wiki/love.isVersionCompatible)
---
---@param version string The version to check (for example '11.3' or '0.10.2'). A version without a revision is treated as revision 0.
---@return boolean compatible Whether the given version is compatible with the current running version of LÖVE.
function love.isVersionCompatible(version)
end

---Gets whether the given version is compatible with the current running version of LÖVE.
---
---[Open in Browser](https://love2d.org/wiki/love.isVersionCompatible)
---
---@param major number The major version to check (for example 11 for 11.3 or 0 for 0.10.2).
---@param minor number The minor version to check (for example 3 for 11.3 or 10 for 0.10.2).
---@param revision (number)? The revision of version to check (for example 0 for 11.3 or 2 for 0.10.2).
---@return boolean compatible Whether the given version is compatible with the current running version of LÖVE.
function love.isVersionCompatible(major, minor, revision)
end

---Records a use of deprecated functionality. The first use of each name prints a warning to the console when deprecation output is enabled (see love.setDeprecationOutput).
---
---[Open in Browser](https://love2d.org/wiki/love.markDeprecated)
---
---@param level number The stack level to report as the place the deprecated functionality was used, as with the level argument of error. 1 is the function that calls love.markDeprecated.
---@param name string The name of the deprecated functionality. Uses are counted per name.
---@param apiname love.APIType The kind of API that is deprecated.
---@param deprecationtype love.DeprecationType How the functionality was deprecated.
---@param replacement (string)? What replaces the deprecated functionality. Required unless deprecationtype is 'noreplacement', in which case it is ignored.
function love.markDeprecated(level, name, apiname, deprecationtype, replacement)
end

---Sets whether LÖVE displays warnings when using deprecated functionality. It is disabled by default in fused mode, and enabled by default otherwise.
---
---When deprecation output is enabled, the first use of a formally deprecated LÖVE API prints a warning to the console. Enabling it also prints a warning for each deprecated API that was already used once.
---
---[Open in Browser](https://love2d.org/wiki/love.setDeprecationOutput)
---
---@param enable boolean Whether to enable or disable deprecation output.
function love.setDeprecationOutput(enable)
end

---Provides an interface to create noise with the user's speakers.
---
---[Open in Browser](https://love2d.org/wiki/love.audio)
---
---@class love.audio
love.audio = {}

---The different distance models.
---
---Extended information can be found in the chapter "3.4. Attenuation By Distance" of the OpenAL 1.1 specification.
---
---[Open in Browser](https://love2d.org/wiki/DistanceModel)
---
---@alias love.audio.DistanceModel
---Sources do not get attenuated.
---| "none"
---Inverse distance attenuation.
---| "inverse"
---Inverse distance attenuation. Gain is clamped.
---| "inverseclamped"
---Linear attenuation.
---| "linear"
---Linear attenuation. Gain is clamped.
---| "linearclamped"
---Exponential attenuation.
---| "exponent"
---Exponential attenuation. Gain is clamped.
---| "exponentclamped"
---@alias love.DistanceModel love.audio.DistanceModel

---The different types of effects supported by love.audio.setEffect.
---
---[Open in Browser](https://love2d.org/wiki/EffectType)
---
---@alias love.audio.EffectType
---Plays multiple copies of the sound with slight pitch and time variation. Used to make sounds sound "fuller" or "thicker".
---| "chorus"
---Decreases the dynamic range of the sound, making the loud and quiet parts closer in volume, producing a more uniform amplitude throughout time.
---| "compressor"
---Alters the sound by amplifying it until it clips, shearing off parts of the signal, leading to a compressed and distorted sound.
---| "distortion"
---Decaying feedback based effect, on the order of seconds. Also known as delay; causes the sound to repeat at regular intervals at a decreasing volume.
---| "echo"
---Adjust the frequency components of the sound using a 4-band (low-shelf, two band-pass and a high-shelf) equalizer.
---| "equalizer"
---Plays two copies of the sound; while varying the phase, or equivalently delaying one of them, by amounts on the order of milliseconds, resulting in phasing sounds.
---| "flanger"
---Decaying feedback based effect, on the order of milliseconds. Used to simulate the reflection off of the surroundings.
---| "reverb"
---An implementation of amplitude modulation; multiplies the source signal with a simple waveform, to produce either volume changes, or inharmonic overtones.
---| "ringmodulator"
---@alias love.EffectType love.audio.EffectType

---The different types of waveforms that can be used for the waveform setting of the chorus, flanger and ringmodulator EffectTypes.
---
---[Open in Browser](https://love2d.org/wiki/EffectWaveform)
---
---@alias love.audio.EffectWaveform
---A sawtooth wave, also known as a ramp wave. Named for its linear rise, and (near-)instantaneous fall along time.
---| "sawtooth"
---A sine wave. Follows a trigonometric sine function.
---| "sine"
---A square wave. Switches between high and low states (near-)instantaneously.
---| "square"
---A triangle wave. Follows a linear rise and fall that repeats periodically.
---| "triangle"
---@alias love.EffectWaveform love.audio.EffectWaveform

---Types of filters for Sources.
---
---[Open in Browser](https://love2d.org/wiki/FilterType)
---
---@alias love.audio.FilterType
---Low-pass filter. High frequency sounds are attenuated.
---| "lowpass"
---High-pass filter. Low frequency sounds are attenuated.
---| "highpass"
---Band-pass filter. Both high and low frequency sounds are attenuated based on the given parameters.
---| "bandpass"
---@alias love.FilterType love.audio.FilterType

---Types of audio sources.
---
---A good rule of thumb is to use stream for music files and static for all short sound effects. Basically, you want to avoid loading large files into memory at once.
---
---[Open in Browser](https://love2d.org/wiki/SourceType)
---
---@alias love.audio.SourceType
---The whole audio is decoded.
---| "static"
---The audio is decoded in chunks when needed.
---| "stream"
---The audio must be manually queued by the user.
---| "queue"
---@alias love.SourceType love.audio.SourceType

---Where a streaming Decoder or Source reads its encoded data from.
---
---[Open in Browser](https://love2d.org/wiki/StreamType)
---
---@alias love.audio.StreamType
---The encoded data is read from the file as it is decoded.
---| "file"
---The whole encoded file is read into memory first, and decoded from there.
---| "memory"
---@alias love.StreamType love.audio.StreamType

---Units that represent time.
---
---[Open in Browser](https://love2d.org/wiki/TimeUnit)
---
---@alias love.audio.TimeUnit
---Regular seconds.
---| "seconds"
---Audio samples.
---| "samples"
---@alias love.TimeUnit love.audio.TimeUnit

---Represents an audio input device capable of recording sounds.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice)
---
---@class love.audio.RecordingDevice: love.Object
local RecordingDevice = {}
---@alias love.RecordingDevice love.audio.RecordingDevice

---Gets the number of bits per sample in the data currently being recorded.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getBitDepth)
---
---@return number bits The number of bits per sample in the data that's currently being recorded.
function RecordingDevice:getBitDepth()
end

---Gets the number of channels currently being recorded (mono or stereo).
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getChannelCount)
---
---@return number channels The number of channels being recorded (1 for mono, 2 for stereo).
function RecordingDevice:getChannelCount()
end

---Gets all recorded audio SoundData stored in the device's internal ring buffer.
---
---The internal ring buffer is cleared when this function is called, so calling it again will only get audio recorded after the previous call. If the device's internal ring buffer completely fills up before getData is called, the oldest data that doesn't fit into the buffer will be lost.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getData)
---
---@return love.sound.SoundData data The recorded audio data, or nil if the device isn't recording.
function RecordingDevice:getData()
end

---Gets the name of the recording device.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getName)
---
---@return string name The name of the device.
function RecordingDevice:getName()
end

---Gets the number of currently recorded samples.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getSampleCount)
---
---@return number samples The number of samples that have been recorded so far.
function RecordingDevice:getSampleCount()
end

---Gets the number of samples per second currently being recorded.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:getSampleRate)
---
---@return number rate The number of samples being recorded per second (sample rate).
function RecordingDevice:getSampleRate()
end

---Gets whether the device is currently recording.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:isRecording)
---
---@return boolean recording True if the recording, false otherwise.
function RecordingDevice:isRecording()
end

---Begins recording audio using this device.
---
---Records with the sample count, sample rate, bit depth and channel count this device currently has (initially 8192 samples, 8000 Hz, 16 bits, 1 channel).
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:start)
---
---@return boolean success True if the device successfully began recording, false if not.
function RecordingDevice:start()
end

---Begins recording audio using this device.
---
---A ring buffer is used internally to store recorded data before RecordingDevice:getData or RecordingDevice:stop are called – the former clears the buffer. If the buffer completely fills up before getData or stop are called, the oldest data that doesn't fit into the buffer will be lost.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:start)
---
---@param samplecount number The maximum number of samples to store in an internal ring buffer when recording. RecordingDevice:getData clears the internal buffer when called.
---@param samplerate (number)? The number of samples per second to store when recording.
---@param bitdepth (number)? The number of bits per sample.
---@param channels (number)? Whether to record in mono or stereo. Most microphones don't support more than 1 channel.
---@return boolean success True if the device successfully began recording using the specified parameters, false if not.
function RecordingDevice:start(samplecount, samplerate, bitdepth, channels)
end

---Stops recording audio from this device. Any sound data currently in the device's buffer will be returned.
---
---[Open in Browser](https://love2d.org/wiki/RecordingDevice:stop)
---
---@return love.sound.SoundData data The sound data currently in the device's buffer, or nil if the device wasn't recording.
function RecordingDevice:stop()
end

---A Source represents audio you can play back.
---
---You can do interesting things with Sources, like set the volume, pitch, and its position relative to the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources.
---
---[Open in Browser](https://love2d.org/wiki/Source)
---
---@class love.audio.Source: love.Object
local Source = {}
---@alias love.Source love.audio.Source

---Creates an identical copy of the Source in the stopped state.
---
---Static Sources will use significantly less memory and take much less time to be created if Source:clone is used to create them instead of love.audio.newSource, so this method should be preferred when making multiple Sources which play the same sound.
---
---Cloned Sources inherit all the set-able state of the original Source, but they are initialized stopped.
---
---[Open in Browser](https://love2d.org/wiki/Source:clone)
---
---@return love.audio.Source source The new identical copy of this Source.
function Source:clone()
end

---Gets a list of the Source's active effect names.
---
---[Open in Browser](https://love2d.org/wiki/Source:getActiveEffects)
---
---@return (string)[] effects A list of the source's active effect names.
function Source:getActiveEffects()
end

---Gets the amount of air absorption applied to the Source.
---
---By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the Source at a rate of 0.05 dB per meter.
---
---Audio air absorption functionality is not supported on iOS.
---
---[Open in Browser](https://love2d.org/wiki/Source:getAirAbsorption)
---
---@return number amount The amount of air absorption applied to the Source.
function Source:getAirAbsorption()
end

---Gets the reference and maximum attenuation distances of the Source. The values, combined with the current DistanceModel, affect how the Source's volume attenuates based on distance from the listener.
---
---[Open in Browser](https://love2d.org/wiki/Source:getAttenuationDistances)
---
---@return number ref The current reference attenuation distance. If the current DistanceModel is clamped, this is the minimum distance before the Source is no longer attenuated.
---@return number max The current maximum attenuation distance.
function Source:getAttenuationDistances()
end

---Gets the number of channels in the Source. Only 1-channel (mono) Sources can use directional and positional effects.
---
---[Open in Browser](https://love2d.org/wiki/Source:getChannelCount)
---
---@return number channels 1 for mono, 2 for stereo.
function Source:getChannelCount()
end

---Gets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.
---
---[Open in Browser](https://love2d.org/wiki/Source:getCone)
---
---@return number innerAngle The inner angle from the Source's direction, in radians. The Source will play at normal volume if the listener is inside the cone defined by this angle.
---@return number outerAngle The outer angle from the Source's direction, in radians. The Source will play at a volume between the normal and outer volumes, if the listener is in between the cones defined by the inner and outer angles.
---@return number outerVolume The Source's volume when the listener is outside both the inner and outer cone angles.
---@return number outerHighGain The gain applied to high frequencies when the listener is outside both the inner and outer cone angles.
function Source:getCone()
end

---Gets the direction of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getDirection)
---
---@return number x The X part of the direction vector.
---@return number y The Y part of the direction vector.
---@return number z The Z part of the direction vector.
function Source:getDirection()
end

---Gets the duration of the Source. For streaming Sources it may not always be sample-accurate, and may return -1 if the duration cannot be determined at all.
---
---[Open in Browser](https://love2d.org/wiki/Source:getDuration)
---
---@param unit (love.audio.TimeUnit)? The time unit for the return value.
---@return number duration The duration of the Source, or -1 if it cannot be determined.
function Source:getDuration(unit)
end

---Gets whether an effect is applied to this Source, and the filter settings associated with it.
---
---[Open in Browser](https://love2d.org/wiki/Source:getEffect)
---
---@param name string The name of the effect.
---@param filtersettings (table)? An optional table that will be filled with the filter settings and returned, instead of a new table.
---@return boolean enabled Whether the effect is applied to this Source.
---@return {type: love.audio.FilterType, volume: number, highgain: number, lowgain: number} filtersettings The settings for the filter associated with this effect, or nil if the effect is not applied or has no filter. The table has the following fields:
function Source:getEffect(name, filtersettings)
end

---Gets the filter settings currently applied to the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getFilter)
---
---@param settings (table)? An optional table that will be filled with the filter settings and returned, instead of a new table.
---@return {type: love.audio.FilterType, volume: number, highgain: number, lowgain: number} settings The filter settings to use for this Source, or nil if the Source has no active filter. The table has the following fields:
function Source:getFilter(settings)
end

---Gets the number of free buffer slots in a queueable Source. If the queueable Source is playing, this value will increase up to the amount the Source was created with. If the queueable Source is stopped, it will process all of its internal buffers first, in which case this function will always return the amount it was created with.
---
---[Open in Browser](https://love2d.org/wiki/Source:getFreeBufferCount)
---
---@return number buffers How many more SoundData objects can be queued up.
function Source:getFreeBufferCount()
end

---Gets the current pitch of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getPitch)
---
---@return number pitch The pitch, where 1.0 is normal.
function Source:getPitch()
end

---Gets the position of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getPosition)
---
---@return number x The X position of the Source.
---@return number y The Y position of the Source.
---@return number z The Z position of the Source.
function Source:getPosition()
end

---Returns the rolloff factor of the source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getRolloff)
---
---@return number rolloff The rolloff factor.
function Source:getRolloff()
end

---Gets the type of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getType)
---
---@return love.audio.SourceType sourcetype The type of the source.
function Source:getType()
end

---Gets the velocity of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getVelocity)
---
---@return number x The X part of the velocity vector.
---@return number y The Y part of the velocity vector.
---@return number z The Z part of the velocity vector.
function Source:getVelocity()
end

---Gets the current volume of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getVolume)
---
---@return number volume The volume of the Source, where 1.0 is normal volume.
function Source:getVolume()
end

---Returns the volume limits of the source.
---
---[Open in Browser](https://love2d.org/wiki/Source:getVolumeLimits)
---
---@return number min The minimum volume.
---@return number max The maximum volume.
function Source:getVolumeLimits()
end

---Returns whether the Source will loop.
---
---[Open in Browser](https://love2d.org/wiki/Source:isLooping)
---
---@return boolean loop True if the Source will loop, false otherwise.
function Source:isLooping()
end

---Returns whether the Source is playing.
---
---[Open in Browser](https://love2d.org/wiki/Source:isPlaying)
---
---@return boolean playing True if the Source is playing, false otherwise.
function Source:isPlaying()
end

---Gets whether the Source's position, velocity, direction, and cone angles are relative to the listener.
---
---[Open in Browser](https://love2d.org/wiki/Source:isRelative)
---
---@return boolean relative True if the position, velocity, direction and cone angles are relative to the listener, false if they're absolute.
function Source:isRelative()
end

---Pauses the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:pause)
---
function Source:pause()
end

---Starts playing the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:play)
---
---@return boolean success Whether the Source was able to successfully start playing.
function Source:play()
end

---Queues SoundData or raw sample data for playback in a queueable Source.
---
---This method requires the Source to be created via love.audio.newQueueableSource.
---
---[Open in Browser](https://love2d.org/wiki/Source:queue)
---
---@param sounddata love.sound.SoundData The data to queue. The SoundData's sample rate, bit depth, and channel count must match the Source's.
---@return boolean success True if the data was successfully queued for playback, false if there were no available buffers to use for queueing.
function Source:queue(sounddata)
end

---Queues SoundData or raw sample data for playback in a queueable Source.
---
---This method requires the Source to be created via love.audio.newQueueableSource.
---
---Queues the first length bytes of the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/Source:queue)
---
---@param sounddata love.sound.SoundData The data to queue. The SoundData's sample rate, bit depth, and channel count must match the Source's.
---@param length number The number of bytes of the SoundData to queue.
---@return boolean success True if the data was successfully queued for playback, false if there were no available buffers to use for queueing.
function Source:queue(sounddata, length)
end

---Queues SoundData or raw sample data for playback in a queueable Source.
---
---This method requires the Source to be created via love.audio.newQueueableSource.
---
---Queues a byte range of the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/Source:queue)
---
---@param sounddata love.sound.SoundData The data to queue. The SoundData's sample rate, bit depth, and channel count must match the Source's.
---@param offset number The byte offset into the SoundData where the queued data starts.
---@param length number The number of bytes to queue.
---@return boolean success True if the data was successfully queued for playback, false if there were no available buffers to use for queueing.
function Source:queue(sounddata, offset, length)
end

---Queues SoundData or raw sample data for playback in a queueable Source.
---
---This method requires the Source to be created via love.audio.newQueueableSource.
---
---Queues raw sample data from memory, such as a pointer from Data:getFFIPointer.
---
---[Open in Browser](https://love2d.org/wiki/Source:queue)
---
---@param data lightuserdata A pointer to the sample data.
---@param offset number The byte offset from the pointer where the queued data starts.
---@param length number The number of bytes to queue.
---@param samplerate number The sample rate of the data. Must match the Source's.
---@param bitdepth number The bit depth of the data. Must match the Source's.
---@param channels number The channel count of the data. Must match the Source's.
---@return boolean success True if the data was successfully queued for playback, false if there were no available buffers to use for queueing.
function Source:queue(data, offset, length, samplerate, bitdepth, channels)
end

---Sets the currently playing position of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:seek)
---
---@param offset number The position to seek to.
---@param unit (love.audio.TimeUnit)? The unit of the position value.
function Source:seek(offset, unit)
end

---Sets the amount of air absorption applied to the Source.
---
---By default the value is set to 0 which means that air absorption effects are disabled. A value of 1 will apply high frequency attenuation to the Source at a rate of 0.05 dB per meter.
---
---Air absorption can simulate sound transmission through foggy air, dry air, smoky atmosphere, etc. It can be used to simulate different atmospheric conditions within different locations in an area.
---
---Audio air absorption functionality is not supported on iOS.
---
---[Open in Browser](https://love2d.org/wiki/Source:setAirAbsorption)
---
---@param amount number The amount of air absorption applied to the Source. Must be between 0 and 10.
function Source:setAirAbsorption(amount)
end

---Sets the reference and maximum attenuation distances of the Source. The parameters, combined with the current DistanceModel, affect how the Source's volume attenuates based on distance.
---
---Distance attenuation is only applicable to Sources based on mono (rather than stereo) audio.
---
---[Open in Browser](https://love2d.org/wiki/Source:setAttenuationDistances)
---
---@param ref number The new reference attenuation distance. If the current DistanceModel is clamped, this is the minimum attenuation distance.
---@param max number The new maximum attenuation distance.
function Source:setAttenuationDistances(ref, max)
end

---Sets the Source's directional volume cones. Together with Source:setDirection, the cone angles allow for the Source's volume to vary depending on its direction.
---
---[Open in Browser](https://love2d.org/wiki/Source:setCone)
---
---@param innerAngle number The inner angle from the Source's direction, in radians. The Source will play at normal volume if the listener is inside the cone defined by this angle.
---@param outerAngle number The outer angle from the Source's direction, in radians. The Source will play at a volume between the normal and outer volumes, if the listener is in between the cones defined by the inner and outer angles.
---@param outerVolume (number)? The Source's volume when the listener is outside both the inner and outer cone angles.
---@param outerHighGain (number)? The gain applied to high frequencies when the listener is outside both the inner and outer cone angles.
function Source:setCone(innerAngle, outerAngle, outerVolume, outerHighGain)
end

---Sets the direction vector of the Source. A zero vector makes the source non-directional.
---
---[Open in Browser](https://love2d.org/wiki/Source:setDirection)
---
---@param x number The X part of the direction vector.
---@param y number The Y part of the direction vector.
---@param z (number)? The Z part of the direction vector.
function Source:setDirection(x, y, z)
end

---Applies an audio effect to the Source.
---
---The effect must have been previously defined using love.audio.setEffect.
---
---Applies the given previously defined effect to this Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:setEffect)
---
---@param name string The name of the effect previously set up with love.audio.setEffect.
---@param enable (boolean)? If false and the given effect name was previously enabled on this Source, disables the effect.
---@return boolean success Whether the effect was successfully applied to this Source.
function Source:setEffect(name, enable)
end

---Applies an audio effect to the Source.
---
---The effect must have been previously defined using love.audio.setEffect.
---
---Applies the given previously defined effect to this Source, and applies a filter to the Source which affects the sound fed into the effect.
---
---Audio effect functionality is not supported on iOS.
---
---[Open in Browser](https://love2d.org/wiki/Source:setEffect)
---
---@param name string The name of the effect previously set up with love.audio.setEffect.
---@param filtersettings {type: love.audio.FilterType, volume: number, highgain: number, lowgain: number} The filter settings to apply prior to the effect, with the following fields:
---@return boolean success Whether the effect and filter were successfully applied to this Source.
function Source:setEffect(name, filtersettings)
end

---Sets a low-pass, high-pass, or band-pass filter to apply when playing the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:setFilter)
---
---@param settings {type: love.audio.FilterType, volume: number, highgain: number, lowgain: number} The filter settings to use for this Source, with the following fields:
---@return boolean success Whether the filter was successfully applied to the Source.
function Source:setFilter(settings)
end

---Sets a low-pass, high-pass, or band-pass filter to apply when playing the Source.
---
---Disables filtering on this Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:setFilter)
---
---@return boolean success Whether the filter was successfully removed from the Source.
function Source:setFilter()
end

---Sets whether the Source should loop.
---
---[Open in Browser](https://love2d.org/wiki/Source:setLooping)
---
---@param loop boolean True if the source should loop, false otherwise.
function Source:setLooping(loop)
end

---Sets the pitch of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:setPitch)
---
---@param pitch number Calculated with regard to 1 being the base pitch. Each reduction by 50 percent equals a pitch shift of -12 semitones (one octave reduction). Each doubling equals a pitch shift of 12 semitones (one octave increase). Zero is not a legal value.
function Source:setPitch(pitch)
end

---Sets the position of the Source. Please note that this only works for mono (i.e. non-stereo) sound files!
---
---[Open in Browser](https://love2d.org/wiki/Source:setPosition)
---
---@param x number The X position of the Source.
---@param y number The Y position of the Source.
---@param z (number)? The Z position of the Source.
function Source:setPosition(x, y, z)
end

---Sets whether the Source's position, velocity, direction, and cone angles are relative to the listener, or absolute.
---
---By default, all sources are absolute and therefore relative to the origin of love's coordinate system 0, 0. Only absolute sources are affected by the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources. 
---
---[Open in Browser](https://love2d.org/wiki/Source:setRelative)
---
---@param enable boolean True to make the position, velocity, direction and cone angles relative to the listener, false to make them absolute.
function Source:setRelative(enable)
end

---Sets the rolloff factor which affects the strength of the used distance attenuation.
---
---Extended information and detailed formulas can be found in the chapter '3.4. Attenuation By Distance' of OpenAL 1.1 specification.
---
---[Open in Browser](https://love2d.org/wiki/Source:setRolloff)
---
---@param rolloff number The new rolloff factor.
function Source:setRolloff(rolloff)
end

---Sets the velocity of the Source.
---
---This does '''not''' change the position of the Source, but lets the application know how it has to calculate the doppler effect.
---
---[Open in Browser](https://love2d.org/wiki/Source:setVelocity)
---
---@param x number The X part of the velocity vector.
---@param y number The Y part of the velocity vector.
---@param z (number)? The Z part of the velocity vector.
function Source:setVelocity(x, y, z)
end

---Sets the current volume of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:setVolume)
---
---@param volume number The volume for a Source, where 1.0 is normal volume. Volume cannot be raised above 1.0.
function Source:setVolume(volume)
end

---Sets the volume limits of the source. The limits have to be numbers from 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/Source:setVolumeLimits)
---
---@param min number The minimum volume.
---@param max number The maximum volume.
function Source:setVolumeLimits(min, max)
end

---Stops a Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:stop)
---
function Source:stop()
end

---Gets the currently playing position of the Source.
---
---[Open in Browser](https://love2d.org/wiki/Source:tell)
---
---@param unit (love.audio.TimeUnit)? The type of unit for the return value.
---@return number position The currently playing position of the Source.
function Source:tell(unit)
end

---Gets a list of the names of the currently enabled effects.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getActiveEffects)
---
---@return (string)[] effects The list of the names of the currently enabled effects.
function love.audio.getActiveEffects()
end

---Gets the current number of simultaneously playing sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getActiveSourceCount)
---
---@return number count The current number of simultaneously playing sources.
function love.audio.getActiveSourceCount()
end

---Returns the distance attenuation model.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getDistanceModel)
---
---@return love.audio.DistanceModel model The current distance model. The default is 'inverseclamped'.
function love.audio.getDistanceModel()
end

---Gets the current global scale factor for velocity-based doppler effects.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getDopplerScale)
---
---@return number scale The current doppler scale factor.
function love.audio.getDopplerScale()
end

---Gets the settings associated with an effect.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getEffect)
---
---@param name string The name of the effect.
---@param settings (table)? An optional table that will be filled with the settings and returned, instead of a new table.
---@return table settings The settings associated with the effect, or nil if no effect with that name is set. It has a type field (EffectType), a volume field, and the type-specific parameters as given to love.audio.setEffect.
function love.audio.getEffect(name, settings)
end

---Gets the maximum number of active effects supported by the system.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getMaxSceneEffects)
---
---@return number maximum The maximum number of active effects.
function love.audio.getMaxSceneEffects()
end

---Gets the maximum number of active Effects in a single Source object, that the system can support.
---
---This function return 0 for system that doesn't support audio effects.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getMaxSourceEffects)
---
---@return number maximum The maximum number of active Effects per Source.
function love.audio.getMaxSourceEffects()
end

---Returns the orientation of the listener.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getOrientation)
---
---@return number fx Forward x of the listener orientation.
---@return number fy Forward y of the listener orientation.
---@return number fz Forward z of the listener orientation.
---@return number ux Up x of the listener orientation.
---@return number uy Up y of the listener orientation.
---@return number uz Up z of the listener orientation.
function love.audio.getOrientation()
end

---Gets whether the audio output is spatialized (such as with HRTF), and the name of the spatialization filter in use.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getOutputSpatialization)
---
---@return boolean enabled Whether output spatialization is enabled.
---@return string filter The name of the spatialization filter in use, or nil if there is none.
function love.audio.getOutputSpatialization()
end

---Gets the names of the output spatialization filters (such as HRTF profiles) the audio device supports.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getOutputSpatializationFilters)
---
---@return (string)[] filters The list of filter names, which can be given to love.audio.setOutputSpatialization.
function love.audio.getOutputSpatializationFilters()
end

---Gets the currently active playback device.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getPlaybackDevice)
---
---@return string device The name of the current playback device.
function love.audio.getPlaybackDevice()
end

---Gets a list of playback devices on the system.
---The first device in the list is the user's default playback device.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getPlaybackDevices)
---
---@return (string)[] devices The list of connected playback device names as strings.
function love.audio.getPlaybackDevices()
end

---Returns the position of the listener. Please note that positional audio only works for mono (i.e. non-stereo) sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getPosition)
---
---@return number x The X position of the listener.
---@return number y The Y position of the listener.
---@return number z The Z position of the listener.
function love.audio.getPosition()
end

---Gets a list of RecordingDevices on the system.
---
---The first device in the list is the user's default recording device. The list may be empty if there are no microphones connected to the system.
---
---Audio recording is currently not supported on iOS.
---
---Audio recording for Android is supported since 11.3. However, it's not supported when APK from Play Store is used.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getRecordingDevices)
---
---@return (love.audio.RecordingDevice)[] devices The list of connected recording devices.
function love.audio.getRecordingDevices()
end

---Returns the velocity of the listener.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getVelocity)
---
---@return number x The X velocity of the listener.
---@return number y The Y velocity of the listener.
---@return number z The Z velocity of the listener.
function love.audio.getVelocity()
end

---Returns the master volume.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.getVolume)
---
---@return number volume The current master volume
function love.audio.getVolume()
end

---Gets whether audio effects are supported in the system.
---
---Older Linux distributions that ship with older OpenAL library may not support audio effects. Furthermore, iOS doesn't
---
---support audio effects at all.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.isEffectsSupported)
---
---@return boolean supported True if effects are supported, false otherwise.
function love.audio.isEffectsSupported()
end

---Creates a new Source usable for real-time generated sound playback with Source:queue.
---
---The sample rate, bit depth, and channel count of any SoundData used with Source:queue must match the parameters given to this constructor.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newQueueableSource)
---
---@param samplerate number Number of samples per second when playing.
---@param bitdepth number Bits per sample (8 or 16).
---@param channels number 1 for mono or 2 for stereo.
---@param buffercount (number)? The number of buffers that can be queued up at any given time with Source:queue. Cannot be greater than 64. A sensible default (~8) is chosen if no value is specified.
---@return love.audio.Source source The new Source usable with Source:queue.
function love.audio.newQueueableSource(samplerate, bitdepth, channels, buffercount)
end

---Creates a new Source from a filepath, File, Data, Decoder or SoundData.
---
---Sources created from SoundData are always static, and Sources created from a Decoder are always streaming.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newSource)
---
---@param filename string The filepath to the audio file.
---@param type love.audio.SourceType Streaming or static source. 'queue' is not allowed; use love.audio.newQueueableSource.
---@param streamtype (love.audio.StreamType)? For streaming Sources, whether to stream from the file or load the encoded file into memory first and stream from there. Ignored for static Sources.
---@return love.audio.Source source A new Source that can play the specified audio.
function love.audio.newSource(filename, type, streamtype)
end

---Creates a new Source from a filepath, File, Data, Decoder or SoundData.
---
---Sources created from SoundData are always static, and Sources created from a Decoder are always streaming.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newSource)
---
---@param file love.filesystem.File A File pointing to an audio file.
---@param type love.audio.SourceType Streaming or static source. 'queue' is not allowed; use love.audio.newQueueableSource.
---@param streamtype (love.audio.StreamType)? For streaming Sources, whether to stream from the file or load the encoded file into memory first and stream from there. Ignored for static Sources.
---@return love.audio.Source source A new Source that can play the specified audio.
function love.audio.newSource(file, type, streamtype)
end

---Creates a new Source from a filepath, File, Data, Decoder or SoundData.
---
---Sources created from SoundData are always static, and Sources created from a Decoder are always streaming.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newSource)
---
---@param data love.Data A Data object (such as FileData) containing the encoded audio file.
---@param type love.audio.SourceType Streaming or static source. 'queue' is not allowed; use love.audio.newQueueableSource.
---@return love.audio.Source source A new Source that can play the specified audio.
function love.audio.newSource(data, type)
end

---Creates a new Source from a filepath, File, Data, Decoder or SoundData.
---
---Sources created from SoundData are always static, and Sources created from a Decoder are always streaming.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newSource)
---
---@param decoder love.sound.Decoder The Decoder to create a streaming Source from.
---@return love.audio.Source source A new Source that can play the specified audio.
function love.audio.newSource(decoder)
end

---Creates a new Source from a filepath, File, Data, Decoder or SoundData.
---
---Sources created from SoundData are always static, and Sources created from a Decoder are always streaming.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.newSource)
---
---@param data love.sound.SoundData The SoundData to create a Source from.
---@return love.audio.Source source A new Source that can play the specified audio. The SourceType of the returned audio is 'static'.
function love.audio.newSource(data)
end

---Pauses specific or all currently played Sources.
---
---Pauses all currently active Sources and returns them.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.pause)
---
---@return (love.audio.Source)[] Sources A table containing a list of Sources that were paused by this call.
function love.audio.pause()
end

---Pauses specific or all currently played Sources.
---
---Pauses the given Sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.pause)
---
---@param source love.audio.Source The first Source to pause.
---@param ... love.audio.Source Additional Sources to pause.
function love.audio.pause(source, ...)
end

---Pauses specific or all currently played Sources.
---
---Pauses the given Sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.pause)
---
---@param sources (love.audio.Source)[] A table containing a list of Sources to pause.
function love.audio.pause(sources)
end

---Plays the specified Source.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.play)
---
---@param source love.audio.Source The Source to play.
---@return boolean success Whether the Sources were able to successfully start playing.
function love.audio.play(source)
end

---Plays the specified Source.
---
---Starts playing multiple Sources simultaneously.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.play)
---
---@param sources (love.audio.Source)[] Table containing a list of Sources to play.
---@return boolean success Whether the Sources were able to successfully start playing.
function love.audio.play(sources)
end

---Plays the specified Source.
---
---Starts playing multiple Sources simultaneously.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.play)
---
---@param source1 love.audio.Source The first Source to play.
---@param source2 love.audio.Source The second Source to play.
---@param ... love.audio.Source Additional Sources to play.
---@return boolean success Whether the Sources were able to successfully start playing.
function love.audio.play(source1, source2, ...)
end

---Sets the distance attenuation model.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setDistanceModel)
---
---@param model love.audio.DistanceModel The new distance model.
function love.audio.setDistanceModel(model)
end

---Sets a global scale factor for velocity-based doppler effects. The default scale value is 1.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setDopplerScale)
---
---@param scale number The new doppler scale factor. The scale must be greater than 0.
function love.audio.setDopplerScale(scale)
end

---Defines an effect that can be applied to a Source.
---
---Not all system supports audio effects. Use love.audio.isEffectsSupported to check.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setEffect)
---
---@param name string The name of the effect.
---@param settings {type: love.audio.EffectType, volume: number, [string]: number|boolean|love.audio.EffectWaveform} The settings to use for this effect, with the following fields:
---@return boolean success Whether the effect was successfully created.
function love.audio.setEffect(name, settings)
end

---Defines an effect that can be applied to a Source.
---
---Not all system supports audio effects. Use love.audio.isEffectsSupported to check.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setEffect)
---
---@param name string The name of the effect.
---@param enabled (boolean)? Must be false or omitted: removes the effect with this name. Passing true is an error.
---@return boolean success Whether the effect was successfully disabled.
function love.audio.setEffect(name, enabled)
end

---Sets whether the system should mix the audio with the system's audio.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setMixWithSystem)
---
---@param mix boolean True to enable mixing, false to disable it.
---@return boolean success True if the change succeeded, false otherwise.
function love.audio.setMixWithSystem(mix)
end

---Sets the orientation of the listener.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setOrientation)
---
---@param fx number Forward x of the listener orientation.
---@param fy number Forward y of the listener orientation.
---@param fz number Forward z of the listener orientation.
---@param ux number Up x of the listener orientation.
---@param uy number Up y of the listener orientation.
---@param uz number Up z of the listener orientation.
function love.audio.setOrientation(fx, fy, fz, ux, uy, uz)
end

---Enables or disables spatialization (such as HRTF) of the audio output, optionally choosing a filter from love.audio.getOutputSpatializationFilters.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setOutputSpatialization)
---
---@param enable boolean Whether to enable output spatialization.
---@param filter (string)? The name of the spatialization filter to use, or nil to let the system choose.
---@return boolean success Whether the setting was applied.
function love.audio.setOutputSpatialization(enable, filter)
end

---Change the audio device to specified device. Also used to reconnect audio device in case of device disconnection.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setPlaybackDevice)
---
---@param name (string)? Fully qualified device name, or nil to use system default.
---@return boolean success Whether the playback device was changed.
---@return string message The error message, only returned on failure.
function love.audio.setPlaybackDevice(name)
end

---Sets the position of the listener, which determines how sounds play.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setPosition)
---
---@param x number The x position of the listener.
---@param y number The y position of the listener.
---@param z (number)? The z position of the listener.
function love.audio.setPosition(x, y, z)
end

---Sets the velocity of the listener.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setVelocity)
---
---@param x number The X velocity of the listener.
---@param y number The Y velocity of the listener.
---@param z (number)? The Z velocity of the listener.
function love.audio.setVelocity(x, y, z)
end

---Sets the master volume.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.setVolume)
---
---@param volume number 1.0 is max and 0.0 is off.
function love.audio.setVolume(volume)
end

---Stops currently played sources.
---
---This function will stop all currently active sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.stop)
---
function love.audio.stop()
end

---Stops currently played sources.
---
---This function will only stop the specified source.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.stop)
---
---@param source love.audio.Source The source on which to stop the playback.
function love.audio.stop(source)
end

---Stops currently played sources.
---
---Simultaneously stops all given Sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.stop)
---
---@param source1 love.audio.Source The first Source to stop.
---@param source2 love.audio.Source The second Source to stop.
---@param ... love.audio.Source Additional Sources to stop.
function love.audio.stop(source1, source2, ...)
end

---Stops currently played sources.
---
---Simultaneously stops all given Sources.
---
---[Open in Browser](https://love2d.org/wiki/love.audio.stop)
---
---@param sources (love.audio.Source)[] A table containing a list of Sources to stop.
function love.audio.stop(sources)
end

---Provides functionality for creating and transforming data.
---
---[Open in Browser](https://love2d.org/wiki/love.data)
---
---@class love.data
love.data = {}

---Compressed data formats.
---
---[Open in Browser](https://love2d.org/wiki/CompressedDataFormat)
---
---@alias love.data.CompressedDataFormat
---The LZ4 compression format. Compresses and decompresses very quickly, but the compression ratio is not the best. LZ4-HC is used when compression level 9 is specified. Some benchmarks are available here.
---| "lz4"
---The zlib format is DEFLATE-compressed data with a small bit of header data. Compresses relatively slowly and decompresses moderately quickly, and has a decent compression ratio.
---| "zlib"
---The gzip format is DEFLATE-compressed data with a slightly larger header than zlib. Since it uses DEFLATE it has the same compression characteristics as the zlib format.
---| "gzip"
---Raw DEFLATE-compressed data (no header).
---| "deflate"
---@alias love.CompressedDataFormat love.data.CompressedDataFormat

---Return type of various data-returning functions.
---
---[Open in Browser](https://love2d.org/wiki/ContainerType)
---
---@alias love.data.ContainerType
---Return type is ByteData.
---| "data"
---Return type is string.
---| "string"
---@alias love.ContainerType love.data.ContainerType

---Encoding format used to encode or decode data.
---
---[Open in Browser](https://love2d.org/wiki/EncodeFormat)
---
---@alias love.data.EncodeFormat
---Encode/decode data as base64 binary-to-text encoding.
---| "base64"
---Encode/decode data as hexadecimal string.
---| "hex"
---@alias love.EncodeFormat love.data.EncodeFormat

---Hash algorithm of love.data.hash.
---
---[Open in Browser](https://love2d.org/wiki/HashFunction)
---
---@alias love.data.HashFunction
---MD5 hash algorithm (16 bytes).
---| "md5"
---SHA1 hash algorithm (20 bytes).
---| "sha1"
---SHA2 hash algorithm with message digest size of 224 bits (28 bytes).
---| "sha224"
---SHA2 hash algorithm with message digest size of 256 bits (32 bytes).
---| "sha256"
---SHA2 hash algorithm with message digest size of 384 bits (48 bytes).
---| "sha384"
---SHA2 hash algorithm with message digest size of 512 bits (64 bytes).
---| "sha512"
---@alias love.HashFunction love.data.HashFunction

---Data object containing arbitrary bytes in an contiguous memory.
---
---[Open in Browser](https://love2d.org/wiki/ByteData)
---
---@class love.data.ByteData: love.Data, love.Object
local ByteData = {}
---@alias love.ByteData love.data.ByteData

---Creates a new copy of the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:clone)
---
---@return love.data.ByteData clone The new copy.
function ByteData:clone()
end

---Writes one or more 64-bit floating point numbers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setDouble)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setDouble(offset, ...)
end

---Writes one or more 64-bit floating point numbers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setDouble)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setDouble(offset, values)
end

---Writes one or more 32-bit floating point numbers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setFloat)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setFloat(offset, ...)
end

---Writes one or more 32-bit floating point numbers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setFloat)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setFloat(offset, values)
end

---Writes one or more signed 16-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt16)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setInt16(offset, ...)
end

---Writes one or more signed 16-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt16)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setInt16(offset, values)
end

---Writes one or more signed 32-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt32)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setInt32(offset, ...)
end

---Writes one or more signed 32-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt32)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setInt32(offset, values)
end

---Writes one or more signed 8-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt8)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setInt8(offset, ...)
end

---Writes one or more signed 8-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setInt8)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setInt8(offset, values)
end

---Replaces all or part of the ByteData's memory with the contents of a string. A string longer than the ByteData is cut to the ByteData's size.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setString)
---
---@param data string The bytes to copy to the Data object.
---@param offset (number)? An optional byte offset into the Data's memory to copy to.
function ByteData:setString(data, offset)
end

---Writes one or more unsigned 16-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt16)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setUInt16(offset, ...)
end

---Writes one or more unsigned 16-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt16)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setUInt16(offset, values)
end

---Writes one or more unsigned 32-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt32)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setUInt32(offset, ...)
end

---Writes one or more unsigned 32-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt32)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setUInt32(offset, values)
end

---Writes one or more unsigned 8-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt8)
---
---@param offset number The byte offset to write the first value at.
---@param ... number The values to write.
function ByteData:setUInt8(offset, ...)
end

---Writes one or more unsigned 8-bit integers into the ByteData's memory, one after another, starting at the given byte offset. Errors if the values do not fit within the ByteData.
---
---[Open in Browser](https://love2d.org/wiki/ByteData:setUInt8)
---
---@param offset number The byte offset to write the first value at.
---@param values (number)[] An array of the values to write.
function ByteData:setUInt8(offset, values)
end

---Represents byte data compressed using a specific algorithm.
---
---love.data.decompress can be used to de-compress the data.
---
---[Open in Browser](https://love2d.org/wiki/CompressedData)
---
---@class love.data.CompressedData: love.Data, love.Object
local CompressedData = {}
---@alias love.CompressedData love.data.CompressedData

---Creates a new copy of the CompressedData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedData:clone)
---
---@return love.data.CompressedData clone The new copy.
function CompressedData:clone()
end

---Gets the compression format of the CompressedData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedData:getFormat)
---
---@return love.data.CompressedDataFormat format The format of the CompressedData.
function CompressedData:getFormat()
end

---A Stream that reads from and writes to a Data object's memory. The engine creates one internally, for example when love.sound.newDecoder is given a Data object; it has no Lua constructor or methods of its own.
---
---[Open in Browser](https://love2d.org/wiki/DataStream)
---
---@class love.data.DataStream: love.Stream, love.Object
local DataStream = {}
---@alias love.DataStream love.data.DataStream

---Data object that references a subsection of another Data object's memory, without copying it. Created by love.data.newDataView.
---
---[Open in Browser](https://love2d.org/wiki/DataView)
---
---@class love.data.DataView: love.Data, love.Object
local DataView = {}
---@alias love.DataView love.data.DataView

---Creates a new DataView referencing the same subsection of the same Data object.
---
---[Open in Browser](https://love2d.org/wiki/DataView:clone)
---
---@return love.data.DataView clone The new copy.
function DataView:clone()
end

---Compresses a string or data using a specific compression algorithm.
---
---[Open in Browser](https://love2d.org/wiki/love.data.compress)
---
---@param container love.data.ContainerType What type to return the compressed data as.
---@param format love.data.CompressedDataFormat The format to use when compressing the string.
---@param rawstring string The raw (un-compressed) string to compress.
---@param level (number)? The level of compression to use, between 0 and 9. -1 indicates the default level. The meaning of this argument depends on the compression format being used.
---@return love.data.CompressedData|string compressedData CompressedData/string which contains the compressed version of rawstring.
function love.data.compress(container, format, rawstring, level)
end

---Compresses a string or data using a specific compression algorithm.
---
---[Open in Browser](https://love2d.org/wiki/love.data.compress)
---
---@param container love.data.ContainerType What type to return the compressed data as.
---@param format love.data.CompressedDataFormat The format to use when compressing the data.
---@param data love.Data A Data object containing the raw (un-compressed) data to compress.
---@param level (number)? The level of compression to use, between 0 and 9. -1 indicates the default level. The meaning of this argument depends on the compression format being used.
---@return love.data.CompressedData|string compressedData CompressedData/string which contains the compressed version of data.
function love.data.compress(container, format, data, level)
end

---Decode Data or a string from any of the EncodeFormats to Data or string.
---
---[Open in Browser](https://love2d.org/wiki/love.data.decode)
---
---@param container love.data.ContainerType What type to return the decoded data as.
---@param format love.data.EncodeFormat The format of the input data.
---@param sourceString string The raw (encoded) data to decode.
---@return love.data.ByteData|string decoded ByteData/string which contains the decoded version of source.
function love.data.decode(container, format, sourceString)
end

---Decode Data or a string from any of the EncodeFormats to Data or string.
---
---[Open in Browser](https://love2d.org/wiki/love.data.decode)
---
---@param container love.data.ContainerType What type to return the decoded data as.
---@param format love.data.EncodeFormat The format of the input data.
---@param sourceData love.Data The raw (encoded) data to decode.
---@return love.data.ByteData|string decoded ByteData/string which contains the decoded version of source.
function love.data.decode(container, format, sourceData)
end

---Decompresses a CompressedData or previously compressed string or Data object.
---
---[Open in Browser](https://love2d.org/wiki/love.data.decompress)
---
---@param container love.data.ContainerType What type to return the decompressed data as.
---@param compressedData love.data.CompressedData The compressed data to decompress.
---@return love.data.ByteData|string decompressedData Data/string containing the raw decompressed data.
function love.data.decompress(container, compressedData)
end

---Decompresses a CompressedData or previously compressed string or Data object.
---
---[Open in Browser](https://love2d.org/wiki/love.data.decompress)
---
---@param container love.data.ContainerType What type to return the decompressed data as.
---@param format love.data.CompressedDataFormat The format that was used to compress the given string.
---@param compressedString string A string containing data previously compressed with love.data.compress.
---@return love.data.ByteData|string decompressedData Data/string containing the raw decompressed data.
function love.data.decompress(container, format, compressedString)
end

---Decompresses a CompressedData or previously compressed string or Data object.
---
---[Open in Browser](https://love2d.org/wiki/love.data.decompress)
---
---@param container love.data.ContainerType What type to return the decompressed data as.
---@param format love.data.CompressedDataFormat The format that was used to compress the given data.
---@param data love.Data A Data object containing data previously compressed with love.data.compress.
---@return love.data.ByteData|string decompressedData Data/string containing the raw decompressed data.
function love.data.decompress(container, format, data)
end

---Encode Data or a string to a Data or string in one of the EncodeFormats.
---
---[Open in Browser](https://love2d.org/wiki/love.data.encode)
---
---@param container love.data.ContainerType What type to return the encoded data as.
---@param format love.data.EncodeFormat The format of the output data.
---@param sourceString string The raw data to encode.
---@param linelength (number)? The maximum line length of the output. Only supported for base64, ignored if 0.
---@return love.data.ByteData|string encoded ByteData/string which contains the encoded version of source.
function love.data.encode(container, format, sourceString, linelength)
end

---Encode Data or a string to a Data or string in one of the EncodeFormats.
---
---[Open in Browser](https://love2d.org/wiki/love.data.encode)
---
---@param container love.data.ContainerType What type to return the encoded data as.
---@param format love.data.EncodeFormat The format of the output data.
---@param sourceData love.Data The raw data to encode.
---@param linelength (number)? The maximum line length of the output. Only supported for base64, ignored if 0.
---@return love.data.ByteData|string encoded ByteData/string which contains the encoded version of source.
function love.data.encode(container, format, sourceData, linelength)
end

---Gets the size in bytes that a given format used with love.data.pack will use.
---
---This function behaves the same as Lua 5.3's string.packsize.
---
---The format string cannot have the variable-length options 's' or 'z'.
---
---[Open in Browser](https://love2d.org/wiki/love.data.getPackedSize)
---
---@param format string A string determining how the values are packed. Follows the rules of Lua 5.3's string.pack format strings.
---@return number size The size in bytes that the packed data will use.
function love.data.getPackedSize(format)
end

---Compute the message digest of a string using a specified hash algorithm.
---
---[Open in Browser](https://love2d.org/wiki/love.data.hash)
---
---@param containerType love.data.ContainerType What type to return the message digest data as.
---@param hashFunction love.data.HashFunction Hash algorithm to use.
---@param string string String to hash.
---@return love.data.ByteData|string rawdigest Raw message digest data.
function love.data.hash(containerType, hashFunction, string)
end

---Compute the message digest of a string using a specified hash algorithm.
---
---To return the hex string representation of the hash, use love.data.encode
---
---hexDigestString = love.data.encode('string', 'hex', love.data.hash('string', algo, data))
---
---[Open in Browser](https://love2d.org/wiki/love.data.hash)
---
---@param containerType love.data.ContainerType What type to return the message digest data as.
---@param hashFunction love.data.HashFunction Hash algorithm to use.
---@param data love.Data Data to hash.
---@return love.data.ByteData|string rawdigest Raw message digest data.
function love.data.hash(containerType, hashFunction, data)
end

---Compute the message digest of a string using a specified hash algorithm.
---
---Deprecated: use the variant with a ContainerType. Always returns the digest as a string.
---
---[Open in Browser](https://love2d.org/wiki/love.data.hash)
---
---@param hashFunction love.data.HashFunction Hash algorithm to use.
---@param data string|love.Data String or Data to hash.
---@return string rawdigest Raw message digest string.
function love.data.hash(hashFunction, data)
end

---Creates a new Data object containing arbitrary bytes.
---
---Data:getPointer along with LuaJIT's FFI can be used to manipulate the contents of the ByteData object after it has been created.
---
---Creates a new ByteData by copying the contents of the specified string.
---
---[Open in Browser](https://love2d.org/wiki/love.data.newByteData)
---
---@param datastring string The byte string to copy.
---@return love.data.ByteData bytedata The new Data object.
function love.data.newByteData(datastring)
end

---Creates a new Data object containing arbitrary bytes.
---
---Data:getPointer along with LuaJIT's FFI can be used to manipulate the contents of the ByteData object after it has been created.
---
---Creates a new ByteData by copying from an existing Data object.
---
---[Open in Browser](https://love2d.org/wiki/love.data.newByteData)
---
---@param data love.Data The existing Data object to copy.
---@param offset (number)? The offset of the subsection to copy, in bytes.
---@param size (number)? The size in bytes of the new Data object.
---@return love.data.ByteData bytedata The new Data object.
function love.data.newByteData(data, offset, size)
end

---Creates a new Data object containing arbitrary bytes.
---
---Data:getPointer along with LuaJIT's FFI can be used to manipulate the contents of the ByteData object after it has been created.
---
---Creates a new empty ByteData with the specific size.
---
---[Open in Browser](https://love2d.org/wiki/love.data.newByteData)
---
---@param size number The size in bytes of the new Data object.
---@return love.data.ByteData bytedata The new Data object.
function love.data.newByteData(size)
end

---Creates a new Data referencing a subsection of an existing Data object.
---
---Data:getString and Data:getPointer will return the original Data object's contents, with the view's offset and size applied.
---
---[Open in Browser](https://love2d.org/wiki/love.data.newDataView)
---
---@param data love.Data The Data object to reference.
---@param offset number The offset of the subsection to reference, in bytes.
---@param size (number)? The size in bytes of the subsection to reference.
---@return love.data.DataView view The new Data view.
function love.data.newDataView(data, offset, size)
end

---Packs (serializes) simple Lua values.
---
---This function behaves the same as Lua 5.3's string.pack.
---
---Packing integers with values greater than 2^52 is not supported, as Lua 5.1 cannot represent those values in its number type. 
---
---[Open in Browser](https://love2d.org/wiki/love.data.pack)
---
---@param container love.data.ContainerType What type to return the encoded data as.
---@param format string A string determining how the values are packed. Follows the rules of Lua 5.3's string.pack format strings.
---@param v1 number|boolean|string The first value (number, boolean, or string) to serialize.
---@param ... number|boolean|string Additional values to serialize.
---@return love.data.ByteData|string data ByteData/string which contains the serialized data.
function love.data.pack(container, format, v1, ...)
end

---Packs (serializes) simple Lua values.
---
---This function behaves the same as Lua 5.3's string.pack.
---
---Packs the values into an existing ByteData's memory instead of creating a new object. Errors if the packed values do not fit within the ByteData at the given offset.
---
---[Open in Browser](https://love2d.org/wiki/love.data.pack)
---
---@param bytedata love.data.ByteData The ByteData to write the packed values into.
---@param offset number The byte offset in the ByteData to start writing at.
---@param format string A string determining how the values are packed. Follows the rules of Lua 5.3's string.pack format strings.
---@param v1 number|boolean|string The first value (number, boolean, or string) to serialize.
---@param ... number|boolean|string Additional values to serialize.
---@return love.data.ByteData bytedata The same ByteData that was given.
function love.data.pack(bytedata, offset, format, v1, ...)
end

---Unpacks (deserializes) a byte-string or Data into simple Lua values.
---
---This function behaves the same as Lua 5.3's string.unpack.
---
---[Open in Browser](https://love2d.org/wiki/love.data.unpack)
---
---@param format string A string determining how the values were packed. Follows the rules of Lua 5.3's string.pack format strings.
---@param datastring string A string containing the packed (serialized) data.
---@param pos (number)? Where to start reading in the string. Negative values can be used to read relative from the end of the string.
---@return number|boolean|string v1 The first value (number, boolean, or string) that was unpacked.
---@return number|boolean|string ... Additional unpacked values.
---@return number index The index of the first unread byte in the data string.
function love.data.unpack(format, datastring, pos)
end

---Unpacks (deserializes) a byte-string or Data into simple Lua values.
---
---This function behaves the same as Lua 5.3's string.unpack.
---
---Unpacking integers with values greater than 2^52 is not supported, as Lua 5.1 cannot represent those values in its number type. 
---
---[Open in Browser](https://love2d.org/wiki/love.data.unpack)
---
---@param format string A string determining how the values were packed. Follows the rules of Lua 5.3's string.pack format strings.
---@param data love.Data A Data object containing the packed (serialized) data.
---@param pos (number)? 1-based index indicating where to start reading in the Data. Negative values can be used to read relative from the end of the Data object.
---@return number|boolean|string v1 The first value (number, boolean, or string) that was unpacked.
---@return number|boolean|string ... Additional unpacked values.
---@return number index The 1-based index of the first unread byte in the Data.
function love.data.unpack(format, data, pos)
end

---Manages events, like keypresses.
---
---[Open in Browser](https://love2d.org/wiki/love.event)
---
---@class love.event
love.event = {}

---Names of the events love.event.push and love.event.poll use. Each is handled by the love callback of the same name, through love.handlers.
---
---[Open in Browser](https://love2d.org/wiki/Event)
---
---@alias love.event.Event
---Key pressed
---| "keypressed"
---Key released
---| "keyreleased"
---User entered text
---| "textinput"
---Candidate text for an IME changed
---| "textedited"
---Mouse position changed
---| "mousemoved"
---Mouse pressed
---| "mousepressed"
---Mouse released
---| "mousereleased"
---Mouse wheel moved
---| "wheelmoved"
---Touch screen or touchpad touched
---| "touchpressed"
---Touch screen or touchpad stopped being touched
---| "touchreleased"
---Touch press moved
---| "touchmoved"
---Joystick pressed
---| "joystickpressed"
---Joystick released
---| "joystickreleased"
---Joystick axis motion
---| "joystickaxis"
---Joystick hat pressed
---| "joystickhat"
---Joystick's virtual gamepad button pressed
---| "gamepadpressed"
---Joystick's virtual gamepad button released
---| "gamepadreleased"
---Joystick's virtual gamepad axis moved
---| "gamepadaxis"
---Joystick connected
---| "joystickadded"
---Joystick disconnected
---| "joystickremoved"
---A joystick sensor's values changed
---| "joysticksensorupdated"
---Window focus gained or lost
---| "focus"
---Window mouse focus gained or lost
---| "mousefocus"
---Window is minimized or un-minimized by the user
---| "visible"
---Window was exposed and should be redrawn
---| "exposed"
---Window became fully covered by other windows
---| "occluded"
---Quit
---| "quit"
---A Lua error has occurred in a thread
---| "threaderror"
---Window size changed
---| "resize"
---File is dragged and dropped onto the window
---| "filedropped"
---Directory is dragged and dropped onto the window
---| "directorydropped"
---A drag and drop onto the window started
---| "dropbegan"
---A drag and drop moved over the window
---| "dropmoved"
---A drag and drop onto the window finished
---| "dropcompleted"
---Running out of memory on mobile devices
---| "lowmemory"
---Display orientation changed
---| "displayrotated"
---The user's preferred locales changed
---| "localechanged"
---The audio output device was disconnected
---| "audiodisconnected"
---A device sensor's values changed
---| "sensorupdated"
---The system theme changed
---| "themechanged"
---@alias love.Event love.event.Event

---Clears the event queue.
---
---[Open in Browser](https://love2d.org/wiki/love.event.clear)
---
function love.event.clear()
end

---Returns an iterator for messages in the event queue.
---
---[Open in Browser](https://love2d.org/wiki/love.event.poll)
---
---@return fun():(love.event.Event,any) i Iterator function usable in a for loop. It is love.event.poll_i.
function love.event.poll()
end

---Removes the next message from the event queue and returns it. This is the iterator function love.event.poll returns.
---
---[Open in Browser](https://love2d.org/wiki/love.event.poll_i)
---
---@return love.event.Event name The name of the event, or nothing if the queue is empty.
---@return any ... Event values.
function love.event.poll_i()
end

---Pump events into the event queue.
---
---This is a low-level function, and is usually not called by the user, but by love.run.
---
---Note that this does need to be called for any OS to think you're still running, and if you want to handle OS-generated events at all (think callbacks).
---
---Raises an error if a render target is active in love.graphics.
---
---[Open in Browser](https://love2d.org/wiki/love.event.pump)
---
---@param waitTimeout (number)? How long to wait for an event, in seconds, if the queue is empty. 0 doesn't wait, and a negative value waits until an event arrives.
function love.event.pump(waitTimeout)
end

---Adds an event to the event queue.
---
---Any number of arguments may be given. Arguments after the first nil are dropped.
---
---[Open in Browser](https://love2d.org/wiki/love.event.push)
---
---@param n love.event.Event|string The name of the event.
---@param ... (string|number|boolean|table|love.Object)? Event arguments: booleans, numbers, strings, light userdata, love objects, or tables of those values.
---@return boolean success Always true.
function love.event.push(n, ...)
end

---Adds the quit event to the queue.
---
---The quit event is a signal for the event handler to close LÖVE. It's possible to abort the exit process with the love.quit callback.
---
---[Open in Browser](https://love2d.org/wiki/love.event.quit)
---
---@param exitstatus (number)? The program exit status to use when closing the application.
---@return boolean success Always true.
function love.event.quit(exitstatus)
end

---Adds the quit event to the queue.
---
---The quit event is a signal for the event handler to close LÖVE. It's possible to abort the exit process with the love.quit callback.
---
---Restarts the game without relaunching the executable. This cleanly shuts down the main Lua state instance and creates a brand new one. love.event.restart does the same.
---
---[Open in Browser](https://love2d.org/wiki/love.event.quit)
---
---@param restart 'restart' Tells the default love.run to exit and restart the game without relaunching the executable.
---@param restartarg (string|number|boolean|table|love.Object)? A value which will appear in the love.restart field after restarting.
---@return boolean success Always true.
function love.event.quit(restart, restartarg)
end

---Restarts the game without relaunching the executable, by adding a quit event with a "restart" parameter to the queue. This cleanly shuts down the main Lua state instance and creates a brand new one.
---
---Equivalent to `love.event.quit("restart", restartarg)`.
---
---[Open in Browser](https://love2d.org/wiki/love.event.restart)
---
---@param restartarg (string|number|boolean|table|love.Object)? A value which will appear in the love.restart field after restarting. Can be a table containing multiple Lua values.
---@return boolean success Always true.
function love.event.restart(restartarg)
end

---Sets the function that draws frames while the operating system is live-resizing the window, which blocks love.event.pump until the resize ends. By default the main loop function returned by love.run is used.
---
---If the function returns a non-nil first value, the program quits as if the main loop had returned that value and the second one, without calling love.quit again.
---
---[Open in Browser](https://love2d.org/wiki/love.event.setModalDrawCallback)
---
---@param callback (fun():(string|number|boolean|table|love.Object,string|number|boolean|table|love.Object))? The function to call for each frame, or nil to go back to the default.
function love.event.setModalDrawCallback(callback)
end

---Like love.event.poll(), but blocks until there is an event in the queue.
---
---Deprecated, use the waitTimeout argument of love.event.pump instead.
---
---[Open in Browser](https://love2d.org/wiki/love.event.wait)
---
---@return love.event.Event n The name of event.
---@return string|number|boolean|table|love.Object ... Event arguments.
function love.event.wait()
end

---Provides an interface to the user's filesystem.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem)
---
---@class love.filesystem
love.filesystem = {}

---Buffer modes for File objects.
---
---[Open in Browser](https://love2d.org/wiki/BufferMode)
---
---@alias love.filesystem.BufferMode
---No buffering. The result of write and append operations appears immediately.
---| "none"
---Line buffering. Write and append operations are buffered until a newline is output or the buffer size limit is reached.
---| "line"
---Full buffering. Write and append operations are always buffered until the buffer size limit is reached.
---| "full"
---@alias love.BufferMode love.filesystem.BufferMode

---Common platform-dependent directories, used by love.filesystem.getFullCommonPath, love.filesystem.mountCommonPath and love.filesystem.unmountCommonPath.
---
---[Open in Browser](https://love2d.org/wiki/CommonPath)
---
---@alias love.filesystem.CommonPath
---The game's save directory: the identity folder inside 'userappdata' (inside a LOVE folder there unless the game is fused).
---| "appsavedir"
---The game's documents directory: the identity folder inside 'userdocuments' (inside a LOVE folder there unless the game is fused).
---| "appdocuments"
---The user's home directory.
---| "userhome"
---The user's application data directory.
---| "userappdata"
---The user's desktop directory. Not available on Android.
---| "userdesktop"
---The user's documents directory.
---| "userdocuments"
---@alias love.CommonPath love.filesystem.CommonPath

---The different modes you can open a File in.
---
---[Open in Browser](https://love2d.org/wiki/FileMode)
---
---@alias love.filesystem.FileMode
---Open a file for read.
---| "r"
---Open a file for write.
---| "w"
---Open a file for append.
---| "a"
---Do not open a file (represents a closed file.)
---| "c"
---@alias love.FileMode love.filesystem.FileMode

---The type of a file.
---
---[Open in Browser](https://love2d.org/wiki/FileType)
---
---@alias love.filesystem.FileType
---Regular file.
---| "file"
---Directory.
---| "directory"
---Symbolic link.
---| "symlink"
---Something completely different like a device.
---| "other"
---@alias love.FileType love.filesystem.FileType

---Possible load modes for love.filesystem.load. This is equivalent to 3rd parameter (mode) in Lua 5.3 load.
---
---[Open in Browser](https://love2d.org/wiki/LoadMode)
---
---@alias love.filesystem.LoadMode
---Only load the file if it's binary pre-compiled chunk.
---| "b"
---Only load the file if it's plain text file.
---| "t"
---Always loads no matter if it's plain text or pre-compiled chunk.
---| "bt"
---@alias love.LoadMode love.filesystem.LoadMode

---The file access allowed in a path mounted with love.filesystem.mountFullPath or love.filesystem.mountCommonPath.
---
---[Open in Browser](https://love2d.org/wiki/MountPermissions)
---
---@alias love.filesystem.MountPermissions
---Files and folders in the mounted path can only be read.
---| "read"
---Files and folders in the mounted path can be read and written.
---| "readwrite"
---@alias love.MountPermissions love.filesystem.MountPermissions

---Represents a file on the filesystem. A function that takes a file path can also take a File.
---
---[Open in Browser](https://love2d.org/wiki/(File))
---
---@class love.filesystem.File: love.Stream, love.Object
local File = {}
---@alias love.File love.filesystem.File

---Closes a File.
---
---[Open in Browser](https://love2d.org/wiki/(File):close)
---
---@return boolean success Whether closing was successful.
function File:close()
end

---Flushes any buffered written data in the file to the disk.
---
---[Open in Browser](https://love2d.org/wiki/(File):flush)
---
---@return boolean success Whether the file successfully flushed any buffered data to the disk.
---@return string err The error string, if an error occurred and the file could not be flushed.
function File:flush()
end

---Gets the buffer mode of a file.
---
---[Open in Browser](https://love2d.org/wiki/(File):getBuffer)
---
---@return love.filesystem.BufferMode mode The current buffer mode of the file.
---@return number size The maximum size in bytes of the file's buffer.
function File:getBuffer()
end

---Gets the extension of the File's filename: the part after the last dot, without the dot. Returns an empty string if the filename has no extension.
---
---[Open in Browser](https://love2d.org/wiki/(File):getExtension)
---
---@return string ext The extension of the File's filename.
function File:getExtension()
end

---Gets the filename that the File object was created with. If the file object originated from the love.filedropped callback, the filename will be the full platform-dependent file path.
---
---[Open in Browser](https://love2d.org/wiki/(File):getFilename)
---
---@return string filename The filename of the File.
function File:getFilename()
end

---Gets the FileMode the file has been opened with.
---
---[Open in Browser](https://love2d.org/wiki/(File):getMode)
---
---@return love.filesystem.FileMode mode The mode this file has been opened with.
function File:getMode()
end

---Returns the file size.
---
---[Open in Browser](https://love2d.org/wiki/(File):getSize)
---
---@return number size The file size in bytes, or nil if the size could not be determined or does not fit in a Lua number.
---@return string err The error message, if the size could not be determined.
function File:getSize()
end

---Gets whether end-of-file has been reached.
---
---[Open in Browser](https://love2d.org/wiki/(File):isEOF)
---
---@return boolean eof Whether EOF has been reached.
function File:isEOF()
end

---Gets whether the file is open.
---
---[Open in Browser](https://love2d.org/wiki/(File):isOpen)
---
---@return boolean open True if the file is currently open, false otherwise.
function File:isOpen()
end

---Iterate over all the lines in a file. The file is opened in read mode if it is not already, and the iterator closes it when it reaches the end.
---
---[Open in Browser](https://love2d.org/wiki/(File):lines)
---
---@return fun():(string) iterator The iterator (can be used in for loops).
function File:lines()
end

---Open the file for write, read or append.
---
---If you are getting the error message 'Could not set write directory', try setting the save directory. This is done either with love.filesystem.setIdentity or by setting the identity field in love.conf.
---
---[Open in Browser](https://love2d.org/wiki/(File):open)
---
---@param mode love.filesystem.FileMode The mode to open the file in.
---@return boolean ok True on success, false otherwise.
---@return string err The error string if an error occurred.
function File:open(mode)
end

---Read a number of bytes from a file. Returns nil and an error message if the file could not be read.
---
---[Open in Browser](https://love2d.org/wiki/(File):read)
---
---@param bytes (number)? The number of bytes to read.
---@return string contents The contents of the read bytes.
---@return number size How many bytes have been read.
function File:read(bytes)
end

---Read a number of bytes from a file. Returns nil and an error message if the file could not be read.
---
---Reads the contents of a file into either a string or a FileData object.
---
---[Open in Browser](https://love2d.org/wiki/(File):read)
---
---@param container love.data.ContainerType What type to return the file's contents as.
---@param bytes (number)? The number of bytes to read.
---@return love.filesystem.FileData|string contents FileData or string containing the read bytes.
---@return number size How many bytes have been read.
function File:read(container, bytes)
end

---Seek to a position in a file
---
---[Open in Browser](https://love2d.org/wiki/(File):seek)
---
---@param pos number The position to seek to
---@return boolean success Whether the operation was successful
function File:seek(pos)
end

---Sets the buffer mode for a file opened for writing or appending. Files with buffering enabled will not write data to the disk until the buffer size limit is reached, depending on the buffer mode.
---
---File:flush will force any buffered data to be written to the disk.
---
---[Open in Browser](https://love2d.org/wiki/(File):setBuffer)
---
---@param mode love.filesystem.BufferMode The buffer mode to use.
---@param size (number)? The maximum size in bytes of the file's buffer.
---@return boolean success Whether the buffer mode was successfully set.
---@return string errorstr The error string, if the buffer mode could not be set and an error occurred.
function File:setBuffer(mode, size)
end

---Returns the position in the file.
---
---[Open in Browser](https://love2d.org/wiki/(File):tell)
---
---@return number pos The current position, or nil if the position is invalid or does not fit in a Lua number.
---@return string err The error message, if the position could not be determined.
function File:tell()
end

---Write data to a file.
---
---[Open in Browser](https://love2d.org/wiki/(File):write)
---
---@param data string The string data to write.
---@param size (number)? How many bytes to write.
---@return boolean success Whether the operation was successful.
---@return string err The error string if an error occurred.
function File:write(data, size)
end

---Write data to a file.
---
---'''Writing to multiple lines''': In Windows, some text editors (e.g. Notepad before Windows 10 1809) only treat CRLF ('\r\n') as a new line.
---
-----example
---
---f = love.filesystem.openFile('note.txt', 'w')
---
---for i = 1, 10 do
---
---    f:write('This is line '..i..'!\r\n')
---
---end
---
---f:close()
---
---[Open in Browser](https://love2d.org/wiki/(File):write)
---
---@param data love.Data The Data object to write.
---@param size (number)? How many bytes to write.
---@return boolean success Whether the operation was successful.
---@return string errorstr The error string if an error occurred.
function File:write(data, size)
end

---Data representing the contents of a file.
---
---[Open in Browser](https://love2d.org/wiki/FileData)
---
---@class love.filesystem.FileData: love.Data, love.Object
local FileData = {}
---@alias love.FileData love.filesystem.FileData

---Creates a new copy of the FileData, including its filename.
---
---[Open in Browser](https://love2d.org/wiki/FileData:clone)
---
---@return love.filesystem.FileData clone The new copy.
function FileData:clone()
end

---Gets the extension of the FileData.
---
---[Open in Browser](https://love2d.org/wiki/FileData:getExtension)
---
---@return string ext The extension of the file the FileData represents.
function FileData:getExtension()
end

---Gets the filename of the FileData.
---
---[Open in Browser](https://love2d.org/wiki/FileData:getFilename)
---
---@return string name The name of the file the FileData represents.
function FileData:getFilename()
end

---Append data to an existing file.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.append)
---
---@param name string The name (and path) of the file.
---@param data string The string data to append to the file.
---@param size (number)? How many bytes to write.
---@return boolean success True if the operation was successful, or nil if there was an error.
---@return string errormsg The error message on failure.
function love.filesystem.append(name, data, size)
end

---Append data to an existing file.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.append)
---
---@param name string The name (and path) of the file.
---@param data love.Data The Data object to append to the file.
---@param size (number)? How many bytes to write.
---@return boolean success True if the operation was successful, or nil if there was an error.
---@return string errormsg The error message on failure.
function love.filesystem.append(name, data, size)
end

---Gets whether love.filesystem follows symbolic links.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.areSymlinksEnabled)
---
---@return boolean enable Whether love.filesystem follows symbolic links.
function love.filesystem.areSymlinksEnabled()
end

---Converts a full platform-dependent path to its canonical form: an absolute path with '.' and '..' components and symbolic links resolved for the parts of the path that exist. Returns the path unchanged if it cannot be canonicalized.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.canonicalizeRealPath)
---
---@param path string The full platform-dependent path to canonicalize.
---@return string canonicalpath The canonical form of the path.
function love.filesystem.canonicalizeRealPath(path)
end

---Recursively creates a directory.
---
---When called with 'a/b' it creates both 'a' and 'a/b', if they don't exist already.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.createDirectory)
---
---@param name string The directory to create.
---@return boolean success True if the directory was created, false if not.
function love.filesystem.createDirectory(name)
end

---Check whether a file or directory exists.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.exists)
---
---@param filename string The path to a potential file or directory.
---@return boolean exists True if there is a file or directory with the specified name. False otherwise.
function love.filesystem.exists(filename)
end

---Returns the application data directory (could be the same as getUserDirectory)
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getAppdataDirectory)
---
---@return string path The path of the application data directory
function love.filesystem.getAppdataDirectory()
end

---Gets the filesystem paths that will be searched for c libraries when require is called.
---
---The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) Additionally, any occurrence of a double question mark ('??') will be replaced by the name passed to require and the default library extension for the platform.
---
---The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
---
---The default paths string is '??', which makes require('cool') try to load cool.dll, or cool.so depending on the platform.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getCRequirePath)
---
---@return string paths The paths that the ''require'' function will check for c libraries in love's filesystem.
function love.filesystem.getCRequirePath()
end

---Returns a table with the names of files and subdirectories in the specified path. The table is not sorted in any way; the order is undefined.
---
---If the path passed to the function exists in the game and the save directory, it will list the files and directories from both places.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getDirectoryItems)
---
---@param dir string The directory.
---@return (string)[] files A sequence with the names of all files and subdirectories as strings.
function love.filesystem.getDirectoryItems(dir)
end

---Gets the full platform-dependent path of the running LÖVE executable. Returns an empty string if it cannot be determined.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getExecutablePath)
---
---@return string path The full path of the executable.
function love.filesystem.getExecutablePath()
end

---Gets the full platform-dependent path of a common directory, such as the user's home or documents directory. The 'appsavedir' and 'appdocuments' paths are inside 'userappdata' and 'userdocuments', and depend on the identity set with love.filesystem.setIdentity and on whether the game is fused. Returns an empty string if the path does not exist on this platform or no identity is set for an app path.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getFullCommonPath)
---
---@param commonPath love.filesystem.CommonPath The common directory to get the path of.
---@return string path The full platform-dependent path of the common directory.
function love.filesystem.getFullCommonPath(commonPath)
end

---Gets the write directory name for your game. 
---
---Note that this only returns the name of the folder to store your files in, not the full path.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getIdentity)
---
---@return string name The identity that is used as write directory.
function love.filesystem.getIdentity()
end

---Gets information about the specified file or directory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getInfo)
---
---@param path string The file or directory path to check.
---@param filtertype (love.filesystem.FileType)? If supplied, this parameter causes getInfo to only return the info table if the item at the given path matches the specified file type.
---@return {type: love.filesystem.FileType, size: number, modtime: number, readonly: boolean} info A table containing information about the specified path, or nil if nothing exists at the path (or it does not match filtertype). The table contains the following fields:
function love.filesystem.getInfo(path, filtertype)
end

---Gets information about the specified file or directory.
---
---This variant accepts an existing table to fill in, instead of creating a new one.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getInfo)
---
---@param path string The file or directory path to check.
---@param info table A table which will be filled in with info about the specified path.
---@return {type: love.filesystem.FileType, size: number, modtime: number, readonly: boolean} info The table given as an argument, or nil if nothing exists at the path. The table will be filled in with the following fields:
function love.filesystem.getInfo(path, info)
end

---Gets information about the specified file or directory.
---
---This variant only returns info if the item at the given path is the same file type as specified in the filtertype argument, and accepts an existing table to fill in, instead of creating a new one.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getInfo)
---
---@param path string The file or directory path to check.
---@param filtertype love.filesystem.FileType Causes getInfo to only return the info table if the item at the given path matches the specified file type.
---@param info table A table which will be filled in with info about the specified path.
---@return {type: love.filesystem.FileType, size: number, modtime: number, readonly: boolean} info The table given as an argument, or nil if nothing exists at the path or it does not match filtertype. The table will be filled in with the following fields:
function love.filesystem.getInfo(path, filtertype, info)
end

---Gets the platform-specific absolute path of the directory containing a filepath.
---
---This can be used to determine whether a file is inside the save directory or the game's source .love.
---
---This function returns the directory containing the given ''file path'', rather than file. For example, if the file screenshot1.png exists in a directory called screenshots in the game's save directory, love.filesystem.getRealDirectory('screenshots/screenshot1.png') will return the same value as love.filesystem.getSaveDirectory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getRealDirectory)
---
---@param filepath string The filepath to get the directory of.
---@return string realdir The platform-specific full path of the directory containing the filepath, or nil if the filepath does not exist.
---@return string errormsg The error message, if the filepath does not exist.
function love.filesystem.getRealDirectory(filepath)
end

---Gets the filesystem paths that will be searched when require is called.
---
---The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.)
---
---The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
---
---The default paths string is '?.lua;?/init.lua', which makes require('cool') try to load cool.lua and then try cool/init.lua if cool.lua doesn't exist.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getRequirePath)
---
---@return string paths The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.getRequirePath()
end

---Gets the full path to the designated save directory.
---
---This can be useful if you want to use the standard io library (or something else) to
---
---read or write in the save directory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getSaveDirectory)
---
---@return string dir The absolute path to the save directory.
function love.filesystem.getSaveDirectory()
end

---Returns the full path to the the .love file or directory. If the game is fused to the LÖVE executable, then the executable is returned.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getSource)
---
---@return string path The full platform-dependent path of the .love file or directory.
function love.filesystem.getSource()
end

---Returns the full path to the directory containing the .love file. If the game is fused to the LÖVE executable, then the directory containing the executable is returned.
---
---If love.filesystem.isFused is true, the path returned by this function can be passed to love.filesystem.mount, which will make the directory containing the main game (e.g. C:\Program Files\coolgame\) readable by love.filesystem.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getSourceBaseDirectory)
---
---@return string path The full platform-dependent path of the directory containing the .love file.
function love.filesystem.getSourceBaseDirectory()
end

---Returns the path of the user's directory
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getUserDirectory)
---
---@return string path The path of the user's directory
function love.filesystem.getUserDirectory()
end

---Gets the current working directory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.getWorkingDirectory)
---
---@return string cwd The current working directory.
function love.filesystem.getWorkingDirectory()
end

---Initializes love.filesystem, will be called internally, so should not be used explicitly.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.init)
---
---@param appname string The name of the application binary, typically love.
function love.filesystem.init(appname)
end

---Gets whether the game is in fused mode or not.
---
---If a game is in fused mode, its save directory will be directly in the Appdata directory instead of Appdata/LOVE/. The game will also be able to load C Lua dynamic libraries which are located in the save directory.
---
---A game is in fused mode if the source .love has been fused to the executable (see Game Distribution), or if '--fused' has been given as a command-line argument when starting the game.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.isFused)
---
---@return boolean fused True if the game is in fused mode, false otherwise.
function love.filesystem.isFused()
end

---Iterate over the lines in a file.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.lines)
---
---@param name string The name (and path) of the file
---@return fun():(string) iterator A function that iterates over all the lines in the file
function love.filesystem.lines(name)
end

---Loads a Lua file (but does not run it). Raises an error if the file has a syntax error or is not allowed by the load mode.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.load)
---
---@param name string The name (and path) of the file.
---@param mode (love.filesystem.LoadMode)? Controls to only allow precompiled chunk, plain text, or both.
---@return function chunk The loaded chunk, or nil if the file could not be read.
---@return string errormsg The error message if the file could not be read.
function love.filesystem.load(name, mode)
end

---Mounts a zip file or folder in the game's save directory for reading.
---
---It is also possible to mount love.filesystem.getSourceBaseDirectory if the game is in fused mode, and a path dropped onto the window (see love.directorydropped and love.filedropped).
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mount)
---
---@param archive string The folder or zip file in the game's save directory to mount.
---@param mountpoint string The new path the archive will be mounted to.
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the archive was successfully mounted, false otherwise.
function love.filesystem.mount(archive, mountpoint, appendToPath)
end

---Mounts a zip file or folder in the game's save directory for reading.
---
---It is also possible to mount love.filesystem.getSourceBaseDirectory if the game is in fused mode, and a path dropped onto the window (see love.directorydropped and love.filedropped).
---
---Mounts the file a File opened with love.filesystem.openNativeFile, or a file dropped onto the window, points to.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mount)
---
---@param file love.filesystem.File The File whose full path is mounted.
---@param mountpoint string The new path the archive will be mounted to.
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the archive was successfully mounted, false otherwise.
function love.filesystem.mount(file, mountpoint, appendToPath)
end

---Mounts a zip file or folder in the game's save directory for reading.
---
---It is also possible to mount love.filesystem.getSourceBaseDirectory if the game is in fused mode, and a path dropped onto the window (see love.directorydropped and love.filedropped).
---
---Mounts the contents of the given FileData in memory, using its filename as the archive name. The FileData's data must contain a zipped directory structure.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mount)
---
---@param filedata love.filesystem.FileData The FileData object in memory to mount.
---@param mountpoint string The new path the archive will be mounted to.
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the archive was successfully mounted, false otherwise.
function love.filesystem.mount(filedata, mountpoint, appendToPath)
end

---Mounts a zip file or folder in the game's save directory for reading.
---
---It is also possible to mount love.filesystem.getSourceBaseDirectory if the game is in fused mode, and a path dropped onto the window (see love.directorydropped and love.filedropped).
---
---Mounts the contents of the given Data object in memory. The data must contain a zipped directory structure.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mount)
---
---@param data love.Data The Data object in memory to mount.
---@param archivename string The name to associate the mounted data with, for use with love.filesystem.unmount. Must be unique compared to other mounted data.
---@param mountpoint string The new path the archive will be mounted to.
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the archive was successfully mounted, false otherwise.
function love.filesystem.mount(data, archivename, mountpoint, appendToPath)
end

---Mounts a common directory, such as the user's documents or desktop directory, in love.filesystem, for reading or writing. The 'appsavedir' and 'appdocuments' directories are created if they do not exist.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mountCommonPath)
---
---@param commonPath love.filesystem.CommonPath The common directory to mount.
---@param mountpoint string The new path in love.filesystem the common directory will be mounted to.
---@param permission (love.filesystem.MountPermissions)? The requested permissions for operating on files and folders in this path after mounting ("read", or "readwrite").
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the common directory was successfully mounted, false otherwise.
function love.filesystem.mountCommonPath(commonPath, mountpoint, permission, appendToPath)
end

---Mounts a full platform-dependent path to a zip file or folder for reading or writing in love.filesystem. Fails if the path is already mounted.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.mountFullPath)
---
---@param archive string The full platform-dependent path to a folder or zip file to mount.
---@param mountpoint string The new path in love.filesystem the archive or the platform-dependent path will be mounted to.
---@param permission (love.filesystem.MountPermissions)? The requested permissions for operating on files and folders in this path after mounting ("read", or "readwrite").
---@param appendToPath (boolean)? Whether the archive will be searched when reading a filepath before or after already-mounted archives. This includes the game's source and save directories.
---@return boolean success True if the archive was successfully mounted with the given path and permissions, false otherwise.
function love.filesystem.mountFullPath(archive, mountpoint, permission, appendToPath)
end

---Deprecated: use love.filesystem.openFile. Creates a new File object. Without a mode the File is created closed and needs File:open before use.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.newFile)
---
---@param filename string The filename of the file.
---@param mode (love.filesystem.FileMode)? The mode to open the file in.
---@return love.filesystem.File file The new File object, or nil if an error occurred.
---@return string errorstr The error string if an error occurred.
function love.filesystem.newFile(filename, mode)
end

---Creates a new FileData object from a file on disk, or from a string in memory.
---
---Creates a new FileData object from a string in memory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.newFileData)
---
---@param contents string The contents of the file in memory represented as a string.
---@param name string The name of the file, returned by FileData:getFilename and used as the archive name by love.filesystem.mount.
---@return love.filesystem.FileData data The new FileData.
function love.filesystem.newFileData(contents, name)
end

---Creates a new FileData object from a file on disk, or from a string in memory.
---
---Creates a new FileData object from a Data object in memory.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.newFileData)
---
---@param originaldata love.Data The Data object to copy into the new FileData object.
---@param name string The name of the file, returned by FileData:getFilename and used as the archive name by love.filesystem.mount.
---@return love.filesystem.FileData data The new FileData.
function love.filesystem.newFileData(originaldata, name)
end

---Creates a new FileData object from a file on disk, or from a string in memory.
---
---Creates a new FileData from a file on the storage device.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.newFileData)
---
---@param filepath string|love.filesystem.File Path to the file, or a File to read.
---@return love.filesystem.FileData data The new FileData, or nil if an error occurred.
---@return string err The error string, if an error occurred.
function love.filesystem.newFileData(filepath)
end

---Opens a new File object, which represents an existing or new file on disk. Mode 'c' creates the File without opening it.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.openFile)
---
---@param filename string The filename of the file.
---@param mode love.filesystem.FileMode The mode to open the file in.
---@return love.filesystem.File file The new File object, or nil if an error occurred.
---@return string errorstr The error string if an error occurred.
function love.filesystem.openFile(filename, mode)
end

---Opens a new File object outside of love.filesystem paths.
---
---Unlike love.filesystem.openFile which operates on restricted love.filesystem paths, this is more similar to Lua standard io.open. 
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.openNativeFile)
---
---@param filename string The full platform-dependent path to the file.
---@param mode love.filesystem.FileMode The mode to open the file in.
---@return love.filesystem.File file The new File object, or nil if an error occurred.
---@return string errorstr The error string if an error occurred.
function love.filesystem.openNativeFile(filename, mode)
end

---Read the contents of a file.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.read)
---
---@param name string The name (and path) of the file.
---@param size (number)? How many bytes to read.
---@return string contents The file contents, or nil if the file could not be read.
---@return number|string size How many bytes have been read, or the error message if the file could not be read.
function love.filesystem.read(name, size)
end

---Read the contents of a file.
---
---Reads the contents of a file into either a string or a FileData object.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.read)
---
---@param container love.data.ContainerType What type to return the file's contents as.
---@param name string The name (and path) of the file
---@param size (number)? How many bytes to read
---@return love.filesystem.FileData|string contents FileData or string containing the file contents, or nil if the file could not be read.
---@return number|string size How many bytes have been read, or the error message if the file could not be read.
function love.filesystem.read(container, name, size)
end

---Removes a file or empty directory.
---
---The directory must be empty before removal or else it will fail. Simply remove all files and folders in the directory beforehand.
---
---If the file exists in the .love but not in the save directory, it returns false as well.
---
---An opened File prevents removal of the underlying file. Simply close the File to remove it.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.remove)
---
---@param name string The file or directory to remove.
---@return boolean success True if the file/directory was removed, false otherwise.
function love.filesystem.remove(name)
end

---Sets the filesystem paths that will be searched for c libraries when require is called.
---
---The paths string returned by this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.) Additionally, any occurrence of a double question mark ('??') will be replaced by the name passed to require and the default library extension for the platform.
---
---The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
---
---The default paths string is '??', which makes require('cool') try to load cool.dll, or cool.so depending on the platform.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setCRequirePath)
---
---@param paths string The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.setCRequirePath(paths)
end

---Sets whether the game is in fused mode. Only the first call has an effect; LÖVE calls it during startup, so calls from the game are ignored.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setFused)
---
---@param fused boolean Whether the game is in fused mode.
function love.filesystem.setFused(fused)
end

---Sets the write directory for your game. 
---
---Note that you can only set the name of the folder to store your files in, not the location. Raises an error if the write directory could not be set, for example while a file in the old save directory is still open.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setIdentity)
---
---@param name string The new identity that will be used as write directory.
---@param appendToPath (boolean)? Whether the save directory will be searched when reading a filepath before or after the game's source and other already-mounted archives.
function love.filesystem.setIdentity(name, appendToPath)
end

---Sets the filesystem paths that will be searched when require is called.
---
---The paths string given to this function is a sequence of path templates separated by semicolons. The argument passed to ''require'' will be inserted in place of any question mark ('?') character in each template (after the dot characters in the argument passed to ''require'' are replaced by directory separators.)
---
---The paths are relative to the game's source and save directories, as well as any paths mounted with love.filesystem.mount.
---
---The default paths string is '?.lua;?/init.lua', which makes require('cool') try to load cool.lua and then try cool/init.lua if cool.lua doesn't exist.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setRequirePath)
---
---@param paths string The paths that the ''require'' function will check in love's filesystem.
function love.filesystem.setRequirePath(paths)
end

---Sets the source of the game, where the code is present. This function can only be called once, and is normally automatically done by LÖVE.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setSource)
---
---@param path string Absolute path to the game's source folder.
function love.filesystem.setSource(path)
end

---Sets whether love.filesystem follows symbolic links. It is enabled by default.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.setSymlinksEnabled)
---
---@param enable boolean Whether love.filesystem should follow symbolic links.
function love.filesystem.setSymlinksEnabled(enable)
end

---Unmounts a zip file or folder previously mounted for reading with love.filesystem.mount.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.unmount)
---
---@param archive string The folder or zip file in the game's save directory which is currently mounted, or the archive name given when mounting a Data object.
---@return boolean success True if the archive was successfully unmounted, false otherwise.
function love.filesystem.unmount(archive)
end

---Unmounts a zip file or folder previously mounted for reading with love.filesystem.mount.
---
---Unmounts a Data object previously mounted with love.filesystem.mount.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.unmount)
---
---@param data love.Data The mounted Data object.
---@return boolean success True if the Data was successfully unmounted, false otherwise.
function love.filesystem.unmount(data)
end

---Unmounts a common directory previously mounted with love.filesystem.mountCommonPath.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.unmountCommonPath)
---
---@param commonPath love.filesystem.CommonPath The common directory to unmount.
---@return boolean success True if the common directory was successfully unmounted, false otherwise.
function love.filesystem.unmountCommonPath(commonPath)
end

---Unmounts a zip file or folder previously mounted with love.filesystem.mountFullPath.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.unmountFullPath)
---
---@param archive string The full platform-dependent path to a folder or zip file which is currently mounted via love.filesystem.mountFullPath.
---@return boolean success True if the archive was successfully unmounted, false otherwise.
function love.filesystem.unmountFullPath(archive)
end

---Write data to a file in the save directory. If the file existed already, it will be completely replaced by the new contents.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.write)
---
---@param name string The name (and path) of the file.
---@param data string The string data to write to the file.
---@param size (number)? How many bytes to write.
---@return boolean success If the operation was successful.
---@return string message Error message if operation was unsuccessful.
function love.filesystem.write(name, data, size)
end

---Write data to a file in the save directory. If the file existed already, it will be completely replaced by the new contents.
---
---If you are getting the error message 'Could not set write directory', try setting the save directory. This is done either with love.filesystem.setIdentity or by setting the identity field in love.conf.
---
---'''Writing to multiple lines''': In Windows, some text editors (e.g. Notepad) only treat CRLF ('\r\n') as a new line.
---
---[Open in Browser](https://love2d.org/wiki/love.filesystem.write)
---
---@param name string The name (and path) of the file.
---@param data love.Data The Data object to write to the file.
---@param size (number)? How many bytes to write.
---@return boolean success If the operation was successful.
---@return string message Error message if operation was unsuccessful.
function love.filesystem.write(name, data, size)
end

---Allows you to work with fonts.
---
---[Open in Browser](https://love2d.org/wiki/love.font)
---
---@class love.font
love.font = {}

---True Type hinting mode.
---
---[Open in Browser](https://love2d.org/wiki/HintingMode)
---
---@alias love.font.HintingMode
---Default hinting. Should be preferred for typical antialiased fonts.
---| "normal"
---Results in fuzzier text but can sometimes preserve the original glyph shapes of the text better than normal hinting.
---| "light"
---Results in aliased / unsmoothed text with either full opacity or completely transparent pixels. Should be used when antialiasing is not desired for the font.
---| "mono"
---Disables hinting for the font. Results in fuzzier text.
---| "none"
---@alias love.HintingMode love.font.HintingMode

---A GlyphData represents a drawable symbol of a font Rasterizer.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData)
---
---@class love.font.GlyphData: love.Data, love.Object
local GlyphData = {}
---@alias love.GlyphData love.font.GlyphData

---Creates a new copy of the GlyphData.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:clone)
---
---@return love.font.GlyphData clone The new copy.
function GlyphData:clone()
end

---Gets glyph advance.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getAdvance)
---
---@return number advance Glyph advance.
function GlyphData:getAdvance()
end

---Gets glyph bearing.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getBearing)
---
---@return number bx Glyph bearing X.
---@return number by Glyph bearing Y.
function GlyphData:getBearing()
end

---Gets glyph bounding box.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getBoundingBox)
---
---@return number x Glyph position x.
---@return number y Glyph position y.
---@return number width Glyph width.
---@return number height Glyph height.
function GlyphData:getBoundingBox()
end

---Gets glyph dimensions.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getDimensions)
---
---@return number width Glyph width.
---@return number height Glyph height.
function GlyphData:getDimensions()
end

---Gets glyph pixel format.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getFormat)
---
---@return love.image.PixelFormat format Glyph pixel format.
function GlyphData:getFormat()
end

---Gets the glyph's unicode codepoint number.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getGlyph)
---
---@return number glyph Glyph number.
function GlyphData:getGlyph()
end

---Gets glyph string.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getGlyphString)
---
---@return string glyph Glyph string.
function GlyphData:getGlyphString()
end

---Gets glyph height.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getHeight)
---
---@return number height Glyph height.
function GlyphData:getHeight()
end

---Gets glyph width.
---
---[Open in Browser](https://love2d.org/wiki/GlyphData:getWidth)
---
---@return number width Glyph width.
function GlyphData:getWidth()
end

---A Rasterizer handles font rendering, containing the font data (image or TrueType font) and drawable glyphs.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer)
---
---@class love.font.Rasterizer: love.Object
local Rasterizer = {}
---@alias love.Rasterizer love.font.Rasterizer

---Gets font advance.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getAdvance)
---
---@return number advance Font advance.
function Rasterizer:getAdvance()
end

---Gets ascent height.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getAscent)
---
---@return number height Ascent height.
function Rasterizer:getAscent()
end

---Gets descent height.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getDescent)
---
---@return number height Descent height.
function Rasterizer:getDescent()
end

---Gets number of glyphs in font.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getGlyphCount)
---
---@return number count Glyphs count.
function Rasterizer:getGlyphCount()
end

---Gets glyph data of a specified glyph.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getGlyphData)
---
---@param glyph string A UTF-8 character.
---@return love.font.GlyphData glyphData The glyph data.
function Rasterizer:getGlyphData(glyph)
end

---Gets glyph data of a specified glyph.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getGlyphData)
---
---@param glyphNumber number A unicode codepoint number.
---@return love.font.GlyphData glyphData The glyph data.
function Rasterizer:getGlyphData(glyphNumber)
end

---Gets font height.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getHeight)
---
---@return number height Font height.
function Rasterizer:getHeight()
end

---Gets line height of a font.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:getLineHeight)
---
---@return number height Line height of a font.
function Rasterizer:getLineHeight()
end

---Checks if font contains specified glyphs.
---
---[Open in Browser](https://love2d.org/wiki/Rasterizer:hasGlyphs)
---
---@param glyph1 string|number A glyph, as a UTF-8 string of one or more characters or a unicode codepoint number.
---@param ... string|number Additional glyphs.
---@return boolean hasGlyphs Whether the font contains every specified glyph.
function Rasterizer:hasGlyphs(glyph1, ...)
end

---Lays out text into positioned glyphs for a font's Rasterizers, including kerning, fallback fonts and word wrapping. The engine uses it internally for Fonts; it has no Lua functions of its own.
---
---[Open in Browser](https://love2d.org/wiki/TextShaper)
---
---@class love.font.TextShaper: love.Object
local TextShaper = {}
---@alias love.TextShaper love.font.TextShaper

---Creates a new BMFont Rasterizer.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newBMFontRasterizer)
---
---@param fontdefinition string|love.filesystem.File|love.filesystem.FileData The BMFont .fnt file, as a filename, File or FileData.
---@param images (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|table)? The glyph page image as a filename, File, FileData or ImageData, or a table of them with one per page. When nil, the pages named in the font definition are loaded.
---@param dpiscale (number)? DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newBMFontRasterizer(fontdefinition, images, dpiscale)
end

---Creates a new GlyphData.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newGlyphData)
---
---@param rasterizer love.font.Rasterizer The Rasterizer containing the font.
---@param glyph string|number The glyph, as a UTF-8 character or a unicode codepoint number.
---@return love.font.GlyphData glyphData The new GlyphData.
function love.font.newGlyphData(rasterizer, glyph)
end

---Creates a new Image Rasterizer.
---
---Create an ImageRasterizer from the image data.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newImageRasterizer)
---
---@param imageData love.image.ImageData|string|love.filesystem.File|love.filesystem.FileData Font image data, or an image file to load it from.
---@param glyphs string String containing font glyphs.
---@param extraSpacing (number)? Font extra spacing.
---@param dpiscale (number)? Font DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newImageRasterizer(imageData, glyphs, extraSpacing, dpiscale)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a TrueType Rasterizer of size 12 or a BMFont Rasterizer, chosen by the file contents.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData The font file, as a filename, File or FileData.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(filename)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a TrueTypeRasterizer with the default font.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param size (number)? The font size.
---@param hinting (love.font.HintingMode)? True Type hinting mode.
---@param dpiscale (number)? The font DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(size, hinting, dpiscale)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a TrueTypeRasterizer with the default font and a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param size (number)? The font size.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} Rasterizer settings.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(size, settings)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a TrueTypeRasterizer with a custom font.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param font string|love.filesystem.File|love.Data The font file, as a filename, File, FileData, or other Data holding the file contents.
---@param size number The font size.
---@param hinting (love.font.HintingMode)? True Type hinting mode.
---@param dpiscale (number)? The font DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(font, size, hinting, dpiscale)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a TrueTypeRasterizer with a custom font and a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param font string|love.filesystem.File|love.Data The font file, as a filename, File, FileData, or other Data holding the file contents.
---@param size number The font size.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} Rasterizer settings.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(font, size, settings)
end

---Creates a new Rasterizer. A number first or second argument (or no arguments) creates a TrueType Rasterizer, a lone font file creates a TrueType or BMFont Rasterizer depending on its contents, and anything else creates a BMFont Rasterizer.
---
---Create a BMFont Rasterizer. Used when the second argument is neither a number nor nil.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newRasterizer)
---
---@param fontdefinition string|love.filesystem.File|love.filesystem.FileData The BMFont .fnt file, as a filename, File or FileData.
---@param images string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|table The glyph page image as a filename, File, FileData or ImageData, or a table of them with one per page.
---@param dpiscale (number)? DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newRasterizer(fontdefinition, images, dpiscale)
end

---Creates a new TrueType Rasterizer.
---
---Create a TrueTypeRasterizer with the default font.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newTrueTypeRasterizer)
---
---@param size (number)? The font size.
---@param hinting (love.font.HintingMode)? True Type hinting mode.
---@param dpiscale (number)? The font DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newTrueTypeRasterizer(size, hinting, dpiscale)
end

---Creates a new TrueType Rasterizer.
---
---Create a TrueTypeRasterizer with the default font and a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newTrueTypeRasterizer)
---
---@param size (number)? The font size.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} Rasterizer settings.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newTrueTypeRasterizer(size, settings)
end

---Creates a new TrueType Rasterizer.
---
---Create a TrueTypeRasterizer with a custom font.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newTrueTypeRasterizer)
---
---@param font string|love.filesystem.File|love.Data The font file, as a filename, File, FileData, or other Data holding the file contents.
---@param size (number)? The font size.
---@param hinting (love.font.HintingMode)? True Type hinting mode.
---@param dpiscale (number)? The font DPI scale.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newTrueTypeRasterizer(font, size, hinting, dpiscale)
end

---Creates a new TrueType Rasterizer.
---
---Create a TrueTypeRasterizer with a custom font and a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.font.newTrueTypeRasterizer)
---
---@param font string|love.filesystem.File|love.Data The font file, as a filename, File, FileData, or other Data holding the file contents.
---@param size (number)? The font size.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} Rasterizer settings.
---@return love.font.Rasterizer rasterizer The rasterizer.
function love.font.newTrueTypeRasterizer(font, size, settings)
end

---The primary responsibility for the love.graphics module is the drawing of lines, shapes, text, Images and other Drawable objects onto the screen. Its secondary responsibilities include loading external files (including Images and Fonts) into memory, creating specialized objects (such as ParticleSystems or Canvases) and managing screen geometry.
---
---LÖVE's coordinate system is rooted in the upper-left corner of the screen, which is at location (0, 0). The x axis is horizontal: larger values are further to the right. The y axis is vertical: larger values are further towards the bottom.
---
---In many cases, you draw images or shapes in terms of their upper-left corner.
---
---Many of the functions are used to manipulate the graphics coordinate system, which is essentially the way coordinates are mapped to the display. You can change the position, scale, and even rotation in this way.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics)
---
---@class love.graphics
love.graphics = {}

---Text alignment.
---
---[Open in Browser](https://love2d.org/wiki/AlignMode)
---
---@alias love.graphics.AlignMode
---Align text center.
---| "center"
---Align text left.
---| "left"
---Align text right.
---| "right"
---Align text both left and right.
---| "justify"
---@alias love.AlignMode love.graphics.AlignMode

---Different types of arcs that can be drawn.
---
---[Open in Browser](https://love2d.org/wiki/ArcType)
---
---@alias love.graphics.ArcType
---The arc is drawn like a slice of pie, with the arc circle connected to the center at its end-points.
---| "pie"
---The arc circle's two end-points are unconnected when the arc is drawn as a line. Behaves like the "closed" arc type when the arc is drawn in filled mode.
---| "open"
---The arc circle's two end-points are connected to each other.
---| "closed"
---@alias love.ArcType love.graphics.ArcType

---Types of particle area spread distribution.
---
---[Open in Browser](https://love2d.org/wiki/AreaSpreadDistribution)
---
---@alias love.graphics.AreaSpreadDistribution
---Uniform distribution.
---| "uniform"
---Normal (gaussian) distribution.
---| "normal"
---Uniform distribution in an ellipse.
---| "ellipse"
---Distribution in an ellipse with particles spawning at the edges of the ellipse.
---| "borderellipse"
---Distribution in a rectangle with particles spawning at the edges of the rectangle.
---| "borderrectangle"
---No distribution - area spread is disabled.
---| "none"
---@alias love.AreaSpreadDistribution love.graphics.AreaSpreadDistribution

---Different ways alpha affects color blending. See BlendMode and the BlendMode Formulas for additional notes.
---
---[Open in Browser](https://love2d.org/wiki/BlendAlphaMode)
---
---@alias love.graphics.BlendAlphaMode
---The RGB values of what's drawn are multiplied by the alpha values of those colors during blending. This is the default alpha mode.
---| "alphamultiply"
---The RGB values of what's drawn are '''not''' multiplied by the alpha values of those colors during blending. For most blend modes to work correctly with this alpha mode, the colors of a drawn object need to have had their RGB values multiplied by their alpha values at some point previously ("premultiplied alpha").
---| "premultiplied"
---@alias love.BlendAlphaMode love.graphics.BlendAlphaMode

---The factor a source or destination color is multiplied by before the BlendOperation combines them, used with love.graphics.setBlendState.
---
---[Open in Browser](https://love2d.org/wiki/BlendFactor)
---
---@alias love.graphics.BlendFactor
---0 for every component.
---| "zero"
---1 for every component.
---| "one"
---The source color.
---| "srccolor"
---1 minus the source color.
---| "oneminussrccolor"
---The source alpha.
---| "srcalpha"
---1 minus the source alpha.
---| "oneminussrcalpha"
---The destination color.
---| "dstcolor"
---1 minus the destination color.
---| "oneminusdstcolor"
---The destination alpha.
---| "dstalpha"
---1 minus the destination alpha.
---| "oneminusdstalpha"
---The smaller of the source alpha and 1 minus the destination alpha, for the RGB components; 1 for alpha.
---| "srcalphasaturated"
---@alias love.BlendFactor love.graphics.BlendFactor

---Different ways to do color blending. See BlendAlphaMode and the BlendMode Formulas for additional notes.
---
---[Open in Browser](https://love2d.org/wiki/BlendMode)
---
---@alias love.graphics.BlendMode
---Alpha blending (normal). The alpha of what's drawn determines its opacity.
---| "alpha"
---The colors of what's drawn completely replace what was on the screen, with no additional blending. The BlendAlphaMode specified in love.graphics.setBlendMode still affects what happens.
---| "replace"
---'Screen' blending.
---| "screen"
---The pixel colors of what's drawn are added to the pixel colors already on the screen. The alpha of the screen is not modified.
---| "add"
---The pixel colors of what's drawn are subtracted from the pixel colors already on the screen. The alpha of the screen is not modified.
---| "subtract"
---The pixel colors of what's drawn are multiplied with the pixel colors already on the screen (darkening them). The alpha of drawn objects is multiplied with the alpha of the screen rather than determining how much the colors on the screen are affected, even when the "alphamultiply" BlendAlphaMode is used.
---| "multiply"
---The pixel colors of what's drawn are compared to the existing pixel colors, and the larger of the two values for each color component is used. Only works when the "premultiplied" BlendAlphaMode is used in love.graphics.setBlendMode.
---| "lighten"
---The pixel colors of what's drawn are compared to the existing pixel colors, and the smaller of the two values for each color component is used. Only works when the "premultiplied" BlendAlphaMode is used in love.graphics.setBlendMode.
---| "darken"
---Blending is disabled: what's drawn replaces what was on the screen, including its alpha.
---| "none"
---Returned by love.graphics.getBlendMode when the blend state set by love.graphics.setBlendState does not match one of the other modes.
---| "custom"
---@alias love.BlendMode love.graphics.BlendMode

---How the source and destination colors are combined when blending, used with love.graphics.setBlendState. Each operation applies after the source and destination are multiplied by their BlendFactors.
---
---[Open in Browser](https://love2d.org/wiki/BlendOperation)
---
---@alias love.graphics.BlendOperation
---Source + destination.
---| "add"
---Source - destination.
---| "subtract"
---Destination - source.
---| "reversesubtract"
---The smaller of source and destination, per component. Blend factors are not applied.
---| "min"
---The larger of source and destination, per component. Blend factors are not applied.
---| "max"
---@alias love.BlendOperation love.graphics.BlendOperation

---Data formats of the elements in a GraphicsBuffer and of vertex attributes, used by love.graphics.newBuffer and love.graphics.newMesh.
---
---[Open in Browser](https://love2d.org/wiki/BufferDataFormat)
---
---@alias love.graphics.BufferDataFormat
---Single 32 bit floating point number.
---| "float"
---2-component vector of 32 bit floats.
---| "floatvec2"
---3-component vector of 32 bit floats.
---| "floatvec3"
---4-component vector of 32 bit floats.
---| "floatvec4"
---Matrix of 32 bit floats with 2 rows and 2 columns.
---| "floatmat2x2"
---Matrix of 32 bit floats with 2 rows and 3 columns.
---| "floatmat2x3"
---Matrix of 32 bit floats with 2 rows and 4 columns.
---| "floatmat2x4"
---Matrix of 32 bit floats with 3 rows and 2 columns.
---| "floatmat3x2"
---Matrix of 32 bit floats with 3 rows and 3 columns.
---| "floatmat3x3"
---Matrix of 32 bit floats with 3 rows and 4 columns.
---| "floatmat3x4"
---Matrix of 32 bit floats with 4 rows and 2 columns.
---| "floatmat4x2"
---Matrix of 32 bit floats with 4 rows and 3 columns.
---| "floatmat4x3"
---Matrix of 32 bit floats with 4 rows and 4 columns.
---| "floatmat4x4"
---Single 32 bit signed integer.
---| "int32"
---2-component vector of 32 bit signed integers.
---| "int32vec2"
---3-component vector of 32 bit signed integers.
---| "int32vec3"
---4-component vector of 32 bit signed integers.
---| "int32vec4"
---Single 32 bit unsigned integer.
---| "uint32"
---2-component vector of 32 bit unsigned integers.
---| "uint32vec2"
---3-component vector of 32 bit unsigned integers.
---| "uint32vec3"
---4-component vector of 32 bit unsigned integers.
---| "uint32vec4"
---4-component vector of 8 bit signed fixed-point normalized numbers.
---| "snorm8vec4"
---4-component vector of 8 bit unsigned fixed-point normalized numbers. Useful for colors.
---| "unorm8vec4"
---4-component vector of 8 bit signed integers.
---| "int8vec4"
---4-component vector of 8 bit unsigned integers.
---| "uint8vec4"
---2-component vector of 16 bit signed fixed-point normalized numbers.
---| "snorm16vec2"
---4-component vector of 16 bit signed fixed-point normalized numbers.
---| "snorm16vec4"
---2-component vector of 16 bit unsigned fixed-point normalized numbers.
---| "unorm16vec2"
---4-component vector of 16 bit unsigned fixed-point normalized numbers.
---| "unorm16vec4"
---2-component vector of 16 bit signed integers.
---| "int16vec2"
---4-component vector of 16 bit signed integers.
---| "int16vec4"
---Single 16 bit unsigned integer.
---| "uint16"
---2-component vector of 16 bit unsigned integers.
---| "uint16vec2"
---4-component vector of 16 bit unsigned integers.
---| "uint16vec4"
---Single boolean (4 bytes per component).
---| "bool"
---2-component vector of booleans (4 bytes per component).
---| "boolvec2"
---3-component vector of booleans (4 bytes per component).
---| "boolvec3"
---4-component vector of booleans (4 bytes per component).
---| "boolvec4"
---@alias love.BufferDataFormat love.graphics.BufferDataFormat

---Usage hints for GraphicsBuffers, SpriteBatches and Meshes to optimize data storage and access.
---
---[Open in Browser](https://love2d.org/wiki/BufferDataUsage)
---
---@alias love.graphics.BufferDataUsage
---The object's data will change occasionally during its lifetime. 
---| "dynamic"
---The object will not be modified after initial sprites or vertices are added.
---| "static"
---The object data will always change between draws.
---| "stream"
---The buffer is used for reading data back from the GPU. It cannot be a vertex, index, texel, shaderstorage or indirectarguments buffer.
---| "readback"
---@alias love.BufferDataUsage love.graphics.BufferDataUsage

---The ways a GraphicsBuffer can be used, checked with GraphicsBuffer:isBufferType and set by the matching boolean fields of the love.graphics.newBuffer settings table.
---
---[Open in Browser](https://love2d.org/wiki/BufferUsage)
---
---@alias love.graphics.BufferUsage
---The buffer can hold vertex data for Meshes.
---| "vertex"
---The buffer can hold vertex indices (uint16 or uint32).
---| "index"
---The buffer can be read as a texel buffer in shaders.
---| "texel"
---The buffer can be read and written as a shader storage buffer in shaders.
---| "shaderstorage"
---The buffer can hold the arguments of love.graphics.drawIndirect, love.graphics.drawFromShaderIndirect and love.graphics.dispatchIndirect.
---| "indirectarguments"
---@alias love.BufferUsage love.graphics.BufferUsage

---Different types of per-pixel stencil test and depth test comparisons. The pixels of an object will be drawn if the comparison succeeds, for each pixel that the object touches.
---
---[Open in Browser](https://love2d.org/wiki/CompareMode)
---
---@alias love.graphics.CompareMode
---* stencil tests: the stencil value of the pixel must be equal to the supplied value.
---| "equal"
---* stencil tests: the stencil value of the pixel must not be equal to the supplied value.
---| "notequal"
---* stencil tests: the stencil value of the pixel must be less than the supplied value.
---| "less"
---* stencil tests: the stencil value of the pixel must be less than or equal to the supplied value.
---| "lequal"
---* stencil tests: the stencil value of the pixel must be greater than or equal to the supplied value.
---| "gequal"
---* stencil tests: the stencil value of the pixel must be greater than the supplied value.
---| "greater"
---Objects will never be drawn.
---| "never"
---Objects will always be drawn. Effectively disables the depth or stencil test.
---| "always"
---@alias love.CompareMode love.graphics.CompareMode

---How Mesh geometry is culled when rendering.
---
---[Open in Browser](https://love2d.org/wiki/CullMode)
---
---@alias love.graphics.CullMode
---Back-facing triangles in Meshes are culled (not rendered). The vertex order of a triangle determines whether it is back- or front-facing.
---| "back"
---Front-facing triangles in Meshes are culled.
---| "front"
---Both back- and front-facing triangles in Meshes are rendered.
---| "none"
---@alias love.CullMode love.graphics.CullMode

---Controls whether shapes are drawn as an outline, or filled.
---
---[Open in Browser](https://love2d.org/wiki/DrawMode)
---
---@alias love.graphics.DrawMode
---Draw filled shape.
---| "fill"
---Draw outlined shape.
---| "line"
---@alias love.DrawMode love.graphics.DrawMode

---How the image is filtered when scaling.
---
---[Open in Browser](https://love2d.org/wiki/FilterMode)
---
---@alias love.graphics.FilterMode
---Scale image with linear interpolation.
---| "linear"
---Scale image with nearest neighbor interpolation.
---| "nearest"
---@alias love.FilterMode love.graphics.FilterMode

---Graphics features that can be checked for with love.graphics.getSupported.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsFeature)
---
---@alias love.graphics.GraphicsFeature
---Whether multiple formats can be used in the same love.graphics.setCanvas call. Deprecated in the engine.
---| "multicanvasformats"
---Whether the "clampzero" WrapMode is supported.
---| "clampzero"
---Whether the "clampone" WrapMode is supported.
---| "clampone"
---Whether the "lighten" and "darken" BlendModes are supported. Deprecated in the engine.
---| "lighten"
---Whether textures with non-power-of-two dimensions can use mipmapping and the 'repeat' WrapMode. Deprecated in the engine.
---| "fullnpot"
---Whether pixel shaders can use "highp" 32 bit floating point numbers (as opposed to just 16 bit or lower precision). Deprecated in the engine.
---| "pixelshaderhighp"
---Whether shaders can use the dFdx, dFdy, and fwidth functions for computing derivatives. Deprecated in the engine.
---| "shaderderivatives"
---Whether GLSL 3 Shaders can be used. Deprecated in the engine.
---| "glsl3"
---Whether GLSL 4 Shaders can be used. Compute shaders, shader storage buffers and computewrite textures need it.
---| "glsl4"
---Whether mesh instancing is supported. Deprecated in the engine.
---| "instancing"
---Whether GraphicsBuffers created with the texel usage flag are supported.
---| "texelbuffer"
---Whether love.graphics.copyTextureToBuffer is supported.
---| "copytexturetobuffer"
---Whether love.graphics.drawIndirect, love.graphics.drawFromShaderIndirect and love.graphics.dispatchIndirect are supported.
---| "indirectdraw"
---Whether vertex shaders can write to storage textures.
---| "vertexwrite"
---Whether pixel shaders can write to storage textures.
---| "pixelwrite"
---Whether vertex shaders can choose the layer of the render target to draw to (the shaderlayer field of love.graphics.setCanvas).
---| "shaderlayer"
---@alias love.GraphicsFeature love.graphics.GraphicsFeature

---Types of system-dependent graphics limits checked for using love.graphics.getSystemLimits.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsLimit)
---
---@alias love.graphics.GraphicsLimit
---The maximum size of points.
---| "pointsize"
---The maximum width or height of 2D and Array textures.
---| "texturesize"
---The maximum number of layers in an Array texture.
---| "texturelayers"
---The maximum width, height, or depth of a Volume texture.
---| "volumetexturesize"
---The maximum width or height of a Cubemap texture.
---| "cubetexturesize"
---The maximum number of elements in a texel buffer.
---| "texelbuffersize"
---The maximum size in bytes of a shader storage buffer.
---| "shaderstoragebuffersize"
---The maximum number of compute shader thread groups in the x dimension, for love.graphics.dispatchThreadgroups.
---| "threadgroupsx"
---The maximum number of compute shader thread groups in the y dimension, for love.graphics.dispatchThreadgroups.
---| "threadgroupsy"
---The maximum number of compute shader thread groups in the z dimension, for love.graphics.dispatchThreadgroups.
---| "threadgroupsz"
---The maximum number of simultaneously active render targets (via love.graphics.setCanvas.)
---| "multicanvas"
---The maximum number of antialiasing samples for a render target Texture.
---| "texturemsaa"
---The maximum amount of anisotropic filtering. Texture:setMipmapFilter internally clamps the given anisotropy value to the system's limit.
---| "anisotropy"
---@alias love.GraphicsLimit love.graphics.GraphicsLimit

---Vertex map datatype for Data variant of Mesh:setVertexMap.
---
---[Open in Browser](https://love2d.org/wiki/IndexDataType)
---
---@alias love.graphics.IndexDataType
---The vertex map is array of unsigned word (16-bit).
---| "uint16"
---The vertex map is array of unsigned dword (32-bit).
---| "uint32"
---@alias love.IndexDataType love.graphics.IndexDataType

---Line join style.
---
---[Open in Browser](https://love2d.org/wiki/LineJoin)
---
---@alias love.graphics.LineJoin
---The ends of the line segments beveled in an angle so that they join seamlessly.
---| "miter"
---No cap applied to the ends of the line segments.
---| "none"
---Flattens the point where line segments join together.
---| "bevel"
---@alias love.LineJoin love.graphics.LineJoin

---The styles in which lines are drawn.
---
---[Open in Browser](https://love2d.org/wiki/LineStyle)
---
---@alias love.graphics.LineStyle
---Draw rough lines.
---| "rough"
---Draw smooth lines.
---| "smooth"
---@alias love.LineStyle love.graphics.LineStyle

---How a Mesh's vertices are used when drawing.
---
---[Open in Browser](https://love2d.org/wiki/MeshDrawMode)
---
---@alias love.graphics.MeshDrawMode
---The vertices create a "fan" shape with the first vertex acting as the hub point. Can be easily used to draw simple convex polygons.
---| "fan"
---The vertices create a series of connected triangles using vertices 1, 2, 3, then 3, 2, 4 (note the order), then 3, 4, 5, and so on.
---| "strip"
---The vertices create unconnected triangles.
---| "triangles"
---The vertices are drawn as unconnected points (see love.graphics.setPointSize.)
---| "points"
---@alias love.MeshDrawMode love.graphics.MeshDrawMode

---How a Texture's mipmaps are sampled, used with Texture:setMipmapFilter and love.graphics.setDefaultMipmapFilter.
---
---[Open in Browser](https://love2d.org/wiki/MipmapFilterMode)
---
---@alias love.graphics.MipmapFilterMode
---Mipmaps are not used.
---| "none"
---Blends between the two nearest mipmap levels.
---| "linear"
---Uses the nearest mipmap level.
---| "nearest"
---@alias love.MipmapFilterMode love.graphics.MipmapFilterMode

---Controls whether a Texture has mipmaps, and how they are updated. Set with the mipmaps field of the Texture settings table.
---
---[Open in Browser](https://love2d.org/wiki/MipmapMode)
---
---@alias love.graphics.MipmapMode
---The Texture has no mipmaps.
---| "none"
---The Texture has mipmaps. love.graphics.setCanvas can be used to render to a specific mipmap level, or Texture:generateMipmaps can (re-)compute all mipmap levels based on the base level.
---| "manual"
---The Texture has mipmaps, and all mipmap levels will automatically be recomputed when switching away from the Texture with love.graphics.setCanvas after rendering to its base level. Falls back to manual for compressed formats and formats that cannot generate mipmaps.
---| "auto"
---@alias love.MipmapMode love.graphics.MipmapMode

---How newly created particles are added to the ParticleSystem.
---
---[Open in Browser](https://love2d.org/wiki/ParticleInsertMode)
---
---@alias love.graphics.ParticleInsertMode
---Particles are inserted at the top of the ParticleSystem's list of particles.
---| "top"
---Particles are inserted at the bottom of the ParticleSystem's list of particles.
---| "bottom"
---Particles are inserted at random positions in the ParticleSystem's list of particles.
---| "random"
---@alias love.ParticleInsertMode love.graphics.ParticleInsertMode

---A graphics backend love.graphics can use. Listed in love.conf's t.graphics.renderers and t.graphics.excluderenderers, and in the --renderers and --excluderenderers command line options. Unknown names in those lists are ignored.
---
---[Open in Browser](https://love2d.org/wiki/Renderer)
---
---@alias love.graphics.Renderer
---The Metal backend, on macOS and iOS.
---| "metal"
---The OpenGL or OpenGL ES backend.
---| "opengl"
---The Vulkan backend.
---| "vulkan"
---@alias love.Renderer love.graphics.Renderer

---The stages a Shader can have, checked with Shader:hasStage.
---
---[Open in Browser](https://love2d.org/wiki/ShaderStageType)
---
---@alias love.graphics.ShaderStageType
---The vertex shader stage.
---| "vertex"
---The pixel shader stage.
---| "pixel"
---The compute shader stage.
---| "compute"
---@alias love.ShaderStageType love.graphics.ShaderStageType

---Graphics state stack types used with love.graphics.push.
---
---[Open in Browser](https://love2d.org/wiki/StackType)
---
---@alias love.graphics.StackType
---The transformation stack (love.graphics.translate, love.graphics.rotate, etc.)
---| "transform"
---All love.graphics state, including transform state.
---| "all"
---@alias love.StackType love.graphics.StackType

---How draws modify the stencil values of the pixels they touch, used with love.graphics.setStencilState.
---
---[Open in Browser](https://love2d.org/wiki/StencilAction)
---
---@alias love.graphics.StencilAction
---The stencil value of a pixel is not changed.
---| "keep"
---The stencil value of a pixel is set to 0.
---| "zero"
---The stencil value of a pixel will be replaced by the value given to love.graphics.setStencilState, if any object touches the pixel.
---| "replace"
---The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If the stencil value reaches 255 it will stay at 255.
---| "increment"
---The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value reaches 0 it will stay at 0.
---| "decrement"
---The stencil value of a pixel will be incremented by 1 for each object that touches the pixel. If a stencil value of 255 is incremented it will be set to 0.
---| "incrementwrap"
---The stencil value of a pixel will be decremented by 1 for each object that touches the pixel. If the stencil value of 0 is decremented it will be set to 255.
---| "decrementwrap"
---The stencil value of a pixel will be bitwise-inverted for each object that touches the pixel. If a stencil value of 0 is inverted it will become 255.
---| "invert"
---@alias love.StencilAction love.graphics.StencilAction

---High level stencil modes used with love.graphics.setStencilMode and returned by love.graphics.getStencilMode.
---
---[Open in Browser](https://love2d.org/wiki/StencilMode)
---
---@alias love.graphics.StencilMode
---Stencil values are neither written nor tested.
---| "off"
---Subsequent draws replace the stencil value of the pixels they touch with the given value, and do not change pixel colors (the color mask is disabled).
---| "draw"
---Subsequent draws only affect pixels whose stencil value equals the given value. Stencil values are not changed.
---| "test"
---Returned by love.graphics.getStencilMode when the stencil state set by love.graphics.setStencilState does not match one of the other modes.
---| "custom"
---@alias love.StencilMode love.graphics.StencilMode

---Types of textures (2D, cubemap, etc.)
---
---[Open in Browser](https://love2d.org/wiki/TextureType)
---
---@alias love.graphics.TextureType
---Regular 2D texture with width and height.
---| "2d"
---Several same-size 2D textures organized into a single object. Similar to a texture atlas / sprite sheet, but avoids sprite bleeding and other issues.
---| "array"
---Cubemap texture with 6 faces. Requires a custom shader (and Shader:send) to use. Sampling from a cube texture in a shader takes a 3D direction vector instead of a texture coordinate.
---| "cube"
---3D texture with width, height, and depth. Requires a custom shader to use. Volume textures can have texture filtering applied along the 3rd axis.
---| "volume"
---@alias love.TextureType love.graphics.TextureType

---The frequency at which a vertex shader fetches the vertex attribute's data from the Mesh when it's drawn.
---
---Per-instance attributes can be used to render a Mesh many times with different positions, colors, or other attributes via a single love.graphics.drawInstanced call, without using the love_InstanceID vertex shader variable.
---
---[Open in Browser](https://love2d.org/wiki/VertexAttributeStep)
---
---@alias love.graphics.VertexAttributeStep
---The vertex attribute will have a unique value for each vertex in the Mesh.
---| "pervertex"
---The vertex attribute will have a unique value for each instance of the Mesh.
---| "perinstance"
---@alias love.VertexAttributeStep love.graphics.VertexAttributeStep

---How Mesh geometry vertices are ordered.
---
---[Open in Browser](https://love2d.org/wiki/VertexWinding)
---
---@alias love.graphics.VertexWinding
---Clockwise.
---| "cw"
---Counter-clockwise.
---| "ccw"
---@alias love.VertexWinding love.graphics.VertexWinding

---How the image wraps inside a Quad with a larger quad size than image size. This also affects how Meshes with texture coordinates which are outside the range of 1 are drawn, and the color returned by the Texel Shader function when using it to sample from texture coordinates outside of the range of 1.
---
---[Open in Browser](https://love2d.org/wiki/WrapMode)
---
---@alias love.graphics.WrapMode
---Clamp the texture. Appears only once. The area outside the texture's normal range is colored based on the edge pixels of the texture.
---| "clamp"
---Repeat the texture. Fills the whole available extent.
---| "repeat"
---Repeat the texture, flipping it each time it repeats. May produce better visual results than the repeat mode when the texture doesn't seamlessly tile.
---| "mirroredrepeat"
---Clamp the texture. Fills the area outside the texture's normal range with transparent black (or opaque black for textures with no alpha channel.)
---| "clampzero"
---Clamp the texture. Fills the area outside the texture's normal range with opaque white. 
---| "clampone"
---@alias love.WrapMode love.graphics.WrapMode

---Superclass for all things that can be drawn on screen. This is an abstract type that can't be created directly.
---
---[Open in Browser](https://love2d.org/wiki/Drawable)
---
---@class love.graphics.Drawable: love.Object
local Drawable = {}
---@alias love.Drawable love.graphics.Drawable

---Defines the shape of characters that can be drawn onto the screen.
---
---[Open in Browser](https://love2d.org/wiki/Font)
---
---@class love.graphics.Font: love.Object
local Font = {}
---@alias love.Font love.graphics.Font

---Gets the ascent of the Font.
---
---The ascent spans the distance between the baseline and the top of the glyph that reaches farthest from the baseline.
---
---[Open in Browser](https://love2d.org/wiki/Font:getAscent)
---
---@return number ascent The ascent of the Font in pixels.
function Font:getAscent()
end

---Gets the baseline of the Font.
---
---Most scripts share the notion of a baseline: an imaginary horizontal line on which characters rest. In some scripts, parts of glyphs lie below the baseline.
---
---[Open in Browser](https://love2d.org/wiki/Font:getBaseline)
---
---@return number baseline The baseline of the Font in pixels.
function Font:getBaseline()
end

---Gets the DPI scale factor of the Font.
---
---The DPI scale factor represents relative pixel density. A DPI scale factor of 2 means the font's glyphs have twice the pixel density in each dimension (4 times as many pixels in the same area) compared to a font with a DPI scale factor of 1.
---
---The font size of TrueType fonts is scaled internally by the font's specified DPI scale factor. By default, LÖVE uses the screen's DPI scale factor when creating TrueType fonts.
---
---[Open in Browser](https://love2d.org/wiki/Font:getDPIScale)
---
---@return number dpiscale The DPI scale factor of the Font.
function Font:getDPIScale()
end

---Gets the descent of the Font.
---
---The descent spans the distance between the baseline and the lowest descending glyph in a typeface.
---
---[Open in Browser](https://love2d.org/wiki/Font:getDescent)
---
---@return number descent The descent of the Font in pixels.
function Font:getDescent()
end

---Gets the filter mode for a font.
---
---[Open in Browser](https://love2d.org/wiki/Font:getFilter)
---
---@return love.graphics.FilterMode min Filter mode used when minifying the font.
---@return love.graphics.FilterMode mag Filter mode used when magnifying the font.
---@return number anisotropy Maximum amount of anisotropic filtering used.
function Font:getFilter()
end

---Gets the height of the Font.
---
---The height of the font is the size including any spacing; the height which it will need.
---
---[Open in Browser](https://love2d.org/wiki/Font:getHeight)
---
---@return number height The height of the Font in pixels.
function Font:getHeight()
end

---Gets the kerning between two characters in the Font.
---
---Kerning is normally handled automatically in love.graphics.print, Text objects, Font:getWidth, Font:getWrap, etc. This function is useful when stitching text together manually.
---
---[Open in Browser](https://love2d.org/wiki/Font:getKerning)
---
---@param leftchar string The left character.
---@param rightchar string The right character.
---@return number kerning The kerning amount to add to the spacing between the two characters. May be negative.
function Font:getKerning(leftchar, rightchar)
end

---Gets the kerning between two characters in the Font.
---
---Kerning is normally handled automatically in love.graphics.print, Text objects, Font:getWidth, Font:getWrap, etc. This function is useful when stitching text together manually.
---
---[Open in Browser](https://love2d.org/wiki/Font:getKerning)
---
---@param leftglyph number The unicode number for the left glyph.
---@param rightglyph number The unicode number for the right glyph.
---@return number kerning The kerning amount to add to the spacing between the two characters. May be negative.
function Font:getKerning(leftglyph, rightglyph)
end

---Gets the line height.
---
---This will be the value previously set by Font:setLineHeight, or 1.0 by default.
---
---[Open in Browser](https://love2d.org/wiki/Font:getLineHeight)
---
---@return number height The current line height.
function Font:getLineHeight()
end

---Determines the maximum width (accounting for newlines) taken by the given string, or the advance width of a single glyph. The width can be fractional.
---
---[Open in Browser](https://love2d.org/wiki/Font:getWidth)
---
---@param text string A string.
---@return number width The width of the text.
function Font:getWidth(text)
end

---Determines the maximum width (accounting for newlines) taken by the given string, or the advance width of a single glyph. The width can be fractional.
---
---Gets the advance width of a single glyph.
---
---[Open in Browser](https://love2d.org/wiki/Font:getWidth)
---
---@param codepoint number The unicode codepoint number of the glyph.
---@return number width The advance width of the glyph.
function Font:getWidth(codepoint)
end

---Gets formatting information for text, given a wrap limit.
---
---This function accounts for newlines correctly (i.e. '\n').
---
---[Open in Browser](https://love2d.org/wiki/Font:getWrap)
---
---@param text string The text that will be wrapped.
---@param wraplimit number The maximum width in pixels of each line that ''text'' is allowed before wrapping.
---@return number width The maximum width of the wrapped text.
---@return (string)[] wrappedtext A sequence containing each line of text that was wrapped.
function Font:getWrap(text, wraplimit)
end

---Gets formatting information for text, given a wrap limit.
---
---This function accounts for newlines correctly (i.e. '\n').
---
---Wraps colored text. The returned lines hold the text only, without colors.
---
---[Open in Browser](https://love2d.org/wiki/Font:getWrap)
---
---@param coloredtext {color1: table, string1: string, [string]: table|string} A table containing colors and strings, in the form of {color1, string1, color2, string2, ...}.
---@param wraplimit number The maximum width in pixels of each line that ''text'' is allowed before wrapping.
---@return number width The maximum width of the wrapped text.
---@return (string)[] wrappedtext A sequence containing each line of text that was wrapped.
function Font:getWrap(coloredtext, wraplimit)
end

---Gets whether the Font can render a character or string.
---
---[Open in Browser](https://love2d.org/wiki/Font:hasGlyphs)
---
---@param text string A UTF-8 encoded unicode string.
---@return boolean hasglyph Whether the font can render all the UTF-8 characters in the string.
function Font:hasGlyphs(text)
end

---Gets whether the Font can render a character or string.
---
---[Open in Browser](https://love2d.org/wiki/Font:hasGlyphs)
---
---@param character1 string A unicode character.
---@param ... string|number More unicode characters, strings or codepoint numbers.
---@return boolean hasglyph Whether the font can render all the glyphs represented by the characters.
function Font:hasGlyphs(character1, ...)
end

---Gets whether the Font can render a character or string.
---
---[Open in Browser](https://love2d.org/wiki/Font:hasGlyphs)
---
---@param codepoint1 number A unicode codepoint number.
---@param ... number|string More unicode codepoint numbers, characters or strings.
---@return boolean hasglyph Whether the font can render all the glyphs represented by the codepoint numbers.
function Font:hasGlyphs(codepoint1, ...)
end

---Sets the fallback fonts. Every fallback Font must have the same DPI scale as this Font. When the Font doesn't contain a glyph, it will substitute the glyph from the next subsequent fallback Fonts. This is akin to setting a 'font stack' in Cascading Style Sheets (CSS).
---
---If this is called it should be before love.graphics.print, Font:getWrap, and other Font methods which use glyph positioning information are called.
---
---Every fallback Font must be created from the same file type as the primary Font. For example, a Font created from a .ttf file can only use fallback Fonts that were created from .ttf files.
---
---[Open in Browser](https://love2d.org/wiki/Font:setFallbacks)
---
---@param fallbackfont1 love.graphics.Font The first fallback Font to use.
---@param ... love.graphics.Font Additional fallback Fonts.
function Font:setFallbacks(fallbackfont1, ...)
end

---Sets the filter mode for a font.
---
---[Open in Browser](https://love2d.org/wiki/Font:setFilter)
---
---@param min love.graphics.FilterMode How to scale a font down.
---@param mag (love.graphics.FilterMode)? How to scale a font up. Defaults to min.
---@param anisotropy (number)? Maximum amount of anisotropic filtering used.
function Font:setFilter(min, mag, anisotropy)
end

---Sets the line height.
---
---When rendering the font in lines the actual height will be determined by the line height multiplied by the height of the font. The default is 1.0.
---
---[Open in Browser](https://love2d.org/wiki/Font:setLineHeight)
---
---@param height number The new line height.
function Font:setLineHeight(height)
end

---Low-level data stored in graphics memory, including arrays of vertices, vertex indices, and custom collections of data accessible in Shaders.
---
---Higher level graphics objects such as Meshes, SpriteBatches, TextBatches, and ParticleSystems make use of GraphicsBuffers internally.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer)
---
---@class love.graphics.GraphicsBuffer: love.Object
local GraphicsBuffer = {}
---@alias love.GraphicsBuffer love.graphics.GraphicsBuffer

---Clears the entire GraphicsBuffer or a specified byte range within it to zero.
---
---This can be more efficient than calling GraphicsBuffer:setArrayData when setting the buffer's contents to zero is desired.
---
---Note that the array element count variants of love.graphics.newBuffer and friends will initialize the buffer's contents to zero when it's first created.
---
---Clears the entire GraphicsBuffer's contents to zero.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:clear)
---
function GraphicsBuffer:clear()
end

---Clears the entire GraphicsBuffer or a specified byte range within it to zero.
---
---This can be more efficient than calling GraphicsBuffer:setArrayData when setting the buffer's contents to zero is desired.
---
---Note that the array element count variants of love.graphics.newBuffer and friends will initialize the buffer's contents to zero when it's first created.
---
---Clears a specified byte range within the GraphicsBuffer to zero.
---
---The offset and size parameters must be multiples of 4.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:clear)
---
---@param offset number The offset in bytes within the Buffer.
---@param size number The size in bytes to clear to zero.
function GraphicsBuffer:clear(offset, size)
end

---Gets the debug name the GraphicsBuffer was created with (the 'debugname' field of love.graphics.newBuffer's settings table).
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:getDebugName)
---
---@return string debugname The debug name, or nil if none was set.
function GraphicsBuffer:getDebugName()
end

---Gets the total number of array elements in this GraphicsBuffer.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:getElementCount)
---
---@return number count The total number of array elements in this Buffer.
function GraphicsBuffer:getElementCount()
end

---Gets the size in bytes used by one array element of this GraphicsBuffer.
---
---This may be larger than the sizes of individual array elements added together, due to internal alignment and padding requirements of different buffer usage modes.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:getElementStride)
---
---@return number stride The size in bytes used by one array element of this Buffer.
function GraphicsBuffer:getElementStride()
end

---Gets the layout of each array element in the GraphicsBuffer: one table per member, in declaration order.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:getFormat)
---
---@return {name: string, format: love.graphics.BufferDataFormat, arraylength: number, location: number, offset: number, size: number}[] format An array with one table per member of an array element.
function GraphicsBuffer:getFormat()
end

---Gets the total size in bytes of the GraphicsBuffer's contents.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:getSize)
---
---@return number size The total size in bytes of the Buffer's contents in VRAM.
function GraphicsBuffer:getSize()
end

---Writes array elements into the GraphicsBuffer from a Lua table or from a Data object.
---
---Writes array elements from a Lua table. Components a format does not need are ignored, and missing optional vector components default to 0, 0, 0, 1.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:setArrayData)
---
---@param data table The array elements to write: either a table of tables, one per element holding every component of that element in order, or a flat table holding all components of all elements in order.
---@param sourceindex (number)? The index of the first array element in data to copy.
---@param destindex (number)? The index of the first array element in the GraphicsBuffer to write to.
---@param count (number)? The number of array elements to copy, or nil to copy as many as fit.
function GraphicsBuffer:setArrayData(data, sourceindex, destindex, count)
end

---Writes array elements into the GraphicsBuffer from a Lua table or from a Data object.
---
---Copies array elements directly from the bytes of a Data object.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:setArrayData)
---
---@param data love.Data The Data to copy from. Its contents must use the same layout as the GraphicsBuffer's array elements.
---@param sourceindex (number)? The index of the first array element in data to copy.
---@param destindex (number)? The index of the first array element in the GraphicsBuffer to write to.
---@param count (number)? The number of array elements to copy, or nil to copy as many as fit.
function GraphicsBuffer:setArrayData(data, sourceindex, destindex, count)
end

---Gets whether the GraphicsBuffer was created with the given buffer type (one of the usage keys in love.graphics.newBuffer's settings table).
---
---[Open in Browser](https://love2d.org/wiki/GraphicsBuffer:isBufferType)
---
---@param type love.graphics.BufferUsage The buffer type to check.
---@return boolean isType True if the GraphicsBuffer can be used as the given buffer type.
function GraphicsBuffer:isBufferType(type)
end

---An asynchronous copy of a Buffer's or Texture's contents from the GPU to the CPU, created by love.graphics.readbackBufferAsync or love.graphics.readbackTextureAsync.
---
---Pending readbacks are updated automatically when love.graphics.present is called.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback)
---
---@class love.graphics.GraphicsReadback: love.Object
local GraphicsReadback = {}
---@alias love.GraphicsReadback love.graphics.GraphicsReadback

---Gets the ByteData holding the result of a Buffer readback. Returns nil while the readback is not complete, and for a Texture readback.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:getBufferData)
---
---@return love.data.ByteData data The read-back Buffer contents, or nil if the readback is not complete or is a Texture readback.
function GraphicsReadback:getBufferData()
end

---Gets the ImageData holding the result of a Texture readback. Returns nil while the readback is not complete, and for a Buffer readback.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:getImageData)
---
---@return love.image.ImageData imageData The read-back Texture contents, or nil if the readback is not complete or is a Buffer readback.
function GraphicsReadback:getImageData()
end

---Gets whether the readback finished with an error.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:hasError)
---
---@return boolean error True if the readback failed.
function GraphicsReadback:hasError()
end

---Gets whether the readback has finished, either successfully or with an error.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:isComplete)
---
---@return boolean complete True if the readback is no longer waiting on the GPU.
function GraphicsReadback:isComplete()
end

---Checks whether the GPU has finished the copy without blocking, and if it has, copies the result into the readback's data.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:update)
---
function GraphicsReadback:update()
end

---Blocks until the GPU has finished the copy, then copies the result into the readback's data.
---
---[Open in Browser](https://love2d.org/wiki/GraphicsReadback:wait)
---
function GraphicsReadback:wait()
end

---A 2D polygon mesh used for drawing arbitrary textured shapes.
---
---[Open in Browser](https://love2d.org/wiki/Mesh)
---
---@class love.graphics.Mesh: love.graphics.Drawable, love.Object
local Mesh = {}
---@alias love.Mesh love.graphics.Mesh

---Attaches a vertex attribute from a GraphicsBuffer or a different Mesh onto this Mesh, for use when drawing. This can be used to share vertex attribute data between several different Meshes, or to supply per-instance data for love.graphics.drawInstanced.
---
---Attaching an attribute with the same name as an existing attached attribute replaces it.
---
---Attaches a vertex attribute from a GraphicsBuffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:attachAttribute)
---
---@param name string|number The name of the vertex attribute to attach, or its binding location.
---@param buffer love.graphics.GraphicsBuffer The vertex GraphicsBuffer to get the vertex attribute from. It must have been created with vertex buffer support.
---@param step (love.graphics.VertexAttributeStep)? Whether the attribute will be per-vertex or per-instance when the mesh is drawn.
---@param attachname (string|number)? The name (or binding location, if name is a location) of the attribute in the source to use. Defaults to name.
---@param startindex (number)? The index of the first array element in the source to use for this Mesh's first vertex.
function Mesh:attachAttribute(name, buffer, step, attachname, startindex)
end

---Attaches a vertex attribute from a GraphicsBuffer or a different Mesh onto this Mesh, for use when drawing. This can be used to share vertex attribute data between several different Meshes, or to supply per-instance data for love.graphics.drawInstanced.
---
---Attaching an attribute with the same name as an existing attached attribute replaces it.
---
---Deprecated: use the GraphicsBuffer variant (Mesh:getVertexBuffer gives a Mesh's buffer). Attaches a vertex attribute from another Mesh's vertex buffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:attachAttribute)
---
---@param name string|number The name of the vertex attribute to attach, or its binding location.
---@param mesh love.graphics.Mesh The Mesh to get the vertex attribute from. It must have its own vertex buffer.
---@param step (love.graphics.VertexAttributeStep)? Whether the attribute will be per-vertex or per-instance when the mesh is drawn.
---@param attachname (string|number)? The name (or binding location, if name is a location) of the attribute in the source to use. Defaults to name.
---@param startindex (number)? The index of the first array element in the source to use for this Mesh's first vertex.
function Mesh:attachAttribute(name, mesh, step, attachname, startindex)
end

---Removes a previously attached vertex attribute from this Mesh.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:detachAttribute)
---
---@param name string The name of the attached vertex attribute to detach.
---@return boolean success Whether the attribute was successfully detached.
function Mesh:detachAttribute(name)
end

---Immediately sends all modified vertex data in the Mesh to the graphics card.
---
---Normally it isn't necessary to call this method as love.graphics.draw(mesh, ...) will do it automatically if needed, but explicitly using **Mesh:flush** gives more control over when the work happens.
---
---If this method is used, it generally shouldn't be called more than once (at most) between love.graphics.draw(mesh, ...) calls.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:flush)
---
function Mesh:flush()
end

---Gets every vertex attribute attached to the Mesh, including the attributes of its own vertex buffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getAttachedAttributes)
---
---@return {name: string, location: number, buffer: love.graphics.GraphicsBuffer, step: love.graphics.VertexAttributeStep, nameinbuffer: string, locationinbuffer: number, startindex: number}[] attributes An array with one table per attached attribute.
function Mesh:getAttachedAttributes()
end

---Gets the mode used when drawing the Mesh.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getDrawMode)
---
---@return love.graphics.MeshDrawMode mode The mode used when drawing the Mesh.
function Mesh:getDrawMode()
end

---Gets the range of vertices used when drawing the Mesh, as set by Mesh:setDrawRange. Returns nothing if no draw range is set.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getDrawRange)
---
---@return number start The index of the first vertex used when drawing, or the index of the first value in the vertex map used if one is set for this Mesh.
---@return number count The number of vertices (or vertex map values) used when drawing.
function Mesh:getDrawRange()
end

---Gets the index GraphicsBuffer used by the Mesh, as set by Mesh:setIndexBuffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getIndexBuffer)
---
---@return love.graphics.GraphicsBuffer buffer The index buffer, or nil if none is set.
function Mesh:getIndexBuffer()
end

---Gets the Texture used when drawing the Mesh. Returns nothing if no Texture is set.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getTexture)
---
---@return love.graphics.Texture texture The Texture used to texture the Mesh when drawing.
function Mesh:getTexture()
end

---Gets the properties of a vertex in the Mesh.
---
---The values are returned in the same order as the vertex attributes in the Mesh's vertex format. A standard Mesh that wasn't created with a custom vertex format will return two position numbers, two texture coordinate numbers, and four color components: x, y, u, v, r, g, b, a.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertex)
---
---@param index number The one-based index of the vertex you want to retrieve the information for.
---@return number attributecomponent The first component of the first vertex attribute in the specified vertex.
---@return number ... Additional components of all vertex attributes in the specified vertex.
function Mesh:getVertex(index)
end

---Gets the properties of a vertex in the Mesh.
---
---Gets the vertex components of a Mesh that wasn't created with a custom vertex format.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertex)
---
---@param index number The index of the vertex you want to retrieve the information for.
---@return number x The position of the vertex on the x-axis.
---@return number y The position of the vertex on the y-axis.
---@return number u The horizontal component of the texture coordinate.
---@return number v The vertical component of the texture coordinate.
---@return number r The red component of the vertex's color.
---@return number g The green component of the vertex's color.
---@return number b The blue component of the vertex's color.
---@return number a The alpha component of the vertex's color.
function Mesh:getVertex(index)
end

---Gets the properties of a specific attribute within a vertex in the Mesh.
---
---Meshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertexAttribute)
---
---@param vertexindex number The index of the the vertex you want to retrieve the attribute for (one-based).
---@param attributeindex number The index of the attribute within the vertex to be retrieved (one-based).
---@return number value1 The value of the first component of the attribute.
---@return number value2 The value of the second component of the attribute.
---@return number ... Any additional vertex attribute components.
function Mesh:getVertexAttribute(vertexindex, attributeindex)
end

---Gets the vertex GraphicsBuffer that the Mesh owns, holding the vertices set with Mesh:setVertices and friends.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertexBuffer)
---
---@return love.graphics.GraphicsBuffer buffer The Mesh's own vertex buffer, or nil if the Mesh was created from GraphicsBuffers instead of owning its vertex data.
function Mesh:getVertexBuffer()
end

---Gets the total number of vertices in the Mesh.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertexCount)
---
---@return number count The total number of vertices in the mesh.
function Mesh:getVertexCount()
end

---Gets the vertex format of the Mesh's own vertex buffer.
---
---A Mesh created without a custom vertex format has the attributes VertexPosition (floatvec2), VertexTexCoord (floatvec2) and VertexColor (unorm8vec4).
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertexFormat)
---
---@return {name: string, location: number, format: love.graphics.BufferDataFormat, arraylength: number, offset: number}[] format An array with one table per vertex attribute.
function Mesh:getVertexFormat()
end

---Gets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.
---
---If no vertex map has been set previously via Mesh:setVertexMap, then this function will return nil in LÖVE 0.10.0+, or an empty table in 0.9.2 and older.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:getVertexMap)
---
---@return (number)[] map A table containing the list of vertex indices used when drawing.
function Mesh:getVertexMap()
end

---Gets whether a specific vertex attribute in the Mesh is enabled. Vertex data from disabled attributes is not used when drawing the Mesh.
---
---If a Mesh wasn't created with a custom vertex format, it will have 3 vertex attributes named VertexPosition, VertexTexCoord, and VertexColor. Otherwise the attribute name must either match one of the vertex attributes specified in the vertex format when creating the Mesh, or must match an attribute attached to this Mesh via Mesh:attachAttribute.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:isAttributeEnabled)
---
---@param name string|number The name of the vertex attribute to be checked, or its binding location.
---@return boolean enabled Whether the vertex attribute is used when drawing this Mesh.
function Mesh:isAttributeEnabled(name)
end

---Enables or disables a specific vertex attribute in the Mesh. Vertex data from disabled attributes is not used when drawing the Mesh.
---
---If a Mesh wasn't created with a custom vertex format, it will have 3 vertex attributes named VertexPosition, VertexTexCoord, and VertexColor. Otherwise the attribute name must either match one of the vertex attributes specified in the vertex format when creating the Mesh, or must match an attribute attached to this Mesh via Mesh:attachAttribute.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setAttributeEnabled)
---
---@param name string|number The name of the vertex attribute to enable or disable, or its binding location.
---@param enable boolean Whether the vertex attribute is used when drawing this Mesh.
function Mesh:setAttributeEnabled(name, enable)
end

---Sets the mode used when drawing the Mesh.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setDrawMode)
---
---@param mode love.graphics.MeshDrawMode The mode to use when drawing the Mesh.
function Mesh:setDrawMode(mode)
end

---Restricts the drawn vertices of the Mesh to a subset of the total.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setDrawRange)
---
---@param start number The index of the first vertex to use when drawing, or the index of the first value in the vertex map to use if one is set for this Mesh.
---@param count number The number of vertices to use when drawing, or number of values in the vertex map to use if one is set for this Mesh.
function Mesh:setDrawRange(start, count)
end

---Restricts the drawn vertices of the Mesh to a subset of the total.
---
---Allows all vertices in the Mesh to be drawn.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setDrawRange)
---
function Mesh:setDrawRange()
end

---Sets a GraphicsBuffer to use as the Mesh's index buffer (vertex map), or removes it. The draw mode 'fan' cannot be used with an index buffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setIndexBuffer)
---
---@param buffer love.graphics.GraphicsBuffer A GraphicsBuffer created as an index buffer.
function Mesh:setIndexBuffer(buffer)
end

---Sets a GraphicsBuffer to use as the Mesh's index buffer (vertex map), or removes it. The draw mode 'fan' cannot be used with an index buffer.
---
---Removes the index buffer.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setIndexBuffer)
---
function Mesh:setIndexBuffer()
end

---Sets the Texture used when drawing the Mesh.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setTexture)
---
---@param texture love.graphics.Texture The Texture to texture the Mesh with when drawing.
function Mesh:setTexture(texture)
end

---Sets the Texture used when drawing the Mesh.
---
---Disables any texture from being used when drawing the Mesh. Untextured meshes have a white color by default.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setTexture)
---
function Mesh:setTexture()
end

---Sets the properties of a vertex in the Mesh.
---
---The arguments are in the same order as the vertex attributes in the Mesh's vertex format. A standard Mesh that wasn't created with a custom vertex format will use two position numbers, two texture coordinate numbers, and four color components per vertex: x, y, u, v, r, g, b, a.
---
---If no value is supplied for a specific vertex attribute component, it will be set to a default value of 0 if its data type is 'float', or 1 if its data type is 'byte'.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertex)
---
---@param index number The index of the the vertex you want to modify (one-based).
---@param attributecomponent number The first component of the first vertex attribute in the specified vertex.
---@param ... number Additional components of all vertex attributes in the specified vertex.
function Mesh:setVertex(index, attributecomponent, ...)
end

---Sets the properties of a vertex in the Mesh.
---
---The table indices are in the same order as the vertex attributes in the Mesh's vertex format. A standard Mesh that wasn't created with a custom vertex format will use two position numbers, two texture coordinate numbers, and four color components per vertex: x, y, u, v, r, g, b, a.
---
---If no value is supplied for a specific vertex attribute component, it will be set to a default value of 0 if its data type is 'float', or 1 if its data type is 'byte'.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertex)
---
---@param index number The index of the the vertex you want to modify (one-based).
---@param vertex {attributecomponent: number, [string]: number} A table with vertex information, in the form of {attributecomponent, ...}.
function Mesh:setVertex(index, vertex)
end

---Sets the properties of a vertex in the Mesh.
---
---Sets the vertex components of a Mesh that wasn't created with a custom vertex format.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertex)
---
---@param index number The index of the the vertex you want to modify (one-based).
---@param x number The position of the vertex on the x-axis.
---@param y number The position of the vertex on the y-axis.
---@param u number The horizontal component of the texture coordinate.
---@param v number The vertical component of the texture coordinate.
---@param r (number)? The red component of the vertex's color.
---@param g (number)? The green component of the vertex's color.
---@param b (number)? The blue component of the vertex's color.
---@param a (number)? The alpha component of the vertex's color.
function Mesh:setVertex(index, x, y, u, v, r, g, b, a)
end

---Sets the properties of a vertex in the Mesh.
---
---Sets the vertex components of a Mesh that wasn't created with a custom vertex format.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertex)
---
---@param index number The index of the the vertex you want to modify (one-based).
---@param vertex {[1]: number, [2]: number, [3]: number, [4]: number, [5]: (number)?, [6]: (number)?, [7]: (number)?, [8]: (number)?} A table with vertex information.
function Mesh:setVertex(index, vertex)
end

---Sets the properties of a specific attribute within a vertex in the Mesh.
---
---Meshes without a custom vertex format specified in love.graphics.newMesh have position as their first attribute, texture coordinates as their second attribute, and color as their third attribute.
---
---Attribute components which exist within the attribute but are not specified as arguments default to 0 for attributes with the float data type, and 255 for the byte data type.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertexAttribute)
---
---@param vertexindex number The index of the the vertex to be modified (one-based).
---@param attributeindex number The index of the attribute within the vertex to be modified (one-based).
---@param value1 number The new value for the first component of the attribute.
---@param value2 number The new value for the second component of the attribute.
---@param ... number Any additional vertex attribute components.
function Mesh:setVertexAttribute(vertexindex, attributeindex, value1, value2, ...)
end

---Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.
---
---The vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertexMap)
---
---@param map table A table containing a list of vertex indices to use when drawing. Values must be in the range of Mesh:getVertexCount().
function Mesh:setVertexMap(map)
end

---Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.
---
---The vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertexMap)
---
---@param vi1 number The index of the first vertex to use when drawing. Must be in the range of Mesh:getVertexCount().
---@param vi2 number The index of the second vertex to use when drawing.
---@param vi3 number The index of the third vertex to use when drawing.
---@param ... number Additional vertex indices.
function Mesh:setVertexMap(vi1, vi2, vi3, ...)
end

---Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.
---
---The vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertexMap)
---
---@param data love.Data Array of vertex indices to use when drawing, starting at 0. Values must be less than Mesh:getVertexCount().
---@param datatype love.graphics.IndexDataType Datatype of the vertex indices array above.
---@param count (number)? The number of indices to read from data. Defaults to as many as fit in data.
function Mesh:setVertexMap(data, datatype, count)
end

---Sets the vertex map for the Mesh. The vertex map describes the order in which the vertices are used when the Mesh is drawn. The vertices, vertex map, and mesh draw mode work together to determine what exactly is displayed on the screen.
---
---The vertex map allows you to re-order or reuse vertices when drawing without changing the actual vertex parameters or duplicating vertices. It is especially useful when combined with different Mesh Draw Modes.
---
---Removes the vertex map, so vertices are drawn in order.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertexMap)
---
function Mesh:setVertexMap()
end

---Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh cannot be changed after it has been created. This is often more efficient than calling Mesh:setVertex in a loop.
---
---The values in each vertex table are in the same order as the vertex attributes in the Mesh's vertex format. A standard Mesh that wasn't created with a custom vertex format will use two position numbers, two texture coordinate numbers, and four color components per vertex: x, y, u, v, r, g, b, a.
---
---If no value is supplied for a vertex attribute component, it defaults to 0 for the first three components and 1 for the fourth, and to 1 for unorm formats.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertices)
---
---@param vertices {attributecomponent: number, [string]: number} The table filled with vertex information tables for each vertex, in the form of {vertex, ...} where each vertex is a table in the form of {attributecomponent, ...}.
---@param startvertex (number)? The index of the first vertex to replace.
---@param count (number)? Amount of vertices to replace. Defaults to the number of vertices in the table.
function Mesh:setVertices(vertices, startvertex, count)
end

---Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh cannot be changed after it has been created. This is often more efficient than calling Mesh:setVertex in a loop.
---
---Sets the vertex components of the Mesh by copying directly from the memory of a Data object.
---
---If LuaJIT's FFI is used to populate the Data object via Data:getPointer and ffi.cast, this variant can be drastically more efficient than other methods of setting Mesh vertex data.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertices)
---
---@param data love.Data A Data object to copy from. The contents of the Data must match the layout of this Mesh's vertex format.
---@param startvertex (number)? The index of the first vertex to replace.
---@param count (number)? The number of vertices to replace. Defaults to all vertices from startvertex to the end of the Mesh.
function Mesh:setVertices(data, startvertex, count)
end

---Replaces a range of vertices in the Mesh with new ones. The total number of vertices in a Mesh cannot be changed after it has been created. This is often more efficient than calling Mesh:setVertex in a loop.
---
---Sets the vertex components of a Mesh that wasn't created with a custom vertex format.
---
---[Open in Browser](https://love2d.org/wiki/Mesh:setVertices)
---
---@param vertices {[1]: number, [2]: number, [3]: number, [4]: number, [5]: (number)?, [6]: (number)?, [7]: (number)?, [8]: (number)?} The table filled with vertex information tables for each vertex as follows:
function Mesh:setVertices(vertices)
end

---A ParticleSystem can be used to create particle effects like fire or smoke.
---
---The particle system has to be created using update it in the update callback to see any changes in the particles emitted.
---
---The particle system won't create any particles unless you call setParticleLifetime and setEmissionRate.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem)
---
---@class love.graphics.ParticleSystem: love.graphics.Drawable, love.Object
local ParticleSystem = {}
---@alias love.ParticleSystem love.graphics.ParticleSystem

---Creates an identical copy of the ParticleSystem in the stopped state.
---
---Cloned ParticleSystem inherit all the set-able state of the original ParticleSystem, but they are initialized stopped.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:clone)
---
---@return love.graphics.ParticleSystem particlesystem The new identical copy of this ParticleSystem.
function ParticleSystem:clone()
end

---Emits a burst of particles from the particle emitter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:emit)
---
---@param numparticles number The amount of particles to emit. The number of emitted particles will be truncated if the particle system's max buffer size is reached.
function ParticleSystem:emit(numparticles)
end

---Gets the maximum number of particles the ParticleSystem can have at once.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getBufferSize)
---
---@return number size The maximum number of particles.
function ParticleSystem:getBufferSize()
end

---Gets the series of colors applied to the particle sprite, one table per color.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getColors)
---
---@return table rgba1 The first color, as {red, green, blue, alpha} with components in the range 0-1.
---@return table ... The additional colors in the same form, up to eight colors in total.
function ParticleSystem:getColors()
end

---Gets the number of particles that are currently in the system.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getCount)
---
---@return number count The current number of live particles.
function ParticleSystem:getCount()
end

---Gets the direction of the particle emitter (in radians).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getDirection)
---
---@return number direction The direction of the emitter (radians).
function ParticleSystem:getDirection()
end

---Gets the area-based spawn parameters for the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getEmissionArea)
---
---@return love.graphics.AreaSpreadDistribution distribution The type of distribution for new particles.
---@return number dx The maximum spawn distance from the emitter along the x-axis for uniform distribution, or the standard deviation along the x-axis for normal distribution.
---@return number dy The maximum spawn distance from the emitter along the y-axis for uniform distribution, or the standard deviation along the y-axis for normal distribution.
---@return number angle The angle in radians of the emission area.
---@return boolean directionRelativeToCenter True if newly spawned particles will be oriented relative to the center of the emission area, false otherwise.
function ParticleSystem:getEmissionArea()
end

---Gets the amount of particles emitted per second.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getEmissionRate)
---
---@return number rate The amount of particles per second.
function ParticleSystem:getEmissionRate()
end

---Gets how long the particle system will emit particles (if -1 then it emits particles forever).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getEmitterLifetime)
---
---@return number life The lifetime of the emitter (in seconds).
function ParticleSystem:getEmitterLifetime()
end

---Gets the mode used when the ParticleSystem adds new particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getInsertMode)
---
---@return love.graphics.ParticleInsertMode mode The mode used when the ParticleSystem adds new particles.
function ParticleSystem:getInsertMode()
end

---Gets the linear acceleration (acceleration along the x and y axes) for particles.
---
---Every particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getLinearAcceleration)
---
---@return number xmin The minimum acceleration along the x axis.
---@return number ymin The minimum acceleration along the y axis.
---@return number xmax The maximum acceleration along the x axis.
---@return number ymax The maximum acceleration along the y axis.
function ParticleSystem:getLinearAcceleration()
end

---Gets the amount of linear damping (constant deceleration) for particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getLinearDamping)
---
---@return number min The minimum amount of linear damping applied to particles.
---@return number max The maximum amount of linear damping applied to particles.
function ParticleSystem:getLinearDamping()
end

---Gets the particle image's draw offset.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getOffset)
---
---@return number ox The x coordinate of the particle image's draw offset.
---@return number oy The y coordinate of the particle image's draw offset.
function ParticleSystem:getOffset()
end

---Gets the lifetime of the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getParticleLifetime)
---
---@return number min The minimum life of the particles (in seconds).
---@return number max The maximum life of the particles (in seconds).
function ParticleSystem:getParticleLifetime()
end

---Gets the position of the emitter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getPosition)
---
---@return number x Position along x-axis.
---@return number y Position along y-axis.
function ParticleSystem:getPosition()
end

---Gets the series of Quads used for the particle sprites.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getQuads)
---
---@return (love.graphics.Quad)[] quads A table containing the Quads used.
function ParticleSystem:getQuads()
end

---Gets the radial acceleration (away from the emitter).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getRadialAcceleration)
---
---@return number min The minimum acceleration.
---@return number max The maximum acceleration.
function ParticleSystem:getRadialAcceleration()
end

---Gets the rotation of the image upon particle creation (in radians).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getRotation)
---
---@return number min The minimum initial angle (radians).
---@return number max The maximum initial angle (radians).
function ParticleSystem:getRotation()
end

---Gets the amount of size variation (0 meaning no variation and 1 meaning full variation between start and end).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSizeVariation)
---
---@return number variation The amount of variation (0 meaning no variation and 1 meaning full variation between start and end).
function ParticleSystem:getSizeVariation()
end

---Gets the series of sizes by which the sprite is scaled. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSizes)
---
---@return number size1 The first size.
---@return number size2 The second size.
---@return number size8 The eighth size.
function ParticleSystem:getSizes()
end

---Gets the speed of the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSpeed)
---
---@return number min The minimum linear speed of the particles.
---@return number max The maximum linear speed of the particles.
function ParticleSystem:getSpeed()
end

---Gets the spin of the sprite.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSpin)
---
---@return number min The minimum spin (radians per second).
---@return number max The maximum spin (radians per second).
function ParticleSystem:getSpin()
end

---Gets the amount of spin variation (0 meaning no variation and 1 meaning full variation between start and end).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSpinVariation)
---
---@return number variation The amount of variation (0 meaning no variation and 1 meaning full variation between start and end).
function ParticleSystem:getSpinVariation()
end

---Gets the amount of directional spread of the particle emitter (in radians).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getSpread)
---
---@return number spread The spread of the emitter (radians).
function ParticleSystem:getSpread()
end

---Gets the tangential acceleration (acceleration perpendicular to the particle's direction).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getTangentialAcceleration)
---
---@return number min The minimum acceleration.
---@return number max The maximum acceleration.
function ParticleSystem:getTangentialAcceleration()
end

---Gets the Texture used for the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:getTexture)
---
---@return love.graphics.Texture texture The Texture used for the particles.
function ParticleSystem:getTexture()
end

---Gets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:hasRelativeRotation)
---
---@return boolean enable True if relative particle rotation is enabled, false if it's disabled.
function ParticleSystem:hasRelativeRotation()
end

---Checks whether the particle system is actively emitting particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:isActive)
---
---@return boolean active True if system is active, false otherwise.
function ParticleSystem:isActive()
end

---Checks whether the particle system is paused.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:isPaused)
---
---@return boolean paused True if system is paused, false otherwise.
function ParticleSystem:isPaused()
end

---Checks whether the particle system is stopped.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:isStopped)
---
---@return boolean stopped True if system is stopped, false otherwise.
function ParticleSystem:isStopped()
end

---Moves the position of the emitter. This results in smoother particle spawning behaviour than if ParticleSystem:setPosition is used every frame.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:moveTo)
---
---@param x number Position along x-axis.
---@param y number Position along y-axis.
function ParticleSystem:moveTo(x, y)
end

---Pauses the particle emitter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:pause)
---
function ParticleSystem:pause()
end

---Resets the particle emitter, removing any existing particles and resetting the lifetime counter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:reset)
---
function ParticleSystem:reset()
end

---Sets the size of the buffer (the max allowed amount of particles in the system).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setBufferSize)
---
---@param size number The buffer size.
function ParticleSystem:setBufferSize(size)
end

---Sets a series of colors to apply to the particle sprite. The particle system will interpolate between each color evenly over the particle's lifetime.
---
---Arguments can be passed in groups of four, representing the components of the desired RGBA value, or as tables of RGBA component values. A table's alpha defaults to 1 if it has only three values; with separate numbers, alpha may only be left out when exactly three numbers are given. At least one color must be specified. A maximum of eight may be used.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setColors)
---
---@param r1 number First color, red component (0-1).
---@param g1 number First color, green component (0-1).
---@param b1 number First color, blue component (0-1).
---@param a1 (number)? First color, alpha component (0-1). It may only be left out when no other colors are given.
---@param ... number Additional colors.
function ParticleSystem:setColors(r1, g1, b1, a1, ...)
end

---Sets a series of colors to apply to the particle sprite. The particle system will interpolate between each color evenly over the particle's lifetime.
---
---Arguments can be passed in groups of four, representing the components of the desired RGBA value, or as tables of RGBA component values. A table's alpha defaults to 1 if it has only three values; with separate numbers, alpha may only be left out when exactly three numbers are given. At least one color must be specified. A maximum of eight may be used.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setColors)
---
---@param rgba1 (number)[] First color, a numerical indexed table with the red, green, blue and alpha values as numbers (0-1). The alpha is optional and defaults to 1 if it is left out.
---@param ... (number)[] Additional color, a numerical indexed table with the red, green, blue and alpha values as numbers (0-1). The alpha is optional and defaults to 1 if it is left out.
function ParticleSystem:setColors(rgba1, ...)
end

---Sets the direction the particles will be emitted in.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setDirection)
---
---@param direction number The direction of the particles (in radians).
function ParticleSystem:setDirection(direction)
end

---Sets area-based spawn parameters for the particles. Newly created particles will spawn in an area around the emitter based on the parameters to this function. A distribution of 'none' (or nil) disables area spawning, and the other arguments are then ignored.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setEmissionArea)
---
---@param distribution love.graphics.AreaSpreadDistribution The type of distribution for new particles.
---@param dx number The maximum spawn distance from the emitter along the x-axis for uniform distribution, or the standard deviation along the x-axis for normal distribution.
---@param dy number The maximum spawn distance from the emitter along the y-axis for uniform distribution, or the standard deviation along the y-axis for normal distribution.
---@param angle (number)? The angle in radians of the emission area.
---@param directionRelativeToCenter (boolean)? True if newly spawned particles will be oriented relative to the center of the emission area, false otherwise.
function ParticleSystem:setEmissionArea(distribution, dx, dy, angle, directionRelativeToCenter)
end

---Sets the amount of particles emitted per second.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setEmissionRate)
---
---@param rate number The amount of particles per second.
function ParticleSystem:setEmissionRate(rate)
end

---Sets how long the particle system should emit particles (if -1 then it emits particles forever).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setEmitterLifetime)
---
---@param life number The lifetime of the emitter (in seconds).
function ParticleSystem:setEmitterLifetime(life)
end

---Sets the mode to use when the ParticleSystem adds new particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setInsertMode)
---
---@param mode love.graphics.ParticleInsertMode The mode to use when the ParticleSystem adds new particles.
function ParticleSystem:setInsertMode(mode)
end

---Sets the linear acceleration (acceleration along the x and y axes) for particles.
---
---Every particle created will accelerate along the x and y axes between xmin,ymin and xmax,ymax.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setLinearAcceleration)
---
---@param xmin number The minimum acceleration along the x axis.
---@param ymin number The minimum acceleration along the y axis.
---@param xmax (number)? The maximum acceleration along the x axis.
---@param ymax (number)? The maximum acceleration along the y axis.
function ParticleSystem:setLinearAcceleration(xmin, ymin, xmax, ymax)
end

---Sets the amount of linear damping (constant deceleration) for particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setLinearDamping)
---
---@param min number The minimum amount of linear damping applied to particles.
---@param max (number)? The maximum amount of linear damping applied to particles.
function ParticleSystem:setLinearDamping(min, max)
end

---Set the offset position which the particle sprite is rotated around.
---
---If this function is not used, the particles rotate around their center.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setOffset)
---
---@param x number The x coordinate of the rotation offset.
---@param y number The y coordinate of the rotation offset.
function ParticleSystem:setOffset(x, y)
end

---Sets the lifetime of the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setParticleLifetime)
---
---@param min number The minimum life of the particles (in seconds).
---@param max (number)? The maximum life of the particles (in seconds).
function ParticleSystem:setParticleLifetime(min, max)
end

---Sets the position of the emitter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setPosition)
---
---@param x number Position along x-axis.
---@param y number Position along y-axis.
function ParticleSystem:setPosition(x, y)
end

---Sets a series of Quads to use for the particle sprites. Particles will choose a Quad from the list based on the particle's current lifetime, allowing for the use of animated sprite sheets with ParticleSystems.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setQuads)
---
---@param quad1 love.graphics.Quad The first Quad to use.
---@param ... love.graphics.Quad Additional Quads to use.
function ParticleSystem:setQuads(quad1, ...)
end

---Sets a series of Quads to use for the particle sprites. Particles will choose a Quad from the list based on the particle's current lifetime, allowing for the use of animated sprite sheets with ParticleSystems.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setQuads)
---
---@param quads (love.graphics.Quad)[] A table containing the Quads to use.
function ParticleSystem:setQuads(quads)
end

---Set the radial acceleration (away from the emitter).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setRadialAcceleration)
---
---@param min number The minimum acceleration.
---@param max (number)? The maximum acceleration.
function ParticleSystem:setRadialAcceleration(min, max)
end

---Sets whether particle angles and rotations are relative to their velocities. If enabled, particles are aligned to the angle of their velocities and rotate relative to that angle.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setRelativeRotation)
---
---@param enable boolean True to enable relative particle rotation, false to disable it.
function ParticleSystem:setRelativeRotation(enable)
end

---Sets the rotation of the image upon particle creation (in radians).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setRotation)
---
---@param min number The minimum initial angle (radians).
---@param max (number)? The maximum initial angle (radians).
function ParticleSystem:setRotation(min, max)
end

---Sets the amount of size variation (0 meaning no variation and 1 meaning full variation between start and end).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSizeVariation)
---
---@param variation number The amount of variation (0 meaning no variation and 1 meaning full variation between start and end).
function ParticleSystem:setSizeVariation(variation)
end

---Sets a series of sizes by which to scale a particle sprite. 1.0 is normal size. The particle system will interpolate between each size evenly over the particle's lifetime.
---
---At least one size must be specified. A maximum of eight may be used.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSizes)
---
---@param size1 number The first size.
---@param size2 (number)? The second size.
---@param size8 (number)? The eighth size.
function ParticleSystem:setSizes(size1, size2, size8)
end

---Sets the speed of the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSpeed)
---
---@param min number The minimum linear speed of the particles.
---@param max (number)? The maximum linear speed of the particles.
function ParticleSystem:setSpeed(min, max)
end

---Sets the spin of the sprite.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSpin)
---
---@param min number The minimum spin (radians per second).
---@param max (number)? The maximum spin (radians per second).
function ParticleSystem:setSpin(min, max)
end

---Sets the amount of spin variation (0 meaning no variation and 1 meaning full variation between start and end).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSpinVariation)
---
---@param variation number The amount of variation (0 meaning no variation and 1 meaning full variation between start and end).
function ParticleSystem:setSpinVariation(variation)
end

---Sets the amount of spread for the system.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setSpread)
---
---@param spread number The amount of spread (radians).
function ParticleSystem:setSpread(spread)
end

---Sets the tangential acceleration (acceleration perpendicular to the particle's direction).
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setTangentialAcceleration)
---
---@param min number The minimum acceleration.
---@param max (number)? The maximum acceleration.
function ParticleSystem:setTangentialAcceleration(min, max)
end

---Sets the Texture to be used for the particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:setTexture)
---
---@param texture love.graphics.Texture A Texture to use for the particles.
function ParticleSystem:setTexture(texture)
end

---Starts the particle emitter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:start)
---
function ParticleSystem:start()
end

---Stops the particle emitter, resetting the lifetime counter.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:stop)
---
function ParticleSystem:stop()
end

---Updates the particle system; moving, creating and killing particles.
---
---[Open in Browser](https://love2d.org/wiki/ParticleSystem:update)
---
---@param dt number The time (seconds) since last frame.
function ParticleSystem:update(dt)
end

---A quadrilateral (a polygon with four sides and four corners) with texture coordinate information.
---
---Quads can be used to select part of a texture to draw. In this way, one large texture atlas can be loaded, and then split up into sub-images.
---
---[Open in Browser](https://love2d.org/wiki/Quad)
---
---@class love.graphics.Quad: love.Object
local Quad = {}
---@alias love.Quad love.graphics.Quad

---Gets the array layer the Quad selects when it is drawn with an array Texture through love.graphics.draw, or added to a SpriteBatch that uses an array Texture.
---
---[Open in Browser](https://love2d.org/wiki/Quad:getLayer)
---
---@return number layer The layer index, starting at 1.
function Quad:getLayer()
end

---Gets reference texture dimensions initially specified in love.graphics.newQuad.
---
---[Open in Browser](https://love2d.org/wiki/Quad:getTextureDimensions)
---
---@return number sw The Texture width used by the Quad.
---@return number sh The Texture height used by the Quad.
function Quad:getTextureDimensions()
end

---Gets the current viewport of this Quad.
---
---[Open in Browser](https://love2d.org/wiki/Quad:getViewport)
---
---@return number x The top-left corner along the x-axis.
---@return number y The top-left corner along the y-axis.
---@return number w The width of the viewport.
---@return number h The height of the viewport.
function Quad:getViewport()
end

---Sets the array layer the Quad selects when it is drawn with an array Texture through love.graphics.draw, or added to a SpriteBatch that uses an array Texture.
---
---[Open in Browser](https://love2d.org/wiki/Quad:setLayer)
---
---@param layer number The layer index, starting at 1.
function Quad:setLayer(layer)
end

---Sets the texture coordinates according to a viewport.
---
---[Open in Browser](https://love2d.org/wiki/Quad:setViewport)
---
---@param x number The top-left corner along the x-axis.
---@param y number The top-left corner along the y-axis.
---@param w number The width of the viewport.
---@param h number The height of the viewport.
---@param sw (number)? Optional new reference width, the width of the Texture. Must be greater than 0 if set.
---@param sh (number)? Optional new reference height, the height of the Texture. Must be greater than 0 if set.
function Quad:setViewport(x, y, w, h, sw, sh)
end

---A Shader is used for advanced hardware-accelerated pixel or vertex manipulation. These effects are written in a language based on GLSL (OpenGL Shading Language) with a few things simplified for easier coding.
---
---Potential uses for shaders include HDR/bloom, motion blur, grayscale/invert/sepia/any kind of color effect, reflection/refraction, distortions, bump mapping, and much more! Here is a collection of basic shaders and good starting point to learn: https://github.com/vrld/moonshine
---
---[Open in Browser](https://love2d.org/wiki/Shader)
---
---@class love.graphics.Shader: love.Object
local Shader = {}
---@alias love.Shader love.graphics.Shader

---Gets the format of a buffer (shader storage buffer) declared in the Shader. A table of this form can be passed to love.graphics.newBuffer to create a matching GraphicsBuffer. Errors if the Shader has no buffer with that name.
---
---[Open in Browser](https://love2d.org/wiki/Shader:getBufferFormat)
---
---@param name string The name of the buffer variable in the Shader.
---@return {name: string, format: love.graphics.BufferDataFormat, arraylength: number}[] format An array with one table per member of the buffer's array elements.
function Shader:getBufferFormat(name)
end

---Gets the debug name the Shader was created with (the 'debugname' option of love.graphics.newShader or love.graphics.newComputeShader).
---
---[Open in Browser](https://love2d.org/wiki/Shader:getDebugName)
---
---@return string debugname The debug name, or nil if none was set.
function Shader:getDebugName()
end

---Gets the local threadgroup size of a compute Shader, as declared by its layout (local_size_x, local_size_y, local_size_z) qualifier. Returns nil if the Shader has no compute stage.
---
---[Open in Browser](https://love2d.org/wiki/Shader:getLocalThreadgroupSize)
---
---@return number x The local threadgroup size in the x dimension, or nil if the Shader is not a compute shader.
---@return number y The local threadgroup size in the y dimension.
---@return number z The local threadgroup size in the z dimension.
function Shader:getLocalThreadgroupSize()
end

---Returns any warning and error messages from compiling the shader code. This can be used for debugging your shaders if there's anything the graphics hardware doesn't like.
---
---[Open in Browser](https://love2d.org/wiki/Shader:getWarnings)
---
---@return string warnings Warning and error messages (if any).
function Shader:getWarnings()
end

---Gets whether the Shader has code for the given shader stage.
---
---[Open in Browser](https://love2d.org/wiki/Shader:hasStage)
---
---@param stage love.graphics.ShaderStageType The shader stage to check.
---@return boolean hasstage True if the Shader has the stage.
function Shader:hasStage(stage)
end

---Gets whether a uniform / extern variable exists in the Shader.
---
---If a graphics driver's shader compiler determines that a uniform / extern variable doesn't affect the final output of the shader, it may optimize the variable out. This function will return false in that case.
---
---[Open in Browser](https://love2d.org/wiki/Shader:hasUniform)
---
---@param name string The name of the uniform variable.
---@return boolean hasuniform Whether the uniform exists in the shader and affects its final output.
function Shader:hasUniform(name)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---Sends numbers to a float, int or uint uniform.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the number to send to the shader.
---@param number number Number to send to store in the uniform variable.
---@param ... number Additional numbers to send if the uniform variable is an array.
function Shader:send(name, number, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the vector to send to the shader.
---@param vector table Numbers to send to the uniform variable as a vector. The number of elements in the table determines the type of the vector (e.g. two numbers -&gt; vec2). At least two and at most four numbers can be used.
---@param ... table Additional vectors to send if the uniform variable is an array. All vectors need to be of the same size (e.g. only vec3's).
function Shader:send(name, vector, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the matrix to send to the shader.
---@param matrix table|love.math.Transform Matrix to send to the uniform variable, in row-major order. Using table form: {{a,b,c,d}, {e,f,g,h}, ... } or {a,b,c,d, e,f,g,h, ...}. A Transform can be sent to a mat4 uniform.
---@param ... table|love.math.Transform Additional matrices of the same type as ''matrix'' to store in a uniform array.
function Shader:send(name, matrix, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the Texture to send to the shader.
---@param texture love.graphics.Texture Texture to send to the uniform variable.
---@param ... love.graphics.Texture Additional Textures to send if the uniform variable is an array.
function Shader:send(name, texture, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the boolean to send to the shader.
---@param boolean boolean Boolean to send to store in the uniform variable.
---@param ... boolean Additional booleans to send if the uniform variable is an array.
function Shader:send(name, boolean, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the matrix to send to the shader.
---@param matrixlayout love.math.MatrixLayout The layout (row- or column-major) of the matrix.
---@param matrix table|love.math.Transform Matrix to send to the uniform variable. Using table form: {{a,b,c,d}, {e,f,g,h}, ... } or {a,b,c,d, e,f,g,h, ...}. A Transform can be sent to a mat4 uniform.
---@param ... table|love.math.Transform Additional matrices of the same type as ''matrix'' to store in a uniform array.
function Shader:send(name, matrixlayout, matrix, ...)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---Sends uniform values to the Shader sourced from the contents of a Data object. This directly copies the bytes of the data.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the uniform to send to the shader.
---@param data love.Data Data object containing the values to send.
---@param offset (number)? Offset in bytes from the start of the Data object.
---@param size (number)? Size in bytes of the data to send. If nil, as many bytes as the specified uniform uses will be copied.
function Shader:send(name, data, offset, size)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---Sends uniform matrices to the Shader sourced from the contents of a Data object. This directly copies the bytes of the data.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the uniform matrix to send to the shader.
---@param data love.Data Data object containing the values to send.
---@param matrixlayout love.math.MatrixLayout The layout (row- or column-major) of the matrix in memory.
---@param offset (number)? Offset in bytes from the start of the Data object.
---@param size (number)? Size in bytes of the data to send. If nil, as many bytes as the specified uniform uses will be copied.
function Shader:send(name, data, matrixlayout, offset, size)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---Sends uniform matrices to the Shader sourced from the contents of a Data object. This directly copies the bytes of the data.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the uniform matrix to send to the shader.
---@param matrixlayout love.math.MatrixLayout The layout (row- or column-major) of the matrix in memory.
---@param data love.Data Data object containing the values to send.
---@param offset (number)? Offset in bytes from the start of the Data object.
---@param size (number)? Size in bytes of the data to send. If nil, as many bytes as the specified uniform uses will be copied.
function Shader:send(name, matrixlayout, data, offset, size)
end

---Sends one or more values to a special (''uniform'') variable inside the shader. Uniform variables have to be marked using the ''uniform'' or ''extern'' keyword, e.g.
---
---uniform float time;  // 'float' is the typical number type used in GLSL shaders.
---
---uniform float varsvec2 light_pos;
---
---uniform vec4 colors[4;
---
---The corresponding send calls would be
---
---shader:send('time', t)
---
---shader:send('vars',a,b)
---
---shader:send('light_pos', {light_x, light_y})
---
---shader:send('colors', {r1, g1, b1, a1},  {r2, g2, b2, a2},  {r3, g3, b3, a3},  {r4, g4, b4, a4})
---
---Uniform / extern variables are read-only in the shader code and remain constant until modified by a Shader:send call. Uniform variables can be accessed in both the Vertex and Pixel components of a shader, as long as the variable is declared in each.
---
---Sends GraphicsBuffers to texel buffer or shader storage buffer uniforms.
---
---[Open in Browser](https://love2d.org/wiki/Shader:send)
---
---@param name string Name of the buffer uniform to send to the shader.
---@param buffer love.graphics.GraphicsBuffer The GraphicsBuffer to bind to a texel buffer or shader storage buffer uniform.
---@param ... love.graphics.GraphicsBuffer Additional GraphicsBuffers to send if the uniform variable is an array.
function Shader:send(name, buffer, ...)
end

---Sends one or more colors to a special (''extern'' / ''uniform'') vec3 or vec4 variable inside the shader. The color components must be in the range of 0 to 1. The colors are gamma-corrected if global gamma-correction is enabled.
---
---Extern variables must be marked using the ''extern'' keyword, e.g.
---
---extern vec4 Color;
---
---The corresponding sendColor call would be
---
---shader:sendColor('Color', {r, g, b, a})
---
---Extern variables can be accessed in both the Vertex and Pixel stages of a shader, as long as the variable is declared in each.
---
---[Open in Browser](https://love2d.org/wiki/Shader:sendColor)
---
---@param name string The name of the color extern variable to send to in the shader.
---@param color (number)[] A table with red, green, blue, and optional alpha color components in the range of 0 to 1 to send to the extern as a vector.
---@param ... (number)[] Additional colors to send in case the extern is an array. All colors need to be of the same size (e.g. only vec3's).
---@return boolean success Always true.
function Shader:sendColor(name, color, ...)
end

---Sends one or more colors to a special (''extern'' / ''uniform'') vec3 or vec4 variable inside the shader. The color components must be in the range of 0 to 1. The colors are gamma-corrected if global gamma-correction is enabled.
---
---Extern variables must be marked using the ''extern'' keyword, e.g.
---
---extern vec4 Color;
---
---The corresponding sendColor call would be
---
---shader:sendColor('Color', {r, g, b, a})
---
---Extern variables can be accessed in both the Vertex and Pixel stages of a shader, as long as the variable is declared in each.
---
---Sends colors sourced from the bytes of a Data object, gamma-correcting them if gamma-correct rendering is enabled.
---
---[Open in Browser](https://love2d.org/wiki/Shader:sendColor)
---
---@param name string The name of the color extern variable to send to in the shader.
---@param data love.Data Data object containing the color values to send.
---@param offset (number)? Offset in bytes from the start of the Data object.
---@param size (number)? Size in bytes of the data to send, or nil for as many bytes as the uniform uses.
---@return boolean success Always true.
function Shader:sendColor(name, data, offset, size)
end

---Using a single image, draw any number of identical copies of the image using a single call to love.graphics.draw(). This can be used, for example, to draw repeating copies of a single background image with high performance.
---
---A SpriteBatch can be even more useful when the underlying image is a texture atlas (a single image file containing many independent images); by adding Quads to the batch, different sub-images from within the atlas can be drawn.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch)
---
---@class love.graphics.SpriteBatch: love.graphics.Drawable, love.Object
local SpriteBatch = {}
---@alias love.SpriteBatch love.graphics.SpriteBatch

---Adds a sprite to the batch. Sprites are drawn in the order they are added.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:add)
---
---@param x (number)? The position to draw the object (x-axis).
---@param y (number)? The position to draw the object (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shear factor (x-axis).
---@param ky (number)? Shear factor (y-axis).
---@return number id An identifier for the added sprite.
function SpriteBatch:add(x, y, r, sx, sy, ox, oy, kx, ky)
end

---Adds a sprite to the batch. Sprites are drawn in the order they are added.
---
---Adds a Quad to the batch.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:add)
---
---@param quad love.graphics.Quad The Quad to add.
---@param x (number)? The position to draw the object (x-axis).
---@param y (number)? The position to draw the object (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shear factor (x-axis).
---@param ky (number)? Shear factor (y-axis).
---@return number id An identifier for the added sprite.
function SpriteBatch:add(quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Adds a sprite to the batch. Sprites are drawn in the order they are added.
---
---Adds a sprite positioned by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:add)
---
---@param transform love.math.Transform The transformation to apply to the sprite.
---@return number id An identifier for the added sprite.
function SpriteBatch:add(transform)
end

---Adds a sprite to the batch. Sprites are drawn in the order they are added.
---
---Adds a Quad positioned by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:add)
---
---@param quad love.graphics.Quad The Quad to use for the sprite.
---@param transform love.math.Transform The transformation to apply to the sprite.
---@return number id An identifier for the added sprite.
function SpriteBatch:add(quad, transform)
end

---Adds a sprite to a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:addLayer)
---
---@param layerindex number The index of the layer to use for this sprite.
---@param x (number)? The position to draw the sprite (x-axis).
---@param y (number)? The position to draw the sprite (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
---@return number spriteindex The index of the added sprite, for use with SpriteBatch:set or SpriteBatch:setLayer.
function SpriteBatch:addLayer(layerindex, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Adds a sprite to a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Quad.
---
---The specified layer index overrides any layer index set on the Quad via Quad:setLayer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:addLayer)
---
---@param layerindex number The index of the layer to use for this sprite.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing the sprite.
---@param x (number)? The position to draw the sprite (x-axis).
---@param y (number)? The position to draw the sprite (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
---@return number spriteindex The index of the added sprite, for use with SpriteBatch:set or SpriteBatch:setLayer.
function SpriteBatch:addLayer(layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Adds a sprite to a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Transform.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:addLayer)
---
---@param layerindex number The index of the layer to use for this sprite.
---@param transform love.math.Transform A transform object.
---@return number spriteindex The index of the added sprite, for use with SpriteBatch:set or SpriteBatch:setLayer.
function SpriteBatch:addLayer(layerindex, transform)
end

---Adds a sprite to a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Quad and Transform.
---
---In order to use an Array Texture or other non-2D texture types as the main texture in a custom void effect() variant must be used in the pixel shader, and MainTex must be declared as an ArrayImage or sampler2DArray like so: uniform ArrayImage MainTex;.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:addLayer)
---
---@param layerindex number The index of the layer to use for this sprite.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing the sprite.
---@param transform love.math.Transform A transform object.
---@return number spriteindex The index of the added sprite, for use with SpriteBatch:set or SpriteBatch:setLayer.
function SpriteBatch:addLayer(layerindex, quad, transform)
end

---Attaches a per-vertex attribute from a GraphicsBuffer or Mesh onto this SpriteBatch, for use when drawing. This can be combined with a Shader to augment a SpriteBatch with per-vertex or additional per-sprite information instead of just having per-sprite colors.
---
---Each sprite in a SpriteBatch has 4 vertices in the following order: top-left, bottom-left, top-right, bottom-right. The index returned by SpriteBatch:add (and used by SpriteBatch:set) can used to determine the first vertex of a specific sprite with the formula 1 + 4 * ( id - 1 ).
---
---The attached data must hold at least 4 vertices for every sprite in the SpriteBatch. If the attribute is named VertexPosition, VertexTexCoord or VertexColor, it overrides the SpriteBatch's sprite positions, texture coordinates or sprite colors respectively.
---
---Attaches an attribute from a vertex GraphicsBuffer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:attachAttribute)
---
---@param name string The name of the vertex attribute to attach.
---@param buffer love.graphics.GraphicsBuffer The vertex GraphicsBuffer holding the attribute. It must have been created with vertex buffer support and have a member with the given name.
function SpriteBatch:attachAttribute(name, buffer)
end

---Attaches a per-vertex attribute from a GraphicsBuffer or Mesh onto this SpriteBatch, for use when drawing. This can be combined with a Shader to augment a SpriteBatch with per-vertex or additional per-sprite information instead of just having per-sprite colors.
---
---Each sprite in a SpriteBatch has 4 vertices in the following order: top-left, bottom-left, top-right, bottom-right. The index returned by SpriteBatch:add (and used by SpriteBatch:set) can used to determine the first vertex of a specific sprite with the formula 1 + 4 * ( id - 1 ).
---
---The attached data must hold at least 4 vertices for every sprite in the SpriteBatch. If the attribute is named VertexPosition, VertexTexCoord or VertexColor, it overrides the SpriteBatch's sprite positions, texture coordinates or sprite colors respectively.
---
---Deprecated: use the GraphicsBuffer variant. Attaches an attribute from a Mesh's vertex buffer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:attachAttribute)
---
---@param name string The name of the vertex attribute to attach.
---@param mesh love.graphics.Mesh The Mesh to get the vertex attribute from. It must have its own vertex buffer.
function SpriteBatch:attachAttribute(name, mesh)
end

---Removes all sprites from the buffer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:clear)
---
function SpriteBatch:clear()
end

---Immediately sends all new and modified sprite data in the batch to the graphics card.
---
---Normally it isn't necessary to call this method as love.graphics.draw(spritebatch, ...) will do it automatically if needed, but explicitly using SpriteBatch:flush gives more control over when the work happens.
---
---If this method is used, it generally shouldn't be called more than once (at most) between love.graphics.draw(spritebatch, ...) calls.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:flush)
---
function SpriteBatch:flush()
end

---Gets the maximum number of sprites the SpriteBatch can hold.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:getBufferSize)
---
---@return number size The maximum number of sprites the batch can hold.
function SpriteBatch:getBufferSize()
end

---Gets the color that will be used for the next add and set operations.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:getColor)
---
---@return number r The red component (0-1).
---@return number g The green component (0-1).
---@return number b The blue component (0-1).
---@return number a The alpha component (0-1).
function SpriteBatch:getColor()
end

---Gets the number of sprites currently in the SpriteBatch.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:getCount)
---
---@return number count The number of sprites currently in the batch.
function SpriteBatch:getCount()
end

---Gets the range of sprites drawn by the SpriteBatch, as set by SpriteBatch:setDrawRange. Returns nothing if no draw range is set.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:getDrawRange)
---
---@return number start The index of the first sprite drawn.
---@return number count The number of sprites drawn.
function SpriteBatch:getDrawRange()
end

---Gets the Texture used by the SpriteBatch.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:getTexture)
---
---@return love.graphics.Texture texture The Texture used by the SpriteBatch.
function SpriteBatch:getTexture()
end

---Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or SpriteBatch:addLayer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:set)
---
---@param spriteindex number The index of the sprite that will be changed.
---@param x (number)? The position to draw the object (x-axis).
---@param y (number)? The position to draw the object (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shear factor (x-axis).
---@param ky (number)? Shear factor (y-axis).
function SpriteBatch:set(spriteindex, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or SpriteBatch:addLayer.
---
---Changes a sprite with a Quad in the batch. This requires the index returned by SpriteBatch:add or SpriteBatch:addLayer.
---
---SpriteBatches do not support removing individual sprites. One can do a pseudo removal (instead of clearing and re-adding everything) by:
---
---SpriteBatch:set(id, 0, 0, 0, 0, 0)
---
---This makes all the sprite's vertices equal (because the x and y scales are 0), which prevents the GPU from fully processing the sprite when drawing the SpriteBatch.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:set)
---
---@param spriteindex number The index of the sprite that will be changed.
---@param quad love.graphics.Quad The Quad used on the image of the batch.
---@param x (number)? The position to draw the object (x-axis).
---@param y (number)? The position to draw the object (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shear factor (x-axis).
---@param ky (number)? Shear factor (y-axis).
function SpriteBatch:set(spriteindex, quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or SpriteBatch:addLayer.
---
---Changes a sprite, positioning it by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:set)
---
---@param spriteindex number The index of the sprite that will be changed.
---@param transform love.math.Transform The transformation to apply to the sprite.
function SpriteBatch:set(spriteindex, transform)
end

---Changes a sprite in the batch. This requires the sprite index returned by SpriteBatch:add or SpriteBatch:addLayer.
---
---Changes a sprite with a Quad, positioning it by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:set)
---
---@param spriteindex number The index of the sprite that will be changed.
---@param quad love.graphics.Quad The Quad to use for the sprite.
---@param transform love.math.Transform The transformation to apply to the sprite.
function SpriteBatch:set(spriteindex, quad, transform)
end

---Sets the color that will be used for the next add and set operations.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setColor)
---
---@param r number The amount of red.
---@param g number The amount of green.
---@param b number The amount of blue.
---@param a (number)? The amount of alpha.
function SpriteBatch:setColor(r, g, b, a)
end

---Sets the color that will be used for the next add and set operations.
---
---Sets the color from a table.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setColor)
---
---@param color table The color as a table in the form {red, green, blue, alpha}. Alpha is optional and defaults to 1.
function SpriteBatch:setColor(color)
end

---Restricts the drawn sprites in the SpriteBatch to a subset of the total.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setDrawRange)
---
---@param start number The index of the first sprite to draw. Index 1 corresponds to the first sprite added with SpriteBatch:add.
---@param count number The number of sprites to draw.
function SpriteBatch:setDrawRange(start, count)
end

---Restricts the drawn sprites in the SpriteBatch to a subset of the total.
---
---Allows all sprites in the SpriteBatch to be drawn.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setDrawRange)
---
function SpriteBatch:setDrawRange()
end

---Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
---
---Changes the sprite in the SpriteBatch.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setLayer)
---
---@param spriteindex number The index of the existing sprite to replace.
---@param layerindex number The index of the layer in the Array Texture to use for this sprite.
---@param x (number)? The position to draw the sprite (x-axis).
---@param y (number)? The position to draw the sprite (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function SpriteBatch:setLayer(spriteindex, layerindex, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Quad.
---
---The specified layer index overrides any layer index set on the Quad via Quad:setLayer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setLayer)
---
---@param spriteindex number The index of the existing sprite to replace.
---@param layerindex number The index of the layer to use for this sprite.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing the sprite.
---@param x (number)? The position to draw the sprite (x-axis).
---@param y (number)? The position to draw the sprite (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function SpriteBatch:setLayer(spriteindex, layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Transform.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setLayer)
---
---@param spriteindex number The index of the existing sprite to replace.
---@param layerindex number The index of the layer to use for the sprite.
---@param transform love.math.Transform A transform object.
function SpriteBatch:setLayer(spriteindex, layerindex, transform)
end

---Changes a sprite previously added with add or addLayer, in a batch created with an Array Texture.
---
---Adds a layer of the SpriteBatch's Array Texture using the specified Quad and Transform.
---
---The specified layer index overrides any layer index set on the Quad via Quad:setLayer.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setLayer)
---
---@param spriteindex number The index of the existing sprite to replace.
---@param layerindex number The index of the layer to use for the sprite.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing the sprite.
---@param transform love.math.Transform A transform object.
function SpriteBatch:setLayer(spriteindex, layerindex, quad, transform)
end

---Sets the Texture used for the sprites in the batch, when drawing.
---
---[Open in Browser](https://love2d.org/wiki/SpriteBatch:setTexture)
---
---@param texture love.graphics.Texture The new Texture to use for the sprites in the batch.
function SpriteBatch:setTexture(texture)
end

---Drawable text: a batch of strings laid out with a Font, drawn together with love.graphics.draw.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch)
---
---@class love.graphics.TextBatch: love.graphics.Drawable, love.Object
local TextBatch = {}
---@alias love.TextBatch love.graphics.TextBatch

---Adds additional colored text to the TextBatch at the specified position.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:add)
---
---@param textstring string The text to add to the object.
---@param x (number)? The position of the new text on the x-axis.
---@param y (number)? The position of the new text on the y-axis.
---@param angle (number)? The orientation of the new text in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:add(textstring, x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Adds additional colored text to the TextBatch at the specified position.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text, when drawing the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:add)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param x (number)? The position of the new text on the x-axis.
---@param y (number)? The position of the new text on the y-axis.
---@param angle (number)? The orientation of the new text in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:add(coloredtext, x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Adds additional colored text to the TextBatch at the specified position.
---
---Adds text positioned by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:add)
---
---@param text string|table The text to add: a string, or a table of colors and strings in the form {color1, string1, color2, string2, ...}.
---@param transform love.math.Transform The transformation to apply to the new text.
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:add(text, transform)
end

---Adds additional formatted / colored text to the TextBatch at the specified position.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:addf)
---
---@param textstring string The text to add to the object.
---@param wraplimit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align love.graphics.AlignMode The alignment of the text.
---@param x (number)? The position of the new text (x-axis).
---@param y (number)? The position of the new text (y-axis).
---@param angle (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing / skew factor (x-axis).
---@param ky (number)? Shearing / skew factor (y-axis).
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:addf(textstring, wraplimit, align, x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Adds additional formatted / colored text to the TextBatch at the specified position.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text, when drawing the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:addf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param wraplimit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align love.graphics.AlignMode The alignment of the text.
---@param x (number)? The position of the new text (x-axis).
---@param y (number)? The position of the new text (y-axis).
---@param angle (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing / skew factor (x-axis).
---@param ky (number)? Shearing / skew factor (y-axis).
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:addf(coloredtext, wraplimit, align, x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Adds additional formatted / colored text to the TextBatch at the specified position.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---Adds formatted text positioned by a Transform object.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:addf)
---
---@param text string|table The text to add: a string, or a table of colors and strings in the form {color1, string1, color2, string2, ...}.
---@param wraplimit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align love.graphics.AlignMode The alignment of the text.
---@param transform love.math.Transform The transformation to apply to the new text.
---@return number index An index number that can be used with TextBatch:getWidth or TextBatch:getHeight.
function TextBatch:addf(text, wraplimit, align, transform)
end

---Clears the contents of the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:clear)
---
function TextBatch:clear()
end

---Gets the width and height of the text in pixels.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getDimensions)
---
---@return number width The width of the text. If multiple sub-strings have been added with TextBatch:add, the width of the last sub-string is returned.
---@return number height The height of the text. If multiple sub-strings have been added with TextBatch:add, the height of the last sub-string is returned.
function TextBatch:getDimensions()
end

---Gets the width and height of the text in pixels.
---
---Gets the width and height of a specific sub-string that was previously added to the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getDimensions)
---
---@param index number An index number returned by TextBatch:add or TextBatch:addf.
---@return number width The width of the sub-string (before scaling and other transformations).
---@return number height The height of the sub-string (before scaling and other transformations).
function TextBatch:getDimensions(index)
end

---Gets the Font used with the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getFont)
---
---@return love.graphics.Font font The font used with this TextBatch.
function TextBatch:getFont()
end

---Gets the height of the text in pixels.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getHeight)
---
---@return number height The height of the text. If multiple sub-strings have been added with TextBatch:add, the height of the last sub-string is returned.
function TextBatch:getHeight()
end

---Gets the height of the text in pixels.
---
---Gets the height of a specific sub-string that was previously added to the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getHeight)
---
---@param index number An index number returned by TextBatch:add or TextBatch:addf.
---@return number height The height of the sub-string (before scaling and other transformations).
function TextBatch:getHeight(index)
end

---Gets the width of the text in pixels.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getWidth)
---
---@return number width The width of the text. If multiple sub-strings have been added with TextBatch:add, the width of the last sub-string is returned.
function TextBatch:getWidth()
end

---Gets the width of the text in pixels.
---
---Gets the width of a specific sub-string that was previously added to the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:getWidth)
---
---@param index number An index number returned by TextBatch:add or TextBatch:addf.
---@return number width The width of the sub-string (before scaling and other transformations).
function TextBatch:getWidth(index)
end

---Replaces the contents of the TextBatch with a new unformatted string.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:set)
---
---@param textstring string The new string of text to use.
function TextBatch:set(textstring)
end

---Replaces the contents of the TextBatch with a new unformatted string.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text, when drawing the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:set)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to use as the new text, in the form of {color1, string1, color2, string2, ...}.
function TextBatch:set(coloredtext)
end

---Replaces the Font used with the text.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:setFont)
---
---@param font love.graphics.Font The new font to use with this TextBatch.
function TextBatch:setFont(font)
end

---Replaces the contents of the TextBatch with a new formatted string.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:setf)
---
---@param textstring string The new string of text to use.
---@param wraplimit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align love.graphics.AlignMode The alignment of the text.
function TextBatch:setf(textstring, wraplimit, align)
end

---Replaces the contents of the TextBatch with a new formatted string.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text, when drawing the TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/TextBatch:setf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to use as the new text, in the form of {color1, string1, color2, string2, ...}.
---@param wraplimit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align love.graphics.AlignMode The alignment of the text.
function TextBatch:setf(coloredtext, wraplimit, align)
end

---Superclass for drawable objects which represent a texture. All Textures can be drawn with Quads.
---
---[Open in Browser](https://love2d.org/wiki/Texture)
---
---@class love.graphics.Texture: love.graphics.Drawable, love.Object
local Texture = {}
---@alias love.Texture love.graphics.Texture

---Generates mipmaps for the Texture, based on the contents of the highest-resolution mipmap level.
---
---The Texture must have been created with a MipmapMode other than 'none', and must not be compressed, a depth/stencil or integer format, or an active render target.
---
---If the mipmap mode is 'auto', this is called automatically inside love.graphics.setCanvas when switching away from the Texture as a render target.
---
---[Open in Browser](https://love2d.org/wiki/Texture:generateMipmaps)
---
function Texture:generateMipmaps()
end

---Gets the DPI scale factor of the Texture.
---
---The DPI scale factor represents relative pixel density. A DPI scale factor of 2 means the texture has twice the pixel density in each dimension (4 times as many pixels in the same area) compared to a texture with a DPI scale factor of 1.
---
---For example, a texture with pixel dimensions of 100x100 with a DPI scale factor of 2 will be drawn as if it was 50x50. This is useful with high-dpi /  retina displays to easily allow swapping out higher or lower pixel density Textures without needing any extra manual scaling logic.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getDPIScale)
---
---@return number dpiscale The DPI scale factor of the Texture.
function Texture:getDPIScale()
end

---Gets the debug name the Texture was created with (the 'debugname' setting of love.graphics.newTexture and friends).
---
---[Open in Browser](https://love2d.org/wiki/Texture:getDebugName)
---
---@return string debugname The debug name, or nil if none was set.
function Texture:getDebugName()
end

---Gets the depth of a Volume Texture. Returns 1 for 2D, Cubemap, and Array textures.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getDepth)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number depth The depth of the volume Texture.
function Texture:getDepth(mipmap)
end

---Gets the comparison mode used when sampling from a depth texture in a shader.
---
---Depth texture comparison modes are advanced low-level functionality typically used with shadow mapping in 3D.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getDepthSampleMode)
---
---@return love.graphics.CompareMode compare The comparison mode used when sampling from this texture in a shader, or nil if none is set.
function Texture:getDepthSampleMode()
end

---Gets the width and height of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getDimensions)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number width The width of the Texture.
---@return number height The height of the Texture.
function Texture:getDimensions(mipmap)
end

---Gets the filter mode of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getFilter)
---
---@return love.graphics.FilterMode min Filter mode to use when minifying the texture (rendering it at a smaller size on-screen than its size in pixels).
---@return love.graphics.FilterMode mag Filter mode to use when magnifying the texture (rendering it at a smaller size on-screen than its size in pixels).
---@return number anisotropy Maximum amount of anisotropic filtering used.
function Texture:getFilter()
end

---Gets the pixel format of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getFormat)
---
---@return love.image.PixelFormat format The pixel format the Texture was created with.
function Texture:getFormat()
end

---Gets the height of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getHeight)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number height The height of the Texture.
function Texture:getHeight(mipmap)
end

---Gets the number of layers / slices in an Array Texture. Returns 1 for 2D, Cubemap, and Volume textures.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getLayerCount)
---
---@return number layers The number of layers in the Array Texture.
function Texture:getLayerCount()
end

---Gets the number of multisample antialiasing (MSAA) samples used when drawing to the Texture.
---
---This may be different than the number requested when the Texture was created, if the system running LÖVE doesn't support that number.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getMSAA)
---
---@return number samples The number of multisample antialiasing samples used by the canvas when drawing to it.
function Texture:getMSAA()
end

---Gets the number of mipmaps contained in the Texture. If the texture was not created with mipmaps, it will return 1.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getMipmapCount)
---
---@return number mipmaps The number of mipmaps in the Texture.
function Texture:getMipmapCount()
end

---Gets the mipmap filter mode for a Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getMipmapFilter)
---
---@return love.graphics.MipmapFilterMode mode The filter mode used in between mipmap levels, or 'none' if mipmap filtering is disabled.
---@return number sharpness Value used to determine whether the image should use more or less detailed mipmap levels than normal when drawing.
function Texture:getMipmapFilter()
end

---Gets the MipmapMode this Texture was created with.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getMipmapMode)
---
---@return love.graphics.MipmapMode mode The mipmap mode this Texture was created with.
function Texture:getMipmapMode()
end

---Gets the width and height of the Texture.
---
---The dimensions are in units scaled by the texture's DPI scale factor, rather than pixels. Use getDimensions for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelDimensions only when dealing specifically with pixels, for example when using love.graphics.readbackTexture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getPixelDimensions)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number pixelwidth The width of the Texture, in pixels.
---@return number pixelheight The height of the Texture, in pixels.
function Texture:getPixelDimensions(mipmap)
end

---Gets the height of the Texture.
---
---The height is in units scaled by the texture's DPI scale factor, rather than pixels. Use getHeight for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelHeight only when dealing specifically with pixels, for example when using love.graphics.readbackTexture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getPixelHeight)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number pixelheight The height of the Texture, in pixels.
function Texture:getPixelHeight(mipmap)
end

---Gets the width of the Texture.
---
---The width is in units scaled by the texture's DPI scale factor, rather than pixels. Use getWidth for calculations related to drawing the texture (calculating an origin offset, for example), and getPixelWidth only when dealing specifically with pixels, for example when using love.graphics.readbackTexture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getPixelWidth)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number pixelwidth The width of the Texture, in pixels.
function Texture:getPixelWidth(mipmap)
end

---Gets the type of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getTextureType)
---
---@return love.graphics.TextureType texturetype The type of the Texture.
function Texture:getTextureType()
end

---Gets the width of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getWidth)
---
---@param mipmap (number)? The mipmap level to get the size of, starting at 1.
---@return number width The width of the Texture.
function Texture:getWidth(mipmap)
end

---Gets the wrapping properties of a Texture.
---
---This function returns the currently set horizontal and vertical wrapping modes for the texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getWrap)
---
---@return love.graphics.WrapMode horiz Horizontal wrapping mode of the texture.
---@return love.graphics.WrapMode vert Vertical wrapping mode of the texture.
---@return love.graphics.WrapMode depth Wrapping mode for the z-axis of a Volume texture.
function Texture:getWrap()
end

---Gets the pixel formats that texture views of this Texture may use in addition to its own format (the 'viewformats' setting of love.graphics.newTexture). See love.graphics.newTextureView.
---
---[Open in Browser](https://love2d.org/wiki/Texture:getViewFormats)
---
---@return (love.image.PixelFormat)[] viewformats An array of the extra pixel formats texture views may use.
function Texture:getViewFormats()
end

---Gets whether the Texture has been created with canvas capabilities via love.graphics.newCanvas or love.graphics.newTexture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:isCanvas)
---
---@return boolean canvas True if the Texture can be rendered to with love.graphics.setCanvas, false otherwise.
function Texture:isCanvas()
end

---Gets whether the Texture was created from CompressedData.
---
---Compressed images take up less space in VRAM, and drawing a compressed image will generally be more efficient than drawing one created from raw pixel data.
---
---[Open in Browser](https://love2d.org/wiki/Texture:isCompressed)
---
---@return boolean compressed Whether the Texture is stored as a compressed texture on the GPU.
function Texture:isCompressed()
end

---Gets whether the Texture can be written to by compute shaders, as set by the 'computewrite' setting when it was created.
---
---[Open in Browser](https://love2d.org/wiki/Texture:isComputeWritable)
---
---@return boolean computewrite True if compute shaders can write to the Texture.
function Texture:isComputeWritable()
end

---Gets whether the Texture was created with the linear (non-gamma corrected) flag set to true.
---
---This method always returns false when gamma-correct rendering is not enabled.
---
---[Open in Browser](https://love2d.org/wiki/Texture:isFormatLinear)
---
---@return boolean linear Whether the Texture's internal pixel format is linear (not gamma corrected), when gamma-correct rendering is enabled.
function Texture:isFormatLinear()
end

---Gets whether the Texture can be drawn and sent to a Shader.
---
---Render target Textures with stencil and/or depth PixelFormats are not readable by default, unless readable=true is specified in the settings table passed into love.graphics.newCanvas or love.graphics.newTexture.
---
---Non-readable Textures can still be rendered to.
---
---[Open in Browser](https://love2d.org/wiki/Texture:isReadable)
---
---@return boolean readable Whether the Texture is readable.
function Texture:isReadable()
end

---Renders to the Texture using a function. The Texture must be a render target (created as a canvas). The previous render targets are restored afterwards.
---
---This is a shortcut to love.graphics.setCanvas:
---
---texture:renderTo( func )
---
---is the same as
---
---love.graphics.setCanvas( texture )
---
---func()
---
---love.graphics.setCanvas()
---
---Renders to a 2D Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:renderTo)
---
---@param func fun(...: any) A function performing drawing operations.
---@param ... any Additional arguments to call the function with.
function Texture:renderTo(func, ...)
end

---Renders to the Texture using a function. The Texture must be a render target (created as a canvas). The previous render targets are restored afterwards.
---
---This is a shortcut to love.graphics.setCanvas:
---
---texture:renderTo( func )
---
---is the same as
---
---love.graphics.setCanvas( texture )
---
---func()
---
---love.graphics.setCanvas()
---
---Renders to one slice of a cube, array, or volume Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:renderTo)
---
---@param slice number The cubemap face, array layer, or volume layer to render to.
---@param func fun(...: any) A function performing drawing operations.
---@param ... any Additional arguments to call the function with.
function Texture:renderTo(slice, func, ...)
end

---Replaces the contents of a Texture, or a region of it, with pixel data.
---
---[Open in Browser](https://love2d.org/wiki/Texture:replacePixels)
---
---@param data love.image.ImageData The new ImageData to replace the contents with.
---@param slice (number)? Which cubemap face, array layer, or volume layer to replace. Required for non-2D textures, and ignored for 2D textures.
---@param mipmap (number)? The mipmap level to replace, if the Texture has mipmaps.
---@param x (number)? The x-offset in pixels from the top-left of the texture to replace. The data's width plus this value must not be greater than the pixel width of the Texture's specified mipmap level.
---@param y (number)? The y-offset in pixels from the top-left of the texture to replace. Required if x is given. The data's height plus this value must not be greater than the pixel height of the Texture's specified mipmap level.
---@param reloadmipmaps (boolean)? Whether to generate new mipmaps after replacing the pixels. Only used when x and y are given, and only takes effect if the Texture was created with automatically generated mipmaps. Defaults to true for such Textures.
function Texture:replacePixels(data, slice, mipmap, x, y, reloadmipmaps)
end

---Replaces the contents of a Texture, or a region of it, with pixel data.
---
---Replaces the contents with a mipmap level of compressed pixel data.
---
---[Open in Browser](https://love2d.org/wiki/Texture:replacePixels)
---
---@param data love.image.CompressedImageData The new CompressedImageData to replace the contents with. Its format must match the Texture's format.
---@param slice (number)? Which cubemap face, array layer, or volume layer to replace. Required for non-2D textures, and ignored for 2D textures.
---@param mipmap (number)? The mipmap level to replace, if the Texture has mipmaps.
---@param x (number)? The x-offset in pixels from the top-left of the texture to replace. The data's width plus this value must not be greater than the pixel width of the Texture's specified mipmap level.
---@param y (number)? The y-offset in pixels from the top-left of the texture to replace. Required if x is given. The data's height plus this value must not be greater than the pixel height of the Texture's specified mipmap level.
---@param reloadmipmaps (boolean)? Whether to generate new mipmaps after replacing the pixels. Only used when x and y are given, and only takes effect if the Texture was created with automatically generated mipmaps. Defaults to true for such Textures.
---@param srcmipmap (number)? The mipmap level of data to copy from. Required if data has more than one mipmap level.
function Texture:replacePixels(data, slice, mipmap, x, y, reloadmipmaps, srcmipmap)
end

---Sets the comparison mode used when sampling from a depth texture in a shader. Depth texture comparison modes are advanced low-level functionality typically used with shadow mapping in 3D.
---
---When using a depth texture with a comparison mode set in a shader, it must be declared as a sampler2DShadow. The result of accessing the texture in the shader will return a float between 0 and 1, proportional to the number of samples (up to 4 samples will be used if bilinear filtering is enabled) that passed the test set by the comparison operation.
---
---Depth texture comparison can only be used with readable depth-formatted textures.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setDepthSampleMode)
---
---@param compare love.graphics.CompareMode The comparison mode used when sampling from this texture in a shader.
function Texture:setDepthSampleMode(compare)
end

---Sets the comparison mode used when sampling from a depth texture in a shader. Depth texture comparison modes are advanced low-level functionality typically used with shadow mapping in 3D.
---
---When using a depth texture with a comparison mode set in a shader, it must be declared as a sampler2DShadow. The result of accessing the texture in the shader will return a float between 0 and 1, proportional to the number of samples (up to 4 samples will be used if bilinear filtering is enabled) that passed the test set by the comparison operation.
---
---Depth texture comparison can only be used with readable depth-formatted textures.
---
---Removes the comparison mode, so sampling returns the depth values.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setDepthSampleMode)
---
function Texture:setDepthSampleMode()
end

---Sets the filter mode of the Texture.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setFilter)
---
---@param min love.graphics.FilterMode Filter mode to use when minifying the texture (rendering it at a smaller size on-screen than its size in pixels).
---@param mag (love.graphics.FilterMode)? Filter mode to use when magnifying the texture (rendering it at a larger size on-screen than its size in pixels).
---@param anisotropy (number)? Maximum amount of anisotropic filtering to use.
function Texture:setFilter(min, mag, anisotropy)
end

---Sets the mipmap filter mode for a Texture.
---
---Mipmapping is useful when drawing a texture at a reduced scale. It can improve performance and reduce aliasing issues. The Texture must have mipmaps for the mipmap filter to have any effect.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setMipmapFilter)
---
---@param filtermode love.graphics.MipmapFilterMode The filter mode to use in between mipmap levels. 'nearest' will often give better performance, and 'none' disables mipmap filtering.
---@param sharpness (number)? A positive sharpness value makes the texture use a more detailed mipmap level when drawing, at the expense of performance. A negative value does the reverse. Not supported on mobile devices.
function Texture:setMipmapFilter(filtermode, sharpness)
end

---Sets the mipmap filter mode for a Texture.
---
---Mipmapping is useful when drawing a texture at a reduced scale. It can improve performance and reduce aliasing issues. The Texture must have mipmaps for the mipmap filter to have any effect.
---
---Disables mipmap filtering.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setMipmapFilter)
---
function Texture:setMipmapFilter()
end

---Sets the wrapping properties of a Texture.
---
---This function sets the way a Texture is repeated when it is drawn with a Quad that is larger than the texture's extent, or when a custom Shader is used which uses texture coordinates outside of [0, 1]. A texture may be clamped or set to repeat in both horizontal and vertical directions.
---
---Clamped textures appear only once (with the edges of the texture stretching to fill the extent of the Quad), whereas repeated ones repeat as many times as there is room in the Quad.
---
---[Open in Browser](https://love2d.org/wiki/Texture:setWrap)
---
---@param horiz love.graphics.WrapMode Horizontal wrapping mode of the texture.
---@param vert (love.graphics.WrapMode)? Vertical wrapping mode of the texture.
---@param depth (love.graphics.WrapMode)? Wrapping mode for the z-axis of a Volume texture.
function Texture:setWrap(horiz, vert, depth)
end

---Deprecated: use love.graphics.readbackTexture. Copies the contents of the Texture, or a region of it, from the GPU into a new ImageData.
---
---[Open in Browser](https://love2d.org/wiki/Texture:newImageData)
---
---@param slice (number)? The cubemap face, array layer, or volume layer to read. Required for non-2D textures, and ignored for 2D textures.
---@param mipmap (number)? The mipmap level to read.
---@param x (number)? The x-coordinate of the top-left corner of the region to read.
---@param y (number)? The y-coordinate of the top-left corner of the region to read. Required if x is given.
---@param width (number)? The width of the region to read. Required if x is given.
---@param height (number)? The height of the region to read. Required if x is given.
---@return love.image.ImageData imagedata The new ImageData holding the read-back pixels.
function Texture:newImageData(slice, mipmap, x, y, width, height)
end

---A drawable video.
---
---[Open in Browser](https://love2d.org/wiki/Video)
---
---@class love.graphics.Video: love.graphics.Drawable, love.Object
local Video = {}
---@alias love.Video love.graphics.Video

---Gets the width and height of the Video, in units scaled by the Video's DPI scale (the 'dpiscale' setting of love.graphics.newVideo).
---
---[Open in Browser](https://love2d.org/wiki/Video:getDimensions)
---
---@return number width The width of the Video.
---@return number height The height of the Video.
function Video:getDimensions()
end

---Gets the scaling filters used when drawing the Video.
---
---[Open in Browser](https://love2d.org/wiki/Video:getFilter)
---
---@return love.graphics.FilterMode min The filter mode used when scaling the Video down.
---@return love.graphics.FilterMode mag The filter mode used when scaling the Video up.
---@return number anisotropy Maximum amount of anisotropic filtering used.
function Video:getFilter()
end

---Gets the height of the Video, in units scaled by the Video's DPI scale.
---
---[Open in Browser](https://love2d.org/wiki/Video:getHeight)
---
---@return number height The height of the Video.
function Video:getHeight()
end

---Gets the width and height of the Video in pixels, as decoded by its VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/Video:getPixelDimensions)
---
---@return number pixelwidth The width of the Video in pixels.
---@return number pixelheight The height of the Video in pixels.
function Video:getPixelDimensions()
end

---Gets the height of the Video in pixels, as decoded by its VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/Video:getPixelHeight)
---
---@return number pixelheight The height of the Video in pixels.
function Video:getPixelHeight()
end

---Gets the width of the Video in pixels, as decoded by its VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/Video:getPixelWidth)
---
---@return number pixelwidth The width of the Video in pixels.
function Video:getPixelWidth()
end

---Gets the audio Source used for playing back the video's audio. May return nil if the video has no audio, or if Video:setSource is called with a nil argument.
---
---[Open in Browser](https://love2d.org/wiki/Video:getSource)
---
---@return love.audio.Source source The audio Source used for audio playback, or nil if the video has no audio.
function Video:getSource()
end

---Gets the VideoStream object used for decoding and controlling the video.
---
---[Open in Browser](https://love2d.org/wiki/Video:getStream)
---
---@return love.video.VideoStream stream The VideoStream used for decoding and controlling the video.
function Video:getStream()
end

---Gets the width of the Video, in units scaled by the Video's DPI scale.
---
---[Open in Browser](https://love2d.org/wiki/Video:getWidth)
---
---@return number width The width of the Video.
function Video:getWidth()
end

---Gets whether the Video is currently playing.
---
---[Open in Browser](https://love2d.org/wiki/Video:isPlaying)
---
---@return boolean playing Whether the video is playing.
function Video:isPlaying()
end

---Pauses the Video.
---
---[Open in Browser](https://love2d.org/wiki/Video:pause)
---
function Video:pause()
end

---Starts playing the Video. In order for the video to appear onscreen it must be drawn with love.graphics.draw.
---
---[Open in Browser](https://love2d.org/wiki/Video:play)
---
function Video:play()
end

---Rewinds the Video to the beginning.
---
---[Open in Browser](https://love2d.org/wiki/Video:rewind)
---
function Video:rewind()
end

---Sets the current playback position of the Video.
---
---[Open in Browser](https://love2d.org/wiki/Video:seek)
---
---@param offset number The time in seconds since the beginning of the Video.
function Video:seek(offset)
end

---Sets the scaling filters used when drawing the Video.
---
---[Open in Browser](https://love2d.org/wiki/Video:setFilter)
---
---@param min love.graphics.FilterMode The filter mode used when scaling the Video down.
---@param mag (love.graphics.FilterMode)? The filter mode used when scaling the Video up. Defaults to min.
---@param anisotropy (number)? Maximum amount of anisotropic filtering used.
function Video:setFilter(min, mag, anisotropy)
end

---Sets the audio Source used for playing back the video's audio, and syncs the VideoStream to it. The audio Source also controls playback speed and synchronization.
---
---[Open in Browser](https://love2d.org/wiki/Video:setSource)
---
---@param source (love.audio.Source)? The audio Source used for audio playback, or nil to disable audio synchronization.
function Video:setSource(source)
end

---Gets the current playback position of the Video.
---
---[Open in Browser](https://love2d.org/wiki/Video:tell)
---
---@return number seconds The time in seconds since the beginning of the Video.
function Video:tell()
end

---Applies the given Transform object to the current coordinate transformation.
---
---This effectively multiplies the existing coordinate transformation's matrix with the Transform object's internal matrix to produce the new coordinate transformation.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.applyTransform)
---
---@param transform love.math.Transform The Transform object to apply to the current graphics coordinate transform.
function love.graphics.applyTransform(transform)
end

---Applies the given Transform object to the current coordinate transformation.
---
---This effectively multiplies the existing coordinate transformation's matrix with the Transform object's internal matrix to produce the new coordinate transformation.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.applyTransform)
---
---@param x number The position of the new Transform on the x-axis.
---@param y number The position of the new Transform on the y-axis.
---@param angle (number)? The orientation of the new Transform in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
function love.graphics.applyTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Draws a filled or unfilled arc at position (x, y). The arc is drawn from angle1 to angle2 in radians.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.arc)
---
---@param drawmode love.graphics.DrawMode How to draw the arc.
---@param arctype (love.graphics.ArcType)? The type of arc to draw.
---@param x number The position of the center along the x-axis.
---@param y number The position of the center along the y-axis.
---@param radius number Radius of the arc.
---@param angle1 number The angle at which the arc begins.
---@param angle2 number The angle at which the arc terminates.
---@param segments (number)? The number of segments used for drawing the arc. A default amount is chosen when not given.
function love.graphics.arc(drawmode, arctype, x, y, radius, angle1, angle2, segments)
end

---Creates a screenshot once the current frame is done (after love.draw has finished).
---
---Since this function enqueues a screenshot capture rather than executing it immediately, it can be called from an input callback or love.update and it will still capture all of what's drawn to the screen in that frame.
---
---Capture a screenshot and save it to a file at the end of the current frame.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.captureScreenshot)
---
---@param filename string The filename to save the screenshot to. The encoded image type is determined based on the extension of the filename, and must be one of the ImageFormats.
function love.graphics.captureScreenshot(filename)
end

---Creates a screenshot once the current frame is done (after love.draw has finished).
---
---Since this function enqueues a screenshot capture rather than executing it immediately, it can be called from an input callback or love.update and it will still capture all of what's drawn to the screen in that frame.
---
---Capture a screenshot and call a callback with the generated ImageData at the end of the current frame.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.captureScreenshot)
---
---@param callback fun(imageData: love.image.ImageData) Function which gets called once the screenshot has been captured. An ImageData is passed into the function as its only argument.
function love.graphics.captureScreenshot(callback)
end

---Creates a screenshot once the current frame is done (after love.draw has finished).
---
---Since this function enqueues a screenshot capture rather than executing it immediately, it can be called from an input callback or love.update and it will still capture all of what's drawn to the screen in that frame.
---
---Capture a screenshot and push the generated ImageData to a Channel at the end of the current frame.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.captureScreenshot)
---
---@param channel love.thread.Channel The Channel to push the generated ImageData to.
function love.graphics.captureScreenshot(channel)
end

---Draws a circle.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.circle)
---
---@param mode love.graphics.DrawMode How to draw the circle.
---@param x number The position of the center along x-axis.
---@param y number The position of the center along y-axis.
---@param radius number The radius of the circle.
---@param segments (number)? The number of segments used for drawing the circle. A default amount is chosen when not given.
function love.graphics.circle(mode, x, y, radius, segments)
end

---Clears the active render targets (or the screen) to a color, and clears the stencil and depth buffers.
---
---The scissor and color mask limit what is cleared.
---
---Clears to transparent black, the stencil buffer to 0 and the depth buffer to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.clear)
---
function love.graphics.clear()
end

---Clears the active render targets (or the screen) to a color, and clears the stencil and depth buffers.
---
---The scissor and color mask limit what is cleared.
---
---Clears all active color render targets to the given color.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.clear)
---
---@param r number The red channel of the color to clear to.
---@param g number The green channel of the color to clear to.
---@param b number The blue channel of the color to clear to.
---@param a (number)? The alpha channel of the color to clear to.
---@param stencil (boolean|number)? The value to clear the stencil buffer to, or false to leave it alone.
---@param depth (boolean|number)? The value to clear the depth buffer to, or false to leave it alone.
function love.graphics.clear(r, g, b, a, stencil, depth)
end

---Clears the active render targets (or the screen) to a color, and clears the stencil and depth buffers.
---
---The scissor and color mask limit what is cleared.
---
---Clears each active render target to its own color. A nil or empty table leaves that render target alone.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.clear)
---
---@param color (number)[] The color for the first render target, as {r, g, b, a}. The alpha defaults to 1.
---@param ... table|boolean|number Colors for the other render targets as {r, g, b, a} tables, optionally followed by the stencil value (default 0) and the depth value (default 1). A stencil or depth value of false leaves that buffer alone.
function love.graphics.clear(color, ...)
end

---Clears the active render targets (or the screen) to a color, and clears the stencil and depth buffers.
---
---The scissor and color mask limit what is cleared.
---
---Chooses which buffers to clear, using transparent black, stencil 0 and depth 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.clear)
---
---@param clearcolor boolean Whether to clear the color render targets.
---@param stencil (boolean|number)? The value to clear the stencil buffer to, or false to leave it alone.
---@param depth (boolean|number)? The value to clear the depth buffer to, or false to leave it alone.
function love.graphics.clear(clearcolor, stencil, depth)
end

---Copies bytes from one GraphicsBuffer to another on the GPU.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.copyBuffer)
---
---@param source love.graphics.GraphicsBuffer The buffer to copy from.
---@param dest love.graphics.GraphicsBuffer The buffer to copy to.
---@param sourceoffset (number)? The byte offset in the source buffer to start copying from.
---@param destoffset (number)? The byte offset in the destination buffer to copy to.
---@param size (number)? The number of bytes to copy. Defaults to as many as fit in both buffers after their offsets.
function love.graphics.copyBuffer(source, dest, sourceoffset, destoffset, size)
end

---Copies pixel data from a GraphicsBuffer into a region of a Texture on the GPU.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.copyBufferToTexture)
---
---@param source love.graphics.GraphicsBuffer The buffer to copy from.
---@param dest love.graphics.Texture The texture to copy to.
---@param sourceoffset (number)? The byte offset in the source buffer to start copying from.
---@param sourcewidth (number)? The width in pixels of each row in the source buffer. 0 means the width of the copied region.
---@param slice (number)? The cube face, array layer or volume slice to copy to. Required for non-2D textures, ignored for 2D textures.
---@param mipmap (number)? The mipmap level to copy to.
---@param x (number)? The x position of the destination region. The region is the whole mipmap level when x is not given.
---@param y (number)? The y position of the destination region. Required when x is given.
---@param width (number)? The width of the destination region. Required when x is given.
---@param height (number)? The height of the destination region. Required when x is given.
function love.graphics.copyBufferToTexture(source, dest, sourceoffset, sourcewidth, slice, mipmap, x, y, width, height)
end

---Copies pixels from a region of a Texture into a GraphicsBuffer on the GPU. Requires the copytexturetobuffer GraphicsFeature.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.copyTextureToBuffer)
---
---@param source love.graphics.Texture The texture to copy from.
---@param dest love.graphics.GraphicsBuffer The buffer to copy to.
---@param slice (number)? The cube face, array layer or volume slice to copy from. Required for non-2D textures, ignored for 2D textures.
---@param mipmap (number)? The mipmap level to copy from.
---@param x (number)? The x position of the source region. The region is the whole mipmap level when x is not given.
---@param y (number)? The y position of the source region. Required when x is given.
---@param width (number)? The width of the source region. Required when x is given.
---@param height (number)? The height of the source region. Required when x is given.
---@param destoffset (number)? The byte offset in the destination buffer to copy to.
---@param destwidth (number)? The width in pixels of each row in the destination buffer. 0 means the width of the copied region.
function love.graphics.copyTextureToBuffer(source, dest, slice, mipmap, x, y, width, height, destoffset, destwidth)
end

---Discards the contents of the active render targets or screen. Pixels are undefined afterwards until drawn to, which can be faster than clearing on some hardware.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.discard)
---
---@param discardcolor (boolean)? Whether to discard the contents of every active color render target.
---@param discarddepthstencil (boolean)? Whether to discard the contents of the depth and stencil buffers.
function love.graphics.discard(discardcolor, discarddepthstencil)
end

---Discards the contents of the active render targets or screen. Pixels are undefined afterwards until drawn to, which can be faster than clearing on some hardware.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.discard)
---
---@param discardcolors (boolean)[] Whether to discard each active color render target, in order. Missing entries count as true.
---@param discarddepthstencil (boolean)? Whether to discard the contents of the depth and stencil buffers.
function love.graphics.discard(discardcolors, discarddepthstencil)
end

---Runs a compute Shader with thread group counts read from a GraphicsBuffer. Requires the indirectdraw GraphicsFeature.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.dispatchIndirect)
---
---@param computeshader love.graphics.Shader A Shader with a compute stage.
---@param argsbuffer love.graphics.GraphicsBuffer A buffer created with the indirectarguments usage flag, holding the thread group counts.
---@param argsindex (number)? The index of the arguments in the buffer, starting at 1.
function love.graphics.dispatchIndirect(computeshader, argsbuffer, argsindex)
end

---Runs a compute Shader with the given number of thread groups in each dimension. Each thread group runs the shader's local threadgroup size of invocations.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.dispatchThreadgroups)
---
---@param computeshader love.graphics.Shader A Shader with a compute stage.
---@param groupsx number The number of thread groups in the x dimension.
---@param groupsy (number)? The number of thread groups in the y dimension.
---@param groupsz (number)? The number of thread groups in the z dimension.
function love.graphics.dispatchThreadgroups(computeshader, groupsx, groupsy, groupsz)
end

---Draws a Drawable object (a Texture, Mesh, SpriteBatch, ParticleSystem, TextBatch or Video), or part of a Texture given by a Quad, on the screen with optional rotation, scaling and shearing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.draw)
---
---@param drawable love.graphics.Drawable A drawable object.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws a Drawable object (a Texture, Mesh, SpriteBatch, ParticleSystem, TextBatch or Video), or part of a Texture given by a Quad, on the screen with optional rotation, scaling and shearing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.draw)
---
---@param texture love.graphics.Texture A Texture to texture the Quad with.
---@param quad love.graphics.Quad The Quad to draw on screen.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.draw(texture, quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws a Drawable object (a Texture, Mesh, SpriteBatch, ParticleSystem, TextBatch or Video), or part of a Texture given by a Quad, on the screen with optional rotation, scaling and shearing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.draw)
---
---@param drawable love.graphics.Drawable A drawable object.
---@param transform love.math.Transform Transformation object.
function love.graphics.draw(drawable, transform)
end

---Draws a Drawable object (a Texture, Mesh, SpriteBatch, ParticleSystem, TextBatch or Video), or part of a Texture given by a Quad, on the screen with optional rotation, scaling and shearing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.draw)
---
---@param texture love.graphics.Texture A Texture to texture the Quad with.
---@param quad love.graphics.Quad The Quad to draw on screen.
---@param transform love.math.Transform Transformation object.
function love.graphics.draw(texture, quad, transform)
end

---Draws primitives whose vertex positions are computed entirely by the active vertex shader, without a Mesh or vertex buffer.
---
---Draws with vertex indices from an index buffer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawFromShader)
---
---@param indexbuffer love.graphics.GraphicsBuffer A buffer created with the index usage flag.
---@param indexcount number The number of indices to draw.
---@param instancecount (number)? The number of instances to draw.
---@param indexstart (number)? The first index in the index buffer to draw, starting at 1.
---@param texture (love.graphics.Texture)? The texture to make available to the shader as MainTex.
function love.graphics.drawFromShader(indexbuffer, indexcount, instancecount, indexstart, texture)
end

---Draws primitives whose vertex positions are computed entirely by the active vertex shader, without a Mesh or vertex buffer.
---
---Draws without an index buffer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawFromShader)
---
---@param primitivetype love.graphics.MeshDrawMode The type of primitives to draw.
---@param vertexcount number The number of vertices to draw.
---@param instancecount (number)? The number of instances to draw.
---@param texture (love.graphics.Texture)? The texture to make available to the shader as MainTex.
function love.graphics.drawFromShader(primitivetype, vertexcount, instancecount, texture)
end

---Draws primitives whose vertex positions are computed by the active vertex shader, using draw arguments stored in a GraphicsBuffer. Requires the indirectdraw GraphicsFeature.
---
---Draws with vertex indices from an index buffer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawFromShaderIndirect)
---
---@param indexbuffer love.graphics.GraphicsBuffer A buffer created with the index usage flag.
---@param argsbuffer love.graphics.GraphicsBuffer A buffer created with the indirectarguments usage flag, holding the draw arguments.
---@param argsindex (number)? The index of the draw arguments in the buffer, starting at 1.
---@param texture (love.graphics.Texture)? The texture to make available to the shader as MainTex.
function love.graphics.drawFromShaderIndirect(indexbuffer, argsbuffer, argsindex, texture)
end

---Draws primitives whose vertex positions are computed by the active vertex shader, using draw arguments stored in a GraphicsBuffer. Requires the indirectdraw GraphicsFeature.
---
---Draws without an index buffer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawFromShaderIndirect)
---
---@param primitivetype love.graphics.MeshDrawMode The type of primitives to draw.
---@param argsbuffer love.graphics.GraphicsBuffer A buffer created with the indirectarguments usage flag, holding the draw arguments.
---@param argsindex (number)? The index of the draw arguments in the buffer, starting at 1.
---@param texture (love.graphics.Texture)? The texture to make available to the shader as MainTex.
function love.graphics.drawFromShaderIndirect(primitivetype, argsbuffer, argsindex, texture)
end

---Draws many instances of a Mesh with a single draw call, using draw arguments stored in a GraphicsBuffer. Requires the indirectdraw GraphicsFeature and a custom vertex shader to position the instances.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawIndirect)
---
---@param mesh love.graphics.Mesh The mesh to render.
---@param argsbuffer love.graphics.GraphicsBuffer A buffer created with the indirectarguments usage flag, holding the draw arguments.
---@param argsindex number The index of the draw arguments in the buffer, starting at 1.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.drawIndirect(mesh, argsbuffer, argsindex, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws many instances of a Mesh with a single draw call, using draw arguments stored in a GraphicsBuffer. Requires the indirectdraw GraphicsFeature and a custom vertex shader to position the instances.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawIndirect)
---
---@param mesh love.graphics.Mesh The mesh to render.
---@param argsbuffer love.graphics.GraphicsBuffer A buffer created with the indirectarguments usage flag, holding the draw arguments.
---@param argsindex number The index of the draw arguments in the buffer, starting at 1.
---@param transform love.math.Transform Transformation object.
function love.graphics.drawIndirect(mesh, argsbuffer, argsindex, transform)
end

---Draws many instances of a Mesh with a single draw call, using hardware geometry instancing.
---
---Each instance can have unique properties (positions, colors, etc.) but will not by default unless a custom per-instance vertex attributes or the love_InstanceID GLSL 3 vertex shader variable is used, otherwise they will all render at the same position on top of each other.
---
---Instancing is not supported by some older GPUs that are only capable of using OpenGL ES 2 or OpenGL 2. Use love.graphics.getSupported to check.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawInstanced)
---
---@param mesh love.graphics.Mesh The mesh to render.
---@param instancecount number The number of instances to render.
---@param x (number)? The position to draw the instances (x-axis).
---@param y (number)? The position to draw the instances (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.drawInstanced(mesh, instancecount, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws many instances of a Mesh with a single draw call, using hardware geometry instancing.
---
---Each instance can have unique properties (positions, colors, etc.) but will not by default unless a custom per-instance vertex attributes or the love_InstanceID GLSL 3 vertex shader variable is used, otherwise they will all render at the same position on top of each other.
---
---Instancing is not supported by some older GPUs that are only capable of using OpenGL ES 2 or OpenGL 2. Use love.graphics.getSupported to check.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawInstanced)
---
---@param mesh love.graphics.Mesh The mesh to render.
---@param instancecount number The number of instances to render.
---@param transform love.math.Transform A transform object.
function love.graphics.drawInstanced(mesh, instancecount, transform)
end

---Draws a layer of an Array Texture.
---
---Draws a layer of an Array Texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawLayer)
---
---@param texture love.graphics.Texture The Array Texture to draw.
---@param layerindex number The index of the layer to use when drawing.
---@param x (number)? The position to draw the texture (x-axis).
---@param y (number)? The position to draw the texture (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.drawLayer(texture, layerindex, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws a layer of an Array Texture.
---
---Draws a layer of an Array Texture using the specified Quad.
---
---The specified layer index overrides any layer index set on the Quad via Quad:setLayer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawLayer)
---
---@param texture love.graphics.Texture The Array Texture to draw.
---@param layerindex number The index of the layer to use when drawing.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing.
---@param x (number)? The position to draw the texture (x-axis).
---@param y (number)? The position to draw the texture (y-axis).
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.drawLayer(texture, layerindex, quad, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws a layer of an Array Texture.
---
---Draws a layer of an Array Texture using the specified Transform.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawLayer)
---
---@param texture love.graphics.Texture The Array Texture to draw.
---@param layerindex number The index of the layer to use when drawing.
---@param transform love.math.Transform A transform object.
function love.graphics.drawLayer(texture, layerindex, transform)
end

---Draws a layer of an Array Texture.
---
---Draws a layer of an Array Texture using the specified Quad and Transform.
---
---In order to use an Array Texture or other non-2D texture types as the main texture in a custom void effect() variant must be used in the pixel shader, and MainTex must be declared as an ArrayImage or sampler2DArray like so: uniform ArrayImage MainTex;.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.drawLayer)
---
---@param texture love.graphics.Texture The Array Texture to draw.
---@param layerindex number The index of the layer to use when drawing.
---@param quad love.graphics.Quad The subsection of the texture's layer to use when drawing.
---@param transform love.math.Transform A transform object.
function love.graphics.drawLayer(texture, layerindex, quad, transform)
end

---Draws an ellipse.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.ellipse)
---
---@param mode love.graphics.DrawMode How to draw the ellipse.
---@param x number The position of the center along x-axis.
---@param y number The position of the center along y-axis.
---@param radiusx number The radius of the ellipse along the x-axis (half the ellipse's width).
---@param radiusy (number)? The radius of the ellipse along the y-axis (half the ellipse's height).
---@param segments (number)? The number of segments used for drawing the ellipse. A default amount is chosen when not given.
function love.graphics.ellipse(mode, x, y, radiusx, radiusy, segments)
end

---Immediately renders any pending automatically batched draws.
---
---LÖVE will call this function internally as needed when most state is changed, so it is not necessary to manually call it.
---
---The current batch will be automatically flushed by love.graphics state changes (except for the transform stack and the current color), as well as Shader:send and methods on Textures which change their state. Using a different Image in consecutive love.graphics.draw calls will also flush the current batch.
---
---SpriteBatches, ParticleSystems, Meshes, and Text objects do their own batching and do not affect automatic batching of other draws, aside from flushing the current batch when they're drawn.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.flushBatch)
---
function love.graphics.flushBatch()
end

---Gets the current background color.
---
---In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getBackgroundColor)
---
---@return number r The red component (0-1).
---@return number g The green component (0-1).
---@return number b The blue component (0-1).
---@return number a The alpha component (0-1).
function love.graphics.getBackgroundColor()
end

---Gets the blending mode.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getBlendMode)
---
---@return love.graphics.BlendMode mode The current blend mode.
---@return love.graphics.BlendAlphaMode alphamode The current blend alpha mode – it determines how the alpha of drawn objects affects blending.
function love.graphics.getBlendMode()
end

---Gets the low-level blend state set by love.graphics.setBlendState or love.graphics.setBlendMode.
---
---Every value is nil when blending is disabled.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getBlendState)
---
---@return love.graphics.BlendOperation operationRGB The blend operation for RGB.
---@return love.graphics.BlendOperation operationA The blend operation for alpha.
---@return love.graphics.BlendFactor srcFactorRGB The blend factor for source RGB.
---@return love.graphics.BlendFactor srcFactorA The blend factor for source alpha.
---@return love.graphics.BlendFactor dstFactorRGB The blend factor for destination RGB.
---@return love.graphics.BlendFactor dstFactorA The blend factor for destination alpha.
function love.graphics.getBlendState()
end

---Gets the current render targets.
---
---Returns nil when drawing to the screen. Otherwise, when every target is a 2D texture at mipmap level 1 with no depth/stencil texture and no shaderlayer, returns each target Texture as its own value.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getCanvas)
---
---@return love.graphics.Texture canvas The first render target, or nil if drawing to the screen.
---@return love.graphics.Texture ... The other active render targets.
function love.graphics.getCanvas()
end

---Gets the current render targets.
---
---Otherwise returns a single table in the same form love.graphics.setCanvas accepts.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getCanvas)
---
---@return {[1]: love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?}, depthstencil: (love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?})?, shaderlayer: (boolean)?, [integer]: love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?}} setup The active render targets.
function love.graphics.getCanvas()
end

---Deprecated: use love.graphics.getTextureFormats. Gets which uncompressed pixel formats render target Textures can use.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getCanvasFormats)
---
---@param readable (boolean)? If given, checks render targets that are (true) or are not (false) sampled in shaders. When left out, depth/stencil formats are checked as not readable and others as readable.
---@param formats (table)? An existing table to fill in and return instead of creating a new one.
---@return table formats A table with PixelFormat keys and boolean values.
function love.graphics.getCanvasFormats(readable, formats)
end

---Gets the current color.
---
---In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getColor)
---
---@return number r The red component (0-1).
---@return number g The green component (0-1).
---@return number b The blue component (0-1).
---@return number a The alpha component (0-1).
function love.graphics.getColor()
end

---Gets the active color components used when drawing. Normally all 4 components are active unless love.graphics.setColorMask has been used.
---
---The color mask determines whether individual components of the colors of drawn objects will affect the color of the screen. They affect love.graphics.clear and Canvas:clear as well.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getColorMask)
---
---@return boolean r Whether the red color component is active when rendering.
---@return boolean g Whether the green color component is active when rendering.
---@return boolean b Whether the blue color component is active when rendering.
---@return boolean a Whether the alpha color component is active when rendering.
function love.graphics.getColorMask()
end

---Gets the DPI scale factor of the window.
---
---The DPI scale factor represents relative pixel density. The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.graphics.getDPIScale() would return 2 in that case.
---
---The love.window.fromPixels and love.window.toPixels functions can also be used to convert between units.
---
---The highdpi window flag must be enabled to use the full pixel density of a Retina screen on Mac OS X and iOS. The flag currently does nothing on Windows and Linux, and on Android it is effectively always enabled.
---
---The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in DPI-scaled units rather than pixels. In LÖVE 0.10 and older they were in pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getDPIScale)
---
---@return number scale The pixel scale factor associated with the window.
function love.graphics.getDPIScale()
end

---Returns the default scaling filters used with Images, Canvases, and Fonts.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getDefaultFilter)
---
---@return love.graphics.FilterMode min Filter mode used when scaling the image down.
---@return love.graphics.FilterMode mag Filter mode used when scaling the image up.
---@return number anisotropy Maximum amount of Anisotropic Filtering used.
function love.graphics.getDefaultFilter()
end

---Gets the default mipmap filter used by new Textures.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getDefaultMipmapFilter)
---
---@return love.graphics.MipmapFilterMode filtermode The default mipmap filter mode.
---@return number sharpness The default mipmap sharpness.
function love.graphics.getDefaultMipmapFilter()
end

---Gets the current depth test mode and whether writing to the depth buffer is enabled.
---
---This is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getDepthMode)
---
---@return love.graphics.CompareMode comparemode Depth comparison mode used for depth testing.
---@return boolean write Whether to write update / write values to the depth buffer when rendering.
function love.graphics.getDepthMode()
end

---Gets the width and height in pixels of the window.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getDimensions)
---
---@return number width The width of the window.
---@return number height The height of the window.
function love.graphics.getDimensions()
end

---Gets the current Font object.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getFont)
---
---@return love.graphics.Font font The current Font. Automatically creates and sets the default font, if none is set yet.
function love.graphics.getFont()
end

---Gets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.
---
---This is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getFrontFaceWinding)
---
---@return love.graphics.VertexWinding winding The winding mode being used. The default winding is counterclockwise ('ccw').
function love.graphics.getFrontFaceWinding()
end

---Gets the height in pixels of the window.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getHeight)
---
---@return number height The height of the window.
function love.graphics.getHeight()
end

---Deprecated: use love.graphics.getTextureFormats. Gets which ImageData and compressed pixel formats can be sampled from Textures.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getImageFormats)
---
---@param formats (table)? An existing table to fill in and return instead of creating a new one.
---@return table formats A table with PixelFormat keys and boolean values.
function love.graphics.getImageFormats(formats)
end

---Gets the line join style.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getLineJoin)
---
---@return love.graphics.LineJoin join The LineJoin style.
function love.graphics.getLineJoin()
end

---Gets the line style.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getLineStyle)
---
---@return love.graphics.LineStyle style The current line style.
function love.graphics.getLineStyle()
end

---Gets the current line width.
---
---This function does not work in 0.8.0, but has been fixed in version 0.9.0. Use the following snippet to circumvent this in 0.8.0;
---
---love.graphics._getLineWidth = love.graphics.getLineWidth
---
---love.graphics._setLineWidth = love.graphics.setLineWidth
---
---function love.graphics.getLineWidth() return love.graphics.varlinewidth or 1 end
---
---function love.graphics.setLineWidth(w) love.graphics.varlinewidth = w; return love.graphics._setLineWidth(w) end
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getLineWidth)
---
---@return number width The current line width.
function love.graphics.getLineWidth()
end

---Gets whether back-facing triangles in a Mesh are culled.
---
---Mesh face culling is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getMeshCullMode)
---
---@return love.graphics.CullMode mode The Mesh face culling mode in use (whether to render everything, cull back-facing triangles, or cull front-facing triangles).
function love.graphics.getMeshCullMode()
end

---Gets the width and height in pixels of the window.
---
---love.graphics.getDimensions gets the dimensions of the window in units scaled by the screen's DPI scale factor, rather than pixels. Use getDimensions for calculations related to drawing to the screen and using the graphics coordinate system (calculating the center of the screen, for example), and getPixelDimensions only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getPixelDimensions)
---
---@return number pixelwidth The width of the window in pixels.
---@return number pixelheight The height of the window in pixels.
function love.graphics.getPixelDimensions()
end

---Gets the height in pixels of the window.
---
---The graphics coordinate system and DPI scale factor, rather than raw pixels. Use getHeight for calculations related to drawing to the screen and using the coordinate system (calculating the center of the screen, for example), and getPixelHeight only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getPixelHeight)
---
---@return number pixelheight The height of the window in pixels.
function love.graphics.getPixelHeight()
end

---Gets the width in pixels of the window.
---
---The graphics coordinate system and DPI scale factor, rather than raw pixels. Use getWidth for calculations related to drawing to the screen and using the coordinate system (calculating the center of the screen, for example), and getPixelWidth only when dealing specifically with underlying pixels (pixel-related calculations in a pixel Shader, for example).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getPixelWidth)
---
---@return number pixelwidth The width of the window in pixels.
function love.graphics.getPixelWidth()
end

---Gets the point size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getPointSize)
---
---@return number size The current point size.
function love.graphics.getPointSize()
end

---Gets the shared index buffer LÖVE uses internally when drawing quads.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getQuadIndexBuffer)
---
---@return love.graphics.GraphicsBuffer buffer The quad index buffer.
function love.graphics.getQuadIndexBuffer()
end

---Gets information about the system's video card and drivers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getRendererInfo)
---
---@return string name The name of the renderer, e.g. 'OpenGL' or 'OpenGL ES'.
---@return string version The version of the renderer with some extra driver-dependent version info, e.g. '2.1 INTEL-8.10.44'.
---@return string vendor The name of the graphics card vendor, e.g. 'Intel Inc'. 
---@return string device The name of the graphics card, e.g. 'Intel HD Graphics 3000 OpenGL Engine'.
function love.graphics.getRendererInfo()
end

---Gets the current scissor box.
---
---Returns nothing when no scissor is set.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getScissor)
---
---@return number x The x-component of the top-left point of the box.
---@return number y The y-component of the top-left point of the box.
---@return number width The width of the box.
---@return number height The height of the box.
function love.graphics.getScissor()
end

---Gets the current Shader. Returns nil if none is set.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getShader)
---
---@return love.graphics.Shader shader The currently active Shader, or nil if none is set.
function love.graphics.getShader()
end

---Gets the current depth of the transform / state stack (the number of pushes without corresponding pops).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getStackDepth)
---
---@return number depth The current depth of the transform and state love.graphics stack.
function love.graphics.getStackDepth()
end

---Gets performance-related rendering statistics.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getStats)
---
---@param stats (table)? An existing table to fill in and return instead of creating a new one.
---@return {drawcalls: number, drawcallsbatched: number, canvasswitches: number, shaderswitches: number, textures: number, fonts: number, buffers: number, texturememory: number, buffermemory: number} stats A table with the following fields:
function love.graphics.getStats(stats)
end

---Gets the current stencil mode, as set by love.graphics.setStencilMode.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getStencilMode)
---
---@return love.graphics.StencilMode mode The current stencil mode. 'custom' when love.graphics.setStencilState set a state no mode matches.
---@return number value The current stencil value.
function love.graphics.getStencilMode()
end

---Gets the current low-level stencil state, as set by love.graphics.setStencilState.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getStencilState)
---
---@return love.graphics.StencilAction action How stencil values of touched pixels are modified.
---@return love.graphics.CompareMode comparemode The comparison used for the stencil test.
---@return number value The stencil reference value.
---@return number readmask The bit mask applied to stencil values read.
---@return number writemask The bit mask applied to stencil values written.
function love.graphics.getStencilState()
end

---Deprecated: use love.graphics.getStencilMode or love.graphics.getStencilState. Gets the current stencil comparison mode and value.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getStencilTest)
---
---@return love.graphics.CompareMode comparemode The current stencil comparison mode.
---@return number comparevalue The current stencil reference value.
function love.graphics.getStencilTest()
end

---Gets which optional graphics features the system supports.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getSupported)
---
---@param features (table)? An existing table to fill in and return instead of creating a new one.
---@return table features A table with GraphicsFeature keys and boolean values.
function love.graphics.getSupported(features)
end

---Gets the system-dependent maximum values for love.graphics features.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getSystemLimits)
---
---@param limits (table)? An existing table to fill in and return instead of creating a new one.
---@return table limits A table with GraphicsLimit keys and number values.
function love.graphics.getSystemLimits(limits)
end

---Gets which pixel formats Textures can use for the given kind of usage.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getTextureFormats)
---
---@param usage {canvas: boolean, readable: (boolean)?, computewrite: (boolean)?, shaderatomics: (boolean)?} The kind of usage to check.
---@param formats (table)? An existing table to fill in and return instead of creating a new one.
---@return table formats A table with PixelFormat keys and boolean values.
function love.graphics.getTextureFormats(usage, formats)
end

---Gets which texture types the system supports.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getTextureTypes)
---
---@param texturetypes (table)? An existing table to fill in and return instead of creating a new one.
---@return table texturetypes A table with TextureType keys and boolean values.
function love.graphics.getTextureTypes(texturetypes)
end

---Gets the width in pixels of the window.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.getWidth)
---
---@return number width The width of the window.
function love.graphics.getWidth()
end

---Sets the scissor to the rectangle created by the intersection of the specified rectangle with the existing scissor.  If no scissor is active yet, it behaves like love.graphics.setScissor.
---
---The scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear.
---
---The dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.intersectScissor)
---
---@param x number The x-coordinate of the upper left corner of the rectangle to intersect with the existing scissor rectangle.
---@param y number The y-coordinate of the upper left corner of the rectangle to intersect with the existing scissor rectangle.
---@param width number The width of the rectangle to intersect with the existing scissor rectangle.
---@param height number The height of the rectangle to intersect with the existing scissor rectangle.
function love.graphics.intersectScissor(x, y, width, height)
end

---Converts the given 2D position from screen-space into global coordinates.
---
---This effectively applies the reverse of the current graphics transformations to the given position. A similar Transform:inverseTransformPoint method exists for Transform objects.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.inverseTransformPoint)
---
---@param screenX number The x component of the screen-space position.
---@param screenY number The y component of the screen-space position.
---@return number globalX The x component of the position in global coordinates.
---@return number globalY The y component of the position in global coordinates.
function love.graphics.inverseTransformPoint(screenX, screenY)
end

---Gets whether the graphics module is able to be used. If it is not active, love.graphics function and method calls will not work correctly and may cause the program to crash.
---The graphics module is inactive if a window is not open, or if the app is in the background on iOS. Typically the app's execution will be automatically paused by the system, in the latter case.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.isActive)
---
---@return boolean active Whether the graphics module is active and able to be used.
function love.graphics.isActive()
end

---Gets whether the graphics module has been initialized, which happens when the first window is created.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.isCreated)
---
---@return boolean created Whether the graphics module is initialized.
function love.graphics.isCreated()
end

---Gets whether gamma-correct rendering is supported and enabled. It can be enabled by setting t.gammacorrect = true in love.conf.
---
---Not all devices support gamma-correct rendering, in which case it will be automatically disabled and this function will return false. It is supported on desktop systems which have graphics cards that are capable of using OpenGL 3 / DirectX 10, and iOS devices that can use OpenGL ES 3.
---
---When gamma-correct rendering is enabled, many functions and objects perform automatic color conversion between sRGB and linear RGB in order for blending and shader math to be mathematically correct (which they aren't if it's not enabled.)
---
---* The colors passed into converted from sRGB to linear RGB.
---
---* The colors set in text with per-character colors, points with per-point colors, standard custom Meshes which use the 'VertexColor' attribute name will automatically be converted from sRGB to linear RGB when those objects are drawn.
---
---* creating the Image.
---
---* Everything drawn to the screen will be blended in linear RGB and then the result will be converted to sRGB for display.
---
---* Canvases which use the 'normal' or 'srgb' CanvasFormat will have their content blended in linear RGB and the result will be stored in the canvas in sRGB, when drawing to them. When the Canvas itself is drawn, its pixel colors will be converted from sRGB to linear RGB in the same manner as Images. Keeping the canvas pixel data stored as sRGB allows for better precision (less banding) for darker colors compared to 'rgba8'.
---
---Because most conversions are automatically handled, your own code doesn't need to worry about sRGB and linear RGB color conversions when gamma-correct rendering is enabled, except in a couple cases:
---
---* If a Mesh with custom vertex attributes is used and one of the attributes is meant to be used as a color in a Shader, and the attribute isn't named 'VertexColor'.
---
---* If  a Shader is used which has uniform / extern variables or other variables that are meant to be used as colors, and Shader:sendColor isn't used.
---
---In both cases, love.math.gammaToLinear can be used to convert color values to linear RGB in Lua code, or the gammaCorrectColor (or unGammaCorrectColor if necessary) shader functions can be used inside shader code. Those shader functions ''only'' do conversions if gamma-correct rendering is actually enabled. The LOVE_GAMMA_CORRECT shader preprocessor define will be set if so.
---
---Read more about gamma-correct rendering here, here, and here.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.isGammaCorrect)
---
---@return boolean gammacorrect True if gamma-correct rendering is supported and was enabled in love.conf, false otherwise.
function love.graphics.isGammaCorrect()
end

---Gets whether the low power GPU was requested (the graphics.lowpower field of love.conf) on systems with more than one.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.isLowPowerPreferred)
---
---@return boolean lowpower Whether the low power GPU is preferred.
function love.graphics.isLowPowerPreferred()
end

---Gets whether wireframe mode is used when drawing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.isWireframe)
---
---@return boolean wireframe True if wireframe lines are used when drawing, false if it's not.
function love.graphics.isWireframe()
end

---Draws lines between points.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.line)
---
---@param x1 number The position of first point on the x-axis.
---@param y1 number The position of first point on the y-axis.
---@param x2 number The position of second point on the x-axis.
---@param y2 number The position of second point on the y-axis.
---@param ... number You can continue passing point positions to draw a polyline.
function love.graphics.line(x1, y1, x2, y2, ...)
end

---Draws lines between points.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.line)
---
---@param points (number)[] A table of point positions, as described above.
function love.graphics.line(points)
end

---Alias of love.graphics.newArrayTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an empty array texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayImage)
---
---@param width number The width of each layer in pixels.
---@param height number The height of each layer in pixels.
---@param layers number The number of layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayImage(width, height, layers, settings)
end

---Alias of love.graphics.newArrayTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an array texture from one image per layer. Each entry can instead be a table of mipmap level images for that layer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayImage)
---
---@param slices (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The layer images, or tables of mipmap level images per layer.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayImage(slices, settings)
end

---Alias of love.graphics.newArrayTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an array texture from a single image.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayImage)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image to use as the texture's layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayImage(source, settings)
end

---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an empty array texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayTexture)
---
---@param width number The width of each layer in pixels.
---@param height number The height of each layer in pixels.
---@param layers number The number of layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayTexture(width, height, layers, settings)
end

---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an array texture from one image per layer. Each entry can instead be a table of mipmap level images for that layer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayTexture)
---
---@param slices (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The layer images, or tables of mipmap level images per layer.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayTexture(slices, settings)
end

---Creates a new array Texture: several same-size 2D layers in one object, drawn with love.graphics.drawLayer or sampled in shaders with an ArrayImage uniform.
---
---Creates an array texture from a single image.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newArrayTexture)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image to use as the texture's layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newArrayTexture(source, settings)
end

---Creates a new GraphicsBuffer: GPU memory holding an array of elements of the given format, usable as vertex, index, texel, shader storage or indirect argument data.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newBuffer)
---
---@param format love.graphics.BufferDataFormat|{name: (string)?, format: love.graphics.BufferDataFormat, arraylength: (number)?, location: (number)?}[] The format of each element: a single BufferDataFormat, or an array with one table per field of a structured element.
---@param data number|table|love.Data The number of elements, or the initial contents: a flat table of numbers, a table of per-element tables, or a Data object.
---@param settings {vertex: (boolean)?, index: (boolean)?, texel: (boolean)?, shaderstorage: (boolean)?, indirectarguments: (boolean)?, usage: (love.graphics.BufferDataUsage)?, debugname: (string)?} The usage flags and other settings of the buffer.
---@return love.graphics.GraphicsBuffer buffer The new buffer.
function love.graphics.newBuffer(format, data, settings)
end

---Creates a new render target Texture (a Texture with the canvas setting) which can be drawn to with love.graphics.setCanvas.
---
---Creates a render target the size of the window.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCanvas)
---
---@return love.graphics.Texture canvas The new Texture.
function love.graphics.newCanvas()
end

---Creates a new render target Texture (a Texture with the canvas setting) which can be drawn to with love.graphics.setCanvas.
---
---Creates a render target of the given size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCanvas)
---
---@param width (number)? The width of the render target in pixels.
---@param height (number)? The height of the render target in pixels.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture canvas The new Texture.
function love.graphics.newCanvas(width, height, settings)
end

---Creates a new render target Texture (a Texture with the canvas setting) which can be drawn to with love.graphics.setCanvas.
---
---Creates an array render target of the given size and layer count.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCanvas)
---
---@param width number The width of the render target in pixels.
---@param height number The height of the render target in pixels.
---@param layers number The number of array layers.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture canvas The new Texture.
function love.graphics.newCanvas(width, height, layers, settings)
end

---Creates a new render target Texture (a Texture with the canvas setting) which can be drawn to with love.graphics.setCanvas.
---
---Creates a render target from a settings table that includes its dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCanvas)
---
---@param settings {width: number, height: number, layers: (number)?, type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?} The settings of the render target. width and height are required. Unknown fields are an error.
---@return love.graphics.Texture canvas The new Texture.
function love.graphics.newCanvas(settings)
end

---Creates a new compute Shader, run with love.graphics.dispatchThreadgroups or love.graphics.dispatchIndirect. Requires the glsl4 GraphicsFeature.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newComputeShader)
---
---@param code string|love.filesystem.File|love.filesystem.FileData The compute shader code, or a file containing it.
---@param options ({defines: (table)?, debugname: (string)?, write: (boolean)?})? Compile options.
---@return love.graphics.Shader shader The new Shader.
function love.graphics.newComputeShader(code, options)
end

---Alias of love.graphics.newCubeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates an empty cubemap of the given face size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeImage)
---
---@param size number The width and height of each face in pixels.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeImage(size, settings)
end

---Alias of love.graphics.newCubeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates a cubemap from a single image containing all 6 faces laid out as a cross or strip.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeImage)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image containing the 6 faces.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeImage(source, settings)
end

---Alias of love.graphics.newCubeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates a cubemap from 6 images, one per face, in the order +x, -x, +y, -y, +z, -z. Each entry can instead be a table of mipmap level images for that face.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeImage)
---
---@param faces (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The 6 face images, or 6 tables of mipmap level images.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeImage(faces, settings)
end

---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates an empty cubemap of the given face size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeTexture)
---
---@param size number The width and height of each face in pixels.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeTexture(size, settings)
end

---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates a cubemap from a single image containing all 6 faces laid out as a cross or strip.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeTexture)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image containing the 6 faces.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeTexture(source, settings)
end

---Creates a new cubemap Texture. Cubemaps have 6 square faces and are sampled in shaders with a 3D direction vector.
---
---Creates a cubemap from 6 images, one per face, in the order +x, -x, +y, -y, +z, -z. Each entry can instead be a table of mipmap level images for that face.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newCubeTexture)
---
---@param faces (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The 6 face images, or 6 tables of mipmap level images.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newCubeTexture(faces, settings)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from a TrueType or BMFont file with default settings.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData The font file.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(filename)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from a TrueType file.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData|love.Data The TrueType font file, or Data holding it.
---@param size (number)? The size of the font in pixels.
---@param hinting (love.font.HintingMode)? TrueType hinting mode.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(filename, size, hinting, dpiscale)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from a TrueType file with a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData|love.Data The TrueType font file, or Data holding it.
---@param size (number)? The size of the font in pixels.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} TrueType font settings.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(filename, size, settings)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from a BMFont file and its glyph images.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData The BMFont .fnt file.
---@param imagefilename string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|table The glyph page image, or an array of them. Taken from the .fnt file when nil.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(filename, imagefilename, dpiscale)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from the default TrueType font.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param size (number)? The size of the font in pixels.
---@param hinting (love.font.HintingMode)? TrueType hinting mode.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(size, hinting, dpiscale)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from the default TrueType font with a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param size (number)? The size of the font in pixels.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} TrueType font settings.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(size, settings)
end

---Creates a new Font from a TrueType font, a BMFont, or a Rasterizer. Arguments other than a Rasterizer are passed to love.font.newRasterizer.
---
---Creates a Font from an existing Rasterizer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newFont)
---
---@param rasterizer love.font.Rasterizer The Rasterizer holding the glyphs.
---@return love.graphics.Font font The new Font.
function love.graphics.newFont(rasterizer)
end

---Alias of love.graphics.newTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates an empty texture of the given size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImage)
---
---@param width number The width of the texture in pixels.
---@param height number The height of the texture in pixels.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newImage(width, height, settings)
end

---Alias of love.graphics.newTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates an empty array texture of the given size and layer count.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImage)
---
---@param width number The width of the texture in pixels.
---@param height number The height of the texture in pixels.
---@param layers number The number of array layers.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newImage(width, height, layers, settings)
end

---Alias of love.graphics.newTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates a 2D texture from an image. Its dimensions come from the image.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImage)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image: a filename, File, FileData, ImageData or CompressedImageData. CompressedImageData includes its mipmap levels when mipmaps are enabled.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newImage(source, settings)
end

---Alias of love.graphics.newTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates a 2D texture whose mipmap levels come from the given images, largest first.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImage)
---
---@param mipmaps (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData)[] The images for each mipmap level, starting with the base level.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newImage(mipmaps, settings)
end

---Creates a new Font from an image whose glyphs are separated by a spacer color (the color of the top-left pixel).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImageFont)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData The image, or a file containing it.
---@param glyphs string The characters in the image, in order from left to right.
---@param extraspacing (number)? Additional spacing in pixels between characters.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.newImageFont(source, glyphs, extraspacing, dpiscale)
end

---Creates a new Font from an image whose glyphs are separated by a spacer color (the color of the top-left pixel).
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newImageFont)
---
---@param rasterizer love.font.Rasterizer An image Rasterizer, from love.font.newImageRasterizer.
---@return love.graphics.Font font The new Font.
function love.graphics.newImageFont(rasterizer)
end

---Creates a new Mesh: a set of vertices drawn as triangles, a strip, a fan or points, optionally with custom vertex attributes.
---
---Creates a Mesh with the standard vertex format (position, texture coordinate and color) from a table of vertices.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newMesh)
---
---@param vertices {[1]: number, [2]: number, [3]: (number)?, [4]: (number)?, [5]: (number)?, [6]: (number)?, [7]: (number)?, [8]: (number)?}[] The vertices of the Mesh, each a table {x, y, u, v, r, g, b, a}.
---@param mode love.graphics.MeshDrawMode How the vertices are used when drawing.
---@param usage (love.graphics.BufferDataUsage)? How often the Mesh's vertices are expected to change.
---@return love.graphics.Mesh mesh The new mesh.
function love.graphics.newMesh(vertices, mode, usage)
end

---Creates a new Mesh: a set of vertices drawn as triangles, a strip, a fan or points, optionally with custom vertex attributes.
---
---Creates a Mesh with the standard vertex format and the given number of vertices, all initialized to zero.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newMesh)
---
---@param vertexcount number The number of vertices.
---@param mode love.graphics.MeshDrawMode How the vertices are used when drawing.
---@param usage (love.graphics.BufferDataUsage)? How often the Mesh's vertices are expected to change.
---@return love.graphics.Mesh mesh The new mesh.
function love.graphics.newMesh(vertexcount, mode, usage)
end

---Creates a new Mesh: a set of vertices drawn as triangles, a strip, a fan or points, optionally with custom vertex attributes.
---
---Creates a Mesh with a custom vertex format.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newMesh)
---
---@param vertexformat {name: (string)?, format: love.graphics.BufferDataFormat, location: number, arraylength: (number)?}[] The vertex attributes, one table per attribute. The older {name, datatype, components} form is deprecated.
---@param vertices table|number|love.Data A table of vertices (each a table with the components of every attribute in order), the number of vertices, or a Data object with the raw vertex data.
---@param mode love.graphics.MeshDrawMode How the vertices are used when drawing.
---@param usage (love.graphics.BufferDataUsage)? How often the Mesh's vertices are expected to change.
---@return love.graphics.Mesh mesh The new mesh.
function love.graphics.newMesh(vertexformat, vertices, mode, usage)
end

---Creates a new Mesh: a set of vertices drawn as triangles, a strip, a fan or points, optionally with custom vertex attributes.
---
---Creates a Mesh whose vertex attributes come from existing vertex GraphicsBuffers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newMesh)
---
---@param attributes {buffer: love.graphics.GraphicsBuffer, location: number, name: (string)?, step: (love.graphics.VertexAttributeStep)?, locationinbuffer: (number)?, nameinbuffer: (string)?, startindex: (number)?}[] The vertex attributes, one table per attribute.
---@param mode love.graphics.MeshDrawMode How the vertices are used when drawing.
---@return love.graphics.Mesh mesh The new mesh.
function love.graphics.newMesh(attributes, mode)
end

---Creates a new ParticleSystem.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newParticleSystem)
---
---@param texture love.graphics.Texture The texture to use for the particles.
---@param buffer (number)? The maximum number of particles at the same time.
---@return love.graphics.ParticleSystem system The new ParticleSystem.
function love.graphics.newParticleSystem(texture, buffer)
end

---Creates a new Quad: a rectangular part of a texture, used to draw only that part.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newQuad)
---
---@param x number The top-left position in the texture along the x-axis.
---@param y number The top-left position in the texture along the y-axis.
---@param width number The width of the Quad in the texture.
---@param height number The height of the Quad in the texture.
---@param sw number The reference width, the width of the texture.
---@param sh number The reference height, the height of the texture.
---@return love.graphics.Quad quad The new Quad.
function love.graphics.newQuad(x, y, width, height, sw, sh)
end

---Creates a new Quad: a rectangular part of a texture, used to draw only that part.
---
---Uses the dimensions of the given texture as the reference width and height.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newQuad)
---
---@param x number The top-left position in the texture along the x-axis.
---@param y number The top-left position in the texture along the y-axis.
---@param width number The width of the Quad in the texture.
---@param height number The height of the Quad in the texture.
---@param texture love.graphics.Texture The texture whose width and height are the reference dimensions.
---@return love.graphics.Quad quad The new Quad.
function love.graphics.newQuad(x, y, width, height, texture)
end

---Creates a new Quad: a rectangular part of a texture, used to draw only that part.
---
---Creates a Quad for one layer of an array texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newQuad)
---
---@param x number The top-left position in the texture along the x-axis.
---@param y number The top-left position in the texture along the y-axis.
---@param width number The width of the Quad in the texture.
---@param height number The height of the Quad in the texture.
---@param layer number The array layer the Quad uses, starting at 1.
---@param texture love.graphics.Texture The texture whose width and height are the reference dimensions.
---@return love.graphics.Quad quad The new Quad.
function love.graphics.newQuad(x, y, width, height, layer, texture)
end

---Creates a new Quad: a rectangular part of a texture, used to draw only that part.
---
---Creates a Quad for one layer of an array texture with an explicit reference size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newQuad)
---
---@param x number The top-left position in the texture along the x-axis.
---@param y number The top-left position in the texture along the y-axis.
---@param width number The width of the Quad in the texture.
---@param height number The height of the Quad in the texture.
---@param layer number The array layer the Quad uses, starting at 1.
---@param sw number The reference width, the width of the texture.
---@param sh number The reference height, the height of the texture.
---@return love.graphics.Quad quad The new Quad.
function love.graphics.newQuad(x, y, width, height, layer, sw, sh)
end

---Creates a new Shader for drawing, from GLSL code with optional LÖVE extensions. Code arguments can be the code itself or a filename, File or FileData holding it. A single code argument may contain both a vertex and a pixel stage.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newShader)
---
---@param code string|love.filesystem.File|love.filesystem.FileData The pixel shader or vertex shader code (or both), or a file containing it.
---@param options ({defines: (table)?, debugname: (string)?, write: (boolean)?})? Compile options.
---@return love.graphics.Shader shader The new Shader.
function love.graphics.newShader(code, options)
end

---Creates a new Shader for drawing, from GLSL code with optional LÖVE extensions. Code arguments can be the code itself or a filename, File or FileData holding it. A single code argument may contain both a vertex and a pixel stage.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newShader)
---
---@param pixelcode string|love.filesystem.File|love.filesystem.FileData The pixel shader code, or a file containing it.
---@param vertexcode string|love.filesystem.File|love.filesystem.FileData The vertex shader code, or a file containing it.
---@param options ({defines: (table)?, debugname: (string)?, write: (boolean)?})? Compile options.
---@return love.graphics.Shader shader The new Shader.
function love.graphics.newShader(pixelcode, vertexcode, options)
end

---Creates a new SpriteBatch, which draws many copies of a texture (or parts of it via Quads) with one draw call.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newSpriteBatch)
---
---@param texture love.graphics.Texture The texture to use for the sprites.
---@param maxsprites (number)? The maximum number of sprites the batch can hold at once.
---@param usage (love.graphics.BufferDataUsage)? How often the batch's contents are expected to change.
---@return love.graphics.SpriteBatch spriteBatch The new SpriteBatch.
function love.graphics.newSpriteBatch(texture, maxsprites, usage)
end

---Deprecated: renamed to love.graphics.newTextBatch, which takes the same arguments. Creates a new TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newText)
---
---@param font love.graphics.Font The font to use for the text.
---@param textstring (string)? The initial string of text the new TextBatch will have.
---@return love.graphics.TextBatch text The new TextBatch.
function love.graphics.newText(font, textstring)
end

---Deprecated: renamed to love.graphics.newTextBatch, which takes the same arguments. Creates a new TextBatch.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newText)
---
---@param font love.graphics.Font The font to use for the text.
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@return love.graphics.TextBatch text The new TextBatch.
function love.graphics.newText(font, coloredtext)
end

---Creates a new drawable Text object.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTextBatch)
---
---@param font love.graphics.Font The font to use for the text.
---@param textstring (string)? The initial string of text that the new Text object will contain. May be nil.
---@return love.graphics.TextBatch text The new drawable Text object.
function love.graphics.newTextBatch(font, textstring)
end

---Creates a new drawable Text object.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTextBatch)
---
---@param font love.graphics.Font The font to use for the text.
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: string|number|boolean|table|love.Object} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@return love.graphics.TextBatch text The new drawable Text object.
function love.graphics.newTextBatch(font, coloredtext)
end

---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates an empty texture of the given size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTexture)
---
---@param width number The width of the texture in pixels.
---@param height number The height of the texture in pixels.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newTexture(width, height, settings)
end

---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates an empty array texture of the given size and layer count.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTexture)
---
---@param width number The width of the texture in pixels.
---@param height number The height of the texture in pixels.
---@param layers number The number of array layers.
---@param settings ({type: (love.graphics.TextureType)?, format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newTexture(width, height, layers, settings)
end

---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates a 2D texture from an image. Its dimensions come from the image.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTexture)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image: a filename, File, FileData, ImageData or CompressedImageData. CompressedImageData includes its mipmap levels when mipmaps are enabled.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newTexture(source, settings)
end

---Creates a new Texture, either empty with the given dimensions or from image data. A Texture can be drawn, sampled in shaders, and (with the canvas setting) rendered to.
---
---Creates a 2D texture whose mipmap levels come from the given images, largest first.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTexture)
---
---@param mipmaps (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData)[] The images for each mipmap level, starting with the base level.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newTexture(mipmaps, settings)
end

---Creates a Texture that views part of an existing Texture's data (a range of mipmap levels or layers, or a different compatible type or pixel format) without copying it.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newTextureView)
---
---@param base love.graphics.Texture The Texture to view.
---@param settings {format: (love.image.PixelFormat)?, type: (love.graphics.TextureType)?, mipmapstart: (number)?, mipmapcount: (number)?, layerstart: (number)?, layers: (number)?, debugname: (string)?} What part of the base texture to view.
---@return love.graphics.Texture view The new texture view.
function love.graphics.newTextureView(base, settings)
end

---Creates a new Video, which plays Ogg Theora files. The audio track, if any, plays through a streaming Source.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVideo)
---
---@param file string|love.filesystem.File|love.video.VideoStream The video file, or an existing VideoStream.
---@param settings ({audio: (boolean)?, dpiscale: (number)?})? Settings for the new video.
---@return love.graphics.Video video The new Video.
function love.graphics.newVideo(file, settings)
end

---Alias of love.graphics.newVolumeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates an empty volume texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeImage)
---
---@param width number The width in pixels.
---@param height number The height in pixels.
---@param layers number The depth in pixels.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeImage(width, height, layers, settings)
end

---Alias of love.graphics.newVolumeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates a volume texture from one image per depth layer. The table can instead hold one table per mipmap level, each containing that level's layers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeImage)
---
---@param layers (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The depth layer images, or tables of layer images per mipmap level.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeImage(layers, settings)
end

---Alias of love.graphics.newVolumeTexture, kept for compatibility. Takes the same arguments.
---
---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates a volume texture from a single image split into its depth layers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeImage)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image containing the depth layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeImage(source, settings)
end

---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates an empty volume texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeTexture)
---
---@param width number The width in pixels.
---@param height number The height in pixels.
---@param layers number The depth in pixels.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeTexture(width, height, layers, settings)
end

---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates a volume texture from one image per depth layer. The table can instead hold one table per mipmap level, each containing that level's layers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeTexture)
---
---@param layers (string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData|table)[] The depth layer images, or tables of layer images per mipmap level.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeTexture(layers, settings)
end

---Creates a new volume (3D) Texture with width, height and depth. Volume textures are sampled in shaders with 3D texture coordinates.
---
---Creates a volume texture from a single image split into its depth layers.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.newVolumeTexture)
---
---@param source string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|love.image.CompressedImageData The image containing the depth layers.
---@param settings ({format: (love.image.PixelFormat)?, mipmaps: (boolean|love.graphics.MipmapMode)?, mipmapcount: (number)?, linear: (boolean)?, msaa: (number)?, dpiscale: (number)?, canvas: (boolean)?, computewrite: (boolean)?, viewformats: ((love.image.PixelFormat)[])?, readable: (boolean)?, debugname: (string)?})? Optional table of settings to configure the texture. Unknown fields are an error.
---@return love.graphics.Texture texture The new Texture.
function love.graphics.newVolumeTexture(source, settings)
end

---Resets the current coordinate transformation.
---
---This function is always used to reverse any previous calls to love.graphics.rotate, love.graphics.scale, love.graphics.shear or love.graphics.translate. It returns the current transformation state to its defaults.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.origin)
---
function love.graphics.origin()
end

---Draws one or more points.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.points)
---
---@param x number The position of the first point on the x-axis.
---@param y number The position of the first point on the y-axis.
---@param ... number The x and y coordinates of additional points.
function love.graphics.points(x, y, ...)
end

---Draws one or more points.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.points)
---
---@param points (number)[] A table containing multiple point positions, in the form of {x, y, ...}.
function love.graphics.points(points)
end

---Draws one or more points.
---
---Draws one or more individually colored points.
---
---In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
---
---The pixel grid is actually offset to the center of each pixel. So to get clean pixels drawn use 0.5 + integer increments.
---
---Points are not affected by size is always in pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.points)
---
---@param points {point: table, [string]: table} A table containing multiple individually colored points, in the form of {point, ...}.
function love.graphics.points(points)
end

---Draw a polygon.
---
---Following the mode argument, this function can accept multiple numeric arguments or a single table of numeric arguments. In either case the arguments are interpreted as alternating x and y coordinates of the polygon's vertices.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.polygon)
---
---@param mode love.graphics.DrawMode How to draw the polygon.
---@param ... number The vertices of the polygon.
function love.graphics.polygon(mode, ...)
end

---Draw a polygon.
---
---Following the mode argument, this function can accept multiple numeric arguments or a single table of numeric arguments. In either case the arguments are interpreted as alternating x and y coordinates of the polygon's vertices.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.polygon)
---
---@param mode love.graphics.DrawMode How to draw the polygon.
---@param vertices (number)[] The vertices of the polygon as a table.
function love.graphics.polygon(mode, vertices)
end

---Pops the current coordinate transformation from the transformation stack.
---
---This function is always used to reverse a previous push operation. It returns the current transformation state to what it was before the last preceding push.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.pop)
---
function love.graphics.pop()
end

---Displays the results of drawing operations on the screen.
---
---This function is used when writing your own love.run function. It presents all the results of your drawing operations on the screen. See the example in love.run for a typical use of this function.
---
---* If love.window.setMode has vsync equal to true, this function can't run more frequently than the refresh rate (e.g. 60 Hz), and will halt the program until ready if necessary.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.present)
---
function love.graphics.present()
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param text string The text to draw.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param text string The text to draw.
---@param font love.graphics.Font The Font object to use.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.print(text, font, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param text string The text to draw.
---@param transform love.math.Transform Transformation object.
function love.graphics.print(text, transform)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param text string The text to draw.
---@param font love.graphics.Font The Font object to use.
---@param transform love.math.Transform Transformation object.
function love.graphics.print(text, font, transform)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.print(coloredtext, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param font love.graphics.Font The Font object to use.
---@param x (number)? The position on the x-axis.
---@param y (number)? The position on the y-axis.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.print(coloredtext, font, x, y, r, sx, sy, ox, oy, kx, ky)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param transform love.math.Transform Transformation object.
function love.graphics.print(coloredtext, transform)
end

---Draws text on screen. If no Font is given, the current font (love.graphics.getFont) is used.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.print)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param font love.graphics.Font The Font object to use.
---@param transform love.math.Transform Transformation object.
function love.graphics.print(coloredtext, font, transform)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param text string A text string.
---@param x number The position on the x-axis.
---@param y number The position on the y-axis.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param text string A text string.
---@param font love.graphics.Font The Font object to use.
---@param x number The position on the x-axis.
---@param y number The position on the y-axis.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
---@param r (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.printf(text, font, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param text string A text string.
---@param transform love.math.Transform Transformation object.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
function love.graphics.printf(text, transform, limit, align)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param text string A text string.
---@param font love.graphics.Font The Font object to use.
---@param transform love.math.Transform Transformation object.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
function love.graphics.printf(text, font, transform, limit, align)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param x number The position of the text (x-axis).
---@param y number The position of the text (y-axis).
---@param limit number The maximum width in pixels of the text before it gets automatically wrapped to a new line.
---@param align (love.graphics.AlignMode)? The alignment of the text.
---@param angle (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing / skew factor (x-axis).
---@param ky (number)? Shearing / skew factor (y-axis).
function love.graphics.printf(coloredtext, x, y, limit, align, angle, sx, sy, ox, oy, kx, ky)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param font love.graphics.Font The Font object to use.
---@param x number The position on the x-axis.
---@param y number The position on the y-axis.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
---@param angle (number)? Orientation (radians).
---@param sx (number)? Scale factor (x-axis).
---@param sy (number)? Scale factor (y-axis).
---@param ox (number)? Origin offset (x-axis).
---@param oy (number)? Origin offset (y-axis).
---@param kx (number)? Shearing factor (x-axis).
---@param ky (number)? Shearing factor (y-axis).
function love.graphics.printf(coloredtext, font, x, y, limit, align, angle, sx, sy, ox, oy, kx, ky)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---The color set by love.graphics.setColor will be combined (multiplied) with the colors of the text.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param transform love.math.Transform Transformation object.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
function love.graphics.printf(coloredtext, transform, limit, align)
end

---Draws formatted text, with word wrap and alignment.
---
---See additional notes in love.graphics.print.
---
---The word wrap limit is applied before any scaling, rotation, and other coordinate transformations. Therefore the amount of text per line stays constant given the same wrap limit, even if the scale arguments change.
---
---In version 0.9.2 and earlier, wrapping was implemented by breaking up words by spaces and putting them back together to make sure things fit nicely within the limit provided. However, due to the way this is done, extra spaces between words would end up missing when printed on the screen, and some lines could overflow past the provided wrap limit. In version 0.10.0 and newer this is no longer the case.
---
---In versions prior to 11.0, color and byte component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.printf)
---
---@param coloredtext {color1: table, string1: string, color2: table, string2: string, [string]: table|string} A table containing colors and strings to add to the object, in the form of {color1, string1, color2, string2, ...}.
---@param font love.graphics.Font The Font object to use.
---@param transform love.math.Transform Transformation object.
---@param limit number Wrap the line after this many horizontal pixels.
---@param align (love.graphics.AlignMode)? The alignment.
function love.graphics.printf(coloredtext, font, transform, limit, align)
end

---Copies and pushes the current coordinate transformation (or all graphics state) onto the stack, to be restored later with love.graphics.pop.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.push)
---
---@param stack (love.graphics.StackType)? The type of state to push.
---@param transform (love.math.Transform)? A Transform applied to the current transformation after pushing.
function love.graphics.push(stack, transform)
end

---Reads the contents of a GraphicsBuffer back to the CPU. Waits until the GPU has finished any work that writes to the buffer, which can take a frame or more; love.graphics.readbackBufferAsync does not wait.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.readbackBuffer)
---
---@param buffer love.graphics.GraphicsBuffer The buffer to read from.
---@param offset (number)? The byte offset in the buffer to start reading from.
---@param size (number)? The number of bytes to read.
---@param dest (love.data.ByteData)? An existing ByteData to write into instead of creating a new one.
---@param destoffset (number)? The byte offset in dest to write to. Only used with dest.
---@return love.data.ByteData data The data read from the buffer (dest, if given).
function love.graphics.readbackBuffer(buffer, offset, size, dest, destoffset)
end

---Starts reading the contents of a GraphicsBuffer back to the CPU without waiting for the GPU. The returned GraphicsReadback reports when the data is ready.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.readbackBufferAsync)
---
---@param buffer love.graphics.GraphicsBuffer The buffer to read from.
---@param offset (number)? The byte offset in the buffer to start reading from.
---@param size (number)? The number of bytes to read.
---@param dest (love.data.ByteData)? An existing ByteData to write into instead of creating a new one.
---@param destoffset (number)? The byte offset in dest to write to. Only used with dest.
---@return love.graphics.GraphicsReadback readback The pending readback.
function love.graphics.readbackBufferAsync(buffer, offset, size, dest, destoffset)
end

---Reads the contents of a Texture back to the CPU as ImageData. Waits until the GPU has finished any work that writes to the texture, which can take a frame or more; love.graphics.readbackTextureAsync does not wait.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.readbackTexture)
---
---@param texture love.graphics.Texture The texture to read from.
---@param slice (number)? The cube face, array layer or volume slice to read. Required for non-2D textures; must be nil or a number for 2D textures.
---@param mipmap (number)? The mipmap level to read.
---@param x (number)? The x position of the region to read. The region is the whole mipmap level when x is not given.
---@param y (number)? The y position of the region to read. Required when x is given.
---@param w (number)? The width of the region to read. Required when x is given.
---@param h (number)? The height of the region to read. Required when x is given.
---@param dest (love.image.ImageData)? An existing ImageData to write into instead of creating a new one.
---@param destx (number)? The x position in dest to write to. Only used with dest.
---@param desty (number)? The y position in dest to write to. Only used with dest.
---@return love.image.ImageData imagedata The pixels read from the texture (dest, if given).
function love.graphics.readbackTexture(texture, slice, mipmap, x, y, w, h, dest, destx, desty)
end

---Starts reading the contents of a Texture back to the CPU without waiting for the GPU. The returned GraphicsReadback reports when the data is ready.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.readbackTextureAsync)
---
---@param texture love.graphics.Texture The texture to read from.
---@param slice (number)? The cube face, array layer or volume slice to read. Required for non-2D textures; must be nil or a number for 2D textures.
---@param mipmap (number)? The mipmap level to read.
---@param x (number)? The x position of the region to read. The region is the whole mipmap level when x is not given.
---@param y (number)? The y position of the region to read. Required when x is given.
---@param w (number)? The width of the region to read. Required when x is given.
---@param h (number)? The height of the region to read. Required when x is given.
---@param dest (love.image.ImageData)? An existing ImageData to write into instead of creating a new one.
---@param destx (number)? The x position in dest to write to. Only used with dest.
---@param desty (number)? The y position in dest to write to. Only used with dest.
---@return love.graphics.GraphicsReadback readback The pending readback.
function love.graphics.readbackTextureAsync(texture, slice, mipmap, x, y, w, h, dest, destx, desty)
end

---Draws a rectangle.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.rectangle)
---
---@param mode love.graphics.DrawMode How to draw the rectangle.
---@param x number The position of top-left corner along the x-axis.
---@param y number The position of top-left corner along the y-axis.
---@param width number Width of the rectangle.
---@param height number Height of the rectangle.
function love.graphics.rectangle(mode, x, y, width, height)
end

---Draws a rectangle.
---
---Draws a rectangle with rounded corners.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.rectangle)
---
---@param mode love.graphics.DrawMode How to draw the rectangle.
---@param x number The position of top-left corner along the x-axis.
---@param y number The position of top-left corner along the y-axis.
---@param width number Width of the rectangle.
---@param height number Height of the rectangle.
---@param rx number The x-axis radius of each round corner. Cannot be greater than half the rectangle's width.
---@param ry (number)? The y-axis radius of each round corner. Cannot be greater than half the rectangle's height.
---@param segments (number)? The number of segments used for drawing the round corners. A default amount will be chosen if no number is given.
function love.graphics.rectangle(mode, x, y, width, height, rx, ry, segments)
end

---Replaces the current coordinate transformation with the given Transform object.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.replaceTransform)
---
---@param transform love.math.Transform The Transform object to replace the current graphics coordinate transform with.
function love.graphics.replaceTransform(transform)
end

---Replaces the current coordinate transformation with the given Transform object.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.replaceTransform)
---
---@param x number The position of the new Transform on the x-axis.
---@param y number The position of the new Transform on the y-axis.
---@param angle (number)? The orientation of the new Transform in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
function love.graphics.replaceTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Resets the current graphics settings.
---
---Calling reset makes the current drawing color white, the current background color black, disables any active color component masks, disables wireframe mode and resets the current graphics transformation to the origin. It also sets both the point and line drawing modes to smooth and their sizes to 1.0.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.reset)
---
function love.graphics.reset()
end

---Resets the projection matrix to the default orthographic projection for the active render target or screen.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.resetProjection)
---
function love.graphics.resetProjection()
end

---Rotates the coordinate system in two dimensions.
---
---Calling this function affects all future drawing operations by rotating the coordinate system around the origin by the given amount of radians. This change lasts until love.draw() exits.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.rotate)
---
---@param angle number The amount to rotate the coordinate system in radians.
function love.graphics.rotate(angle)
end

---Scales the coordinate system in two dimensions.
---
---By default the coordinate system in LÖVE corresponds to the display pixels in horizontal and vertical directions one-to-one, and the x-axis increases towards the right while the y-axis increases downwards. Scaling the coordinate system changes this relation.
---
---After scaling by sx and sy, all coordinates are treated as if they were multiplied by sx and sy. Every result of a drawing operation is also correspondingly scaled, so scaling by (2, 2) for example would mean making everything twice as large in both x- and y-directions. Scaling by a negative value flips the coordinate system in the corresponding direction, which also means everything will be drawn flipped or upside down, or both. Scaling by zero is not a useful operation.
---
---Scale and translate are not commutative operations, therefore, calling them in different orders will change the outcome.
---
---Scaling lasts until love.draw() exits.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.scale)
---
---@param sx number The scaling in the direction of the x-axis.
---@param sy (number)? The scaling in the direction of the y-axis. If omitted, it defaults to same as parameter sx.
function love.graphics.scale(sx, sy)
end

---Sets the background color.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBackgroundColor)
---
---@param red number The red component (0-1).
---@param green number The green component (0-1).
---@param blue number The blue component (0-1).
---@param alpha (number)? The alpha component (0-1).
function love.graphics.setBackgroundColor(red, green, blue, alpha)
end

---Sets the background color.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBackgroundColor)
---
---@param rgba (number)[] A numerical indexed table with the red, green, blue and alpha values as numbers. The alpha is optional and defaults to 1 if it is left out.
function love.graphics.setBackgroundColor(rgba)
end

---Sets the blending mode.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBlendMode)
---
---@param mode love.graphics.BlendMode The blend mode to use.
function love.graphics.setBlendMode(mode)
end

---Sets the blending mode.
---
---The default 'alphamultiply' alpha mode should normally be preferred except when drawing content with pre-multiplied alpha. If content is drawn to a Canvas using the 'alphamultiply' mode, the Canvas texture will have pre-multiplied alpha afterwards, so the 'premultiplied' alpha mode should generally be used when drawing a Canvas to the screen.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBlendMode)
---
---@param mode love.graphics.BlendMode The blend mode to use.
---@param alphamode (love.graphics.BlendAlphaMode)? What to do with the alpha of drawn objects when blending.
function love.graphics.setBlendMode(mode, alphamode)
end

---Sets the low-level blending state. love.graphics.setBlendMode is a simpler function for setting a higher level blending mode.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBlendState)
---
---@param operation love.graphics.BlendOperation The blend operation to use for RGB and alpha.
---@param srcFactor love.graphics.BlendFactor The blend factor to use for source RGB and source alpha.
---@param dstFactor love.graphics.BlendFactor The blend factor to use for destination RGB and destination alpha.
function love.graphics.setBlendState(operation, srcFactor, dstFactor)
end

---Sets the low-level blending state. love.graphics.setBlendMode is a simpler function for setting a higher level blending mode.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBlendState)
---
---@param operationRGB love.graphics.BlendOperation The blend operation to use for RGB.
---@param operationA love.graphics.BlendOperation The blend operation to use for alpha.
---@param srcFactorRGB love.graphics.BlendFactor The blend factor to use for source RGB.
---@param srcFactorA love.graphics.BlendFactor The blend factor to use for source alpha.
---@param dstFactorRGB love.graphics.BlendFactor The blend factor to use for destination RGB.
---@param dstFactorA love.graphics.BlendFactor The blend factor to use for destination alpha.
function love.graphics.setBlendState(operationRGB, operationA, srcFactorRGB, srcFactorA, dstFactorRGB, dstFactorA)
end

---Sets the low-level blending state. love.graphics.setBlendMode is a simpler function for setting a higher level blending mode.
---
---Disables all blending.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setBlendState)
---
function love.graphics.setBlendState()
end

---Sets the render targets that subsequent drawing goes to, or resets drawing to the screen.
---
---No render target should be active when love.graphics.present is called. Temporary depth and stencil buffers requested here are cleared whenever they are used.
---
---Resets the render target to the screen.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setCanvas)
---
function love.graphics.setCanvas()
end

---Sets the render targets that subsequent drawing goes to, or resets drawing to the screen.
---
---No render target should be active when love.graphics.present is called. Temporary depth and stencil buffers requested here are cleared whenever they are used.
---
---Sets one or more 2D textures (made with the canvas setting) as render targets. A mipmap level may follow each texture.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setCanvas)
---
---@param canvas love.graphics.Texture The first render target. Must be a 2D texture.
---@param mipmap (number)? The mipmap level to render to.
---@param ... love.graphics.Texture More 2D render targets, each optionally followed by its mipmap level.
function love.graphics.setCanvas(canvas, mipmap, ...)
end

---Sets the render targets that subsequent drawing goes to, or resets drawing to the screen.
---
---No render target should be active when love.graphics.present is called. Temporary depth and stencil buffers requested here are cleared whenever they are used.
---
---Sets a layer or face and mipmap level of a non-2D texture as the render target.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setCanvas)
---
---@param canvas love.graphics.Texture The cube, array or volume render target.
---@param slice number The cube face index (1-6), array layer, or volume depth slice to render to.
---@param mipmap (number)? The mipmap level to render to.
function love.graphics.setCanvas(canvas, slice, mipmap)
end

---Sets the render targets that subsequent drawing goes to, or resets drawing to the screen.
---
---No render target should be active when love.graphics.present is called. Temporary depth and stencil buffers requested here are cleared whenever they are used.
---
---Sets render targets and depth/stencil buffers from a setup table. The array part holds either Textures (2D, unless shaderlayer is set) or RenderTargetSetup tables {texture, layer = ?, face = ?, mipmap = 1}; layer is required for array and volume textures and face for cubemaps unless shaderlayer is set.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setCanvas)
---
---@param setup {[1]: love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?}, depthstencil: (love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?}|boolean)?, depth: (boolean)?, stencil: (boolean)?, shaderlayer: (boolean)?, [integer]: love.graphics.Texture|{[1]: love.graphics.Texture, mipmap: (integer)?, layer: (integer)?, face: (integer)?}} The render targets and depth/stencil options.
function love.graphics.setCanvas(setup)
end

---Sets the color used for drawing.
---
---In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setColor)
---
---@param red number The amount of red.
---@param green number The amount of green.
---@param blue number The amount of blue.
---@param alpha (number)? The amount of alpha.  The alpha value will be applied to all subsequent draw operations, even the drawing of an image.
function love.graphics.setColor(red, green, blue, alpha)
end

---Sets the color used for drawing.
---
---In versions prior to 11.0, color component values were within the range of 0 to 255 instead of 0 to 1.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setColor)
---
---@param rgba (number)[] A numerical indexed table with the red, green, blue and alpha values as numbers. The alpha is optional and defaults to 1 if it is left out.
function love.graphics.setColor(rgba)
end

---Sets the color mask, which enables or disables writing specific color components when drawing and clearing.
---
---Enables or disables writing each color component.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setColorMask)
---
---@param red boolean Write the red component.
---@param green boolean Write the green component.
---@param blue boolean Write the blue component.
---@param alpha boolean Write the alpha component.
function love.graphics.setColorMask(red, green, blue, alpha)
end

---Sets the color mask, which enables or disables writing specific color components when drawing and clearing.
---
---Enables or disables writing all color components.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setColorMask)
---
---@param enable boolean Write all color components.
function love.graphics.setColorMask(enable)
end

---Sets the color mask, which enables or disables writing specific color components when drawing and clearing.
---
---Enables writing all color components.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setColorMask)
---
function love.graphics.setColorMask()
end

---Sets the default scaling filters used with Images, Canvases, and Fonts.
---
---This function does not apply retroactively to loaded images.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setDefaultFilter)
---
---@param min love.graphics.FilterMode Filter mode used when scaling the image down.
---@param mag (love.graphics.FilterMode)? Filter mode used when scaling the image up.
---@param anisotropy (number)? Maximum amount of Anisotropic Filtering used.
function love.graphics.setDefaultFilter(min, mag, anisotropy)
end

---Sets the default mipmap filter used by Textures created afterwards.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setDefaultMipmapFilter)
---
---@param filtermode (love.graphics.MipmapFilterMode)? The mipmap filter mode. nil means 'none'.
---@param sharpness (number)? Value that makes mipmap levels appear sharper (positive) or blurrier (negative).
function love.graphics.setDefaultMipmapFilter(filtermode, sharpness)
end

---Configures depth testing and writing to the depth buffer.
---
---This is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setDepthMode)
---
---@param comparemode love.graphics.CompareMode Depth comparison mode used for depth testing.
---@param write boolean Whether to write update / write values to the depth buffer when rendering.
function love.graphics.setDepthMode(comparemode, write)
end

---Configures depth testing and writing to the depth buffer.
---
---This is low-level functionality designed for use with custom vertex shaders and Meshes with custom vertex attributes. No higher level APIs are provided to set the depth of 2D graphics such as shapes, lines, and Images.
---
---Disables depth testing and depth writes.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setDepthMode)
---
function love.graphics.setDepthMode()
end

---Set an already-loaded Font as the current font or create and load a new one from the file and size.
---
---It's recommended that Font objects are created with love.graphics.newFont in the loading stage and then passed to this function in the drawing stage.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setFont)
---
---@param font love.graphics.Font The Font object to use.
function love.graphics.setFont(font)
end

---Sets whether triangles with clockwise- or counterclockwise-ordered vertices are considered front-facing.
---
---This is designed for use in combination with Mesh face culling. Other love.graphics shapes, lines, and sprites are not guaranteed to have a specific winding order to their internal vertices.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setFrontFaceWinding)
---
---@param winding love.graphics.VertexWinding The winding mode to use. The default winding is counterclockwise ('ccw').
function love.graphics.setFrontFaceWinding(winding)
end

---Sets the line join style. See LineJoin for the possible options.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setLineJoin)
---
---@param join love.graphics.LineJoin The LineJoin to use.
function love.graphics.setLineJoin(join)
end

---Sets the line style.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setLineStyle)
---
---@param style love.graphics.LineStyle The LineStyle to use. Line styles include smooth and rough.
function love.graphics.setLineStyle(style)
end

---Sets the line width.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setLineWidth)
---
---@param width number The width of the line.
function love.graphics.setLineWidth(width)
end

---Sets whether back-facing triangles in a Mesh are culled.
---
---This is designed for use with low level custom hardware-accelerated 3D rendering via custom vertex attributes on Meshes, custom vertex shaders, and depth testing with a depth buffer.
---
---By default, both front- and back-facing triangles in Meshes are rendered.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setMeshCullMode)
---
---@param mode love.graphics.CullMode The Mesh face culling mode to use (whether to render everything, cull back-facing triangles, or cull front-facing triangles).
function love.graphics.setMeshCullMode(mode)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from a TrueType or BMFont file with default settings.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData The font file.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(filename)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from a TrueType file.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData|love.Data The TrueType font file, or Data holding it.
---@param size (number)? The size of the font in pixels.
---@param hinting (love.font.HintingMode)? TrueType hinting mode.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(filename, size, hinting, dpiscale)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from a TrueType file with a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData|love.Data The TrueType font file, or Data holding it.
---@param size (number)? The size of the font in pixels.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} TrueType font settings.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(filename, size, settings)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from a BMFont file and its glyph images.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param filename string|love.filesystem.File|love.filesystem.FileData The BMFont .fnt file.
---@param imagefilename string|love.filesystem.File|love.filesystem.FileData|love.image.ImageData|table The glyph page image, or an array of them. Taken from the .fnt file when nil.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(filename, imagefilename, dpiscale)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from the default TrueType font.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param size (number)? The size of the font in pixels.
---@param hinting (love.font.HintingMode)? TrueType hinting mode.
---@param dpiscale (number)? The DPI scale of the font.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(size, hinting, dpiscale)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from the default TrueType font with a settings table.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param size (number)? The size of the font in pixels.
---@param settings {hinting: (love.font.HintingMode)?, dpiscale: (number)?, sdf: (boolean)?} TrueType font settings.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(size, settings)
end

---Deprecated, with no replacement. Creates a new Font, makes it the current font and returns it. Takes the same arguments as love.graphics.newFont.
---
---Creates a Font from an existing Rasterizer.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setNewFont)
---
---@param rasterizer love.font.Rasterizer The Rasterizer holding the glyphs.
---@return love.graphics.Font font The new Font.
function love.graphics.setNewFont(rasterizer)
end

---Sets the point size.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setPointSize)
---
---@param size number The new point size.
function love.graphics.setPointSize(size)
end

---Sets the projection matrix used for subsequent draws. love.graphics.resetProjection restores the default orthographic projection.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setProjection)
---
---@param transform love.math.Transform The Transform whose matrix becomes the projection.
function love.graphics.setProjection(transform)
end

---Sets the projection matrix used for subsequent draws. love.graphics.resetProjection restores the default orthographic projection.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setProjection)
---
---@param layout (love.math.MatrixLayout)? Whether the matrix is given row by row or column by column.
---@param matrix table The 16 matrix elements as a flat table, or as 4 tables of 4 numbers.
function love.graphics.setProjection(layout, matrix)
end

---Sets the projection matrix used for subsequent draws. love.graphics.resetProjection restores the default orthographic projection.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setProjection)
---
---@param layout (love.math.MatrixLayout)? Whether the matrix is given row by row or column by column.
---@param ... number The 16 matrix elements.
function love.graphics.setProjection(layout, ...)
end

---Sets or disables scissor.
---
---The scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear. 
---
---The dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).
---
---Limits the drawing area to a specified rectangle. 
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setScissor)
---
---@param x number x coordinate of upper left corner.
---@param y number y coordinate of upper left corner.
---@param width number width of clipping rectangle.
---@param height number height of clipping rectangle.
function love.graphics.setScissor(x, y, width, height)
end

---Sets or disables scissor.
---
---The scissor limits the drawing area to a specified rectangle. This affects all graphics calls, including love.graphics.clear. 
---
---The dimensions of the scissor is unaffected by graphical transformations (translate, scale, ...).
---
---Disables scissor.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setScissor)
---
function love.graphics.setScissor()
end

---Sets or resets a Shader as the current pixel effect or vertex shaders. All drawing operations until the next ''love.graphics.setShader'' will be drawn using the Shader object specified.
---
---Sets the current shader to a specified Shader. All drawing operations until the next ''love.graphics.setShader'' will be drawn using the Shader object specified.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setShader)
---
---@param shader love.graphics.Shader The new shader.
function love.graphics.setShader(shader)
end

---Sets or resets a Shader as the current pixel effect or vertex shaders. All drawing operations until the next ''love.graphics.setShader'' will be drawn using the Shader object specified.
---
---Disables shaders, allowing unfiltered drawing operations.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setShader)
---
function love.graphics.setShader()
end

---Sets a high level stencil mode for subsequent draws. For full control see love.graphics.setStencilState.
---
---The 'draw' mode also disables the color mask so draws only write stencil values; other modes re-enable it.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilMode)
---
---@param mode love.graphics.StencilMode The stencil mode to use.
---@param value (number)? The stencil value to write with 'draw' or compare against with 'test'.
function love.graphics.setStencilMode(mode, value)
end

---Sets a high level stencil mode for subsequent draws. For full control see love.graphics.setStencilState.
---
---The 'draw' mode also disables the color mask so draws only write stencil values; other modes re-enable it.
---
---Turns stencil writing and testing off and re-enables the color mask.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilMode)
---
function love.graphics.setStencilMode()
end

---Low-level function to configure the per-pixel stencil buffer for subsequent draws. For a simpler API see love.graphics.setStencilMode.
---
---Unlike love.graphics.setStencilMode this does not change the color mask.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilState)
---
---@param action love.graphics.StencilAction How to modify the stencil values of pixels touched by subsequent draws.
---@param comparemode love.graphics.CompareMode The comparison between value and each pixel's stencil value that decides whether the pixel is drawn.
---@param value (number)? The value to compare against, and the value written by the 'replace' action.
---@param readmask (number)? A bit mask applied to stencil values read in subsequent draws.
---@param writemask (number)? A bit mask applied to stencil values written in subsequent draws.
function love.graphics.setStencilState(action, comparemode, value, readmask, writemask)
end

---Low-level function to configure the per-pixel stencil buffer for subsequent draws. For a simpler API see love.graphics.setStencilMode.
---
---Unlike love.graphics.setStencilMode this does not change the color mask.
---
---Resets the stencil state: no stencil writes, and every pixel passes the test.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilState)
---
function love.graphics.setStencilState()
end

---Deprecated: use love.graphics.setStencilMode or love.graphics.setStencilState. Sets a stencil test for subsequent draws, keeping stencil values unchanged.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilTest)
---
---@param comparemode love.graphics.CompareMode The comparison between value and each pixel's stencil value that decides whether the pixel is drawn.
---@param comparevalue (number)? The value to compare against.
function love.graphics.setStencilTest(comparemode, comparevalue)
end

---Deprecated: use love.graphics.setStencilMode or love.graphics.setStencilState. Sets a stencil test for subsequent draws, keeping stencil values unchanged.
---
---Disables stencil testing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setStencilTest)
---
function love.graphics.setStencilTest()
end

---Sets whether wireframe lines will be used when drawing.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.setWireframe)
---
---@param enable boolean True to enable wireframe mode when drawing, false to disable it.
function love.graphics.setWireframe(enable)
end

---Shears the coordinate system.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.shear)
---
---@param kx number The shear factor on the x-axis.
---@param ky number The shear factor on the y-axis.
function love.graphics.shear(kx, ky)
end

---Deprecated: use love.graphics.setStencilMode or love.graphics.setStencilState. Draws geometry as a stencil: calls a function with stencil writing enabled and the color mask disabled, then restores the previous stencil state and color mask.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.stencil)
---
---@param stencilfunction function Function which draws geometry. The stencil values of pixels it touches are set according to action.
---@param action (love.graphics.StencilAction)? How to modify any stencil values of pixels that are touched by what's drawn in the stencil function.
---@param value (number)? The new stencil value to use for pixels if the 'replace' stencil action is used.
---@param keepvalues (boolean)? True to preserve old stencil values of pixels, false to clear the stencil buffer to 0 first.
function love.graphics.stencil(stencilfunction, action, value, keepvalues)
end

---Converts the given 2D position from global coordinates into screen-space.
---
---This effectively applies the current graphics transformations to the given position. A similar Transform:transformPoint method exists for Transform objects.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.transformPoint)
---
---@param globalX number The x component of the position in global coordinates.
---@param globalY number The y component of the position in global coordinates.
---@return number screenX The x component of the position with graphics transformations applied.
---@return number screenY The y component of the position with graphics transformations applied.
function love.graphics.transformPoint(globalX, globalY)
end

---Translates the coordinate system in two dimensions.
---
---When this function is called with two numbers, dx, and dy, all the following drawing operations take effect as if their x and y coordinates were x+dx and y+dy. 
---
---Scale and translate are not commutative operations, therefore, calling them in different orders will change the outcome.
---
---This change lasts until love.draw() exits or else a love.graphics.pop reverts to a previous love.graphics.push.
---
---Translating using whole numbers will prevent tearing/blurring of images and fonts draw after translating.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.translate)
---
---@param dx number The translation relative to the x-axis.
---@param dy number The translation relative to the y-axis.
function love.graphics.translate(dx, dy)
end

---Checks whether shader code compiles, without creating a Shader.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.validateShader)
---
---@param gles boolean Validate the code as GLSL ES.
---@param code string|love.filesystem.File|love.filesystem.FileData The shader code (any stages), or a file containing it.
---@param options ({defines: (table)?, debugname: (string)?, write: (boolean)?})? Compile options.
---@return boolean status true if the shader code has no errors.
---@return string message The reason validation failed. Not returned when it succeeds.
function love.graphics.validateShader(gles, code, options)
end

---Checks whether shader code compiles, without creating a Shader.
---
---[Open in Browser](https://love2d.org/wiki/love.graphics.validateShader)
---
---@param gles boolean Validate the code as GLSL ES.
---@param pixelcode string|love.filesystem.File|love.filesystem.FileData The pixel shader code, or a file containing it.
---@param vertexcode string|love.filesystem.File|love.filesystem.FileData The vertex shader code, or a file containing it.
---@param options ({defines: (table)?, debugname: (string)?, write: (boolean)?})? Compile options.
---@return boolean status true if the shader code has no errors.
---@return string message The reason validation failed. Not returned when it succeeds.
function love.graphics.validateShader(gles, pixelcode, vertexcode, options)
end

---Provides an interface to decode encoded image data.
---
---[Open in Browser](https://love2d.org/wiki/love.image)
---
---@class love.image
love.image = {}

---Encoded image formats that ImageData:encode can write.
---
---[Open in Browser](https://love2d.org/wiki/ImageFormat)
---
---@alias love.image.ImageFormat
---Targa image format. Only ImageData with the rgba8 pixel format can be encoded.
---| "tga"
---PNG image format. Only ImageData with the rgba8 or rgba16 pixel formats can be encoded.
---| "png"
---OpenEXR image format. Only ImageData with the r16f, r32f, r32ui, rg16f, rg32f, rg32ui, rgba16f, rgba32f or rgba32ui pixel formats can be encoded.
---| "exr"
---QOI (Quite OK Image) format. Only ImageData with the rgba8 pixel format can be encoded.
---| "qoi"
---@alias love.ImageFormat love.image.ImageFormat

---Pixel formats for Textures, ImageData, and CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/PixelFormat)
---
---@alias love.image.PixelFormat
---Indicates unknown pixel format, used internally.
---| "unknown"
---Alias for rgba8, or srgba8 if gamma-correct rendering is enabled.
---| "normal"
---A format suitable for high dynamic range content - an alias for the rgba16f format, normally.
---| "hdr"
---Single-channel (red component) format (8 bpp).
---| "r8"
---Single-channel (red component) signed integer format (8 bpp).
---| "r8i"
---Single-channel (red component) unsigned integer format (8 bpp).
---| "r8ui"
---Single-channel (red component) format (16 bpp).
---| "r16"
---Floating point single-channel format (16 bpp). Color values can range from [-65504, +65504].
---| "r16f"
---Single-channel (red component) signed integer format (16 bpp).
---| "r16i"
---Single-channel (red component) unsigned integer format (16 bpp).
---| "r16ui"
---Floating point single-channel format (32 bpp).
---| "r32f"
---Single-channel (red component) signed integer format (32 bpp).
---| "r32i"
---Single-channel (red component) unsigned integer format (32 bpp).
---| "r32ui"
---Two channels (red and green components) with 8 bits per channel (16 bpp).
---| "rg8"
---Two-channel signed integer format with 8 bits per channel (16 bpp).
---| "rg8i"
---Two-channel unsigned integer format with 8 bits per channel (16 bpp).
---| "rg8ui"
---Same as rg8, but accessed as (L, L, L, A)
---| "la8"
---Two channels (red and green components) with 16 bits per channel (32 bpp).
---| "rg16"
---Floating point two-channel format with 16 bits per channel (32 bpp). Color values can range from [-65504, +65504].
---| "rg16f"
---Two-channel signed integer format with 16 bits per channel (32 bpp).
---| "rg16i"
---Two-channel unsigned integer format with 16 bits per channel (32 bpp).
---| "rg16ui"
---Floating point two-channel format with 32 bits per channel (64 bpp).
---| "rg32f"
---Two-channel signed integer format with 32 bits per channel (64 bpp).
---| "rg32i"
---Two-channel unsigned integer format with 32 bits per channel (64 bpp).
---| "rg32ui"
---8 bits per channel (32 bpp) RGBA. Color channel values range from 0-255 (0-1 in shaders).
---| "rgba8"
---Gamma-correct (sRGB) version of rgba8.
---| "srgba8"
---8 bits per channel (32 bpp) BGRA.
---| "bgra8"
---Gamma-correct (sRGB) version of bgra8.
---| "bgra8srgb"
---RGBA signed integer format with 8 bits per channel (32 bpp).
---| "rgba8i"
---RGBA unsigned integer format with 8 bits per channel (32 bpp).
---| "rgba8ui"
---16 bits per channel (64 bpp) RGBA. Color channel values range from 0-65535 (0-1 in shaders).
---| "rgba16"
---Floating point RGBA with 16 bits per channel (64 bpp). Color values can range from [-65504, +65504].
---| "rgba16f"
---RGBA signed integer format with 16 bits per channel (64 bpp).
---| "rgba16i"
---RGBA unsigned integer format with 16 bits per channel (64 bpp).
---| "rgba16ui"
---Floating point RGBA with 32 bits per channel (128 bpp).
---| "rgba32f"
---RGBA signed integer format with 32 bits per channel (128 bpp).
---| "rgba32i"
---RGBA unsigned integer format with 32 bits per channel (128 bpp).
---| "rgba32ui"
---4 bits per channel (16 bpp) RGBA.
---| "rgba4"
---RGB with 5 bits each, and a 1-bit alpha channel (16 bpp).
---| "rgb5a1"
---RGB with 5, 6, and 5 bits each, respectively (16 bpp). There is no alpha channel in this format.
---| "rgb565"
---RGB with 10 bits per channel, and a 2-bit alpha channel (32 bpp).
---| "rgb10a2"
---Unsigned integer RGB with 10 bits per channel, and a 2-bit alpha channel (32 bpp).
---| "rgb10a2ui"
---Floating point RGB with 11 bits in the red and green channels, and 10 bits in the blue channel (32 bpp). There is no alpha channel. Color values can range from [0, +65024].
---| "rg11b10f"
---No depth buffer and 8-bit stencil buffer.
---| "stencil8"
---16-bit depth buffer and no stencil buffer.
---| "depth16"
---24-bit depth buffer and no stencil buffer.
---| "depth24"
---32-bit float depth buffer and no stencil buffer.
---| "depth32f"
---24-bit depth buffer and 8-bit stencil buffer.
---| "depth24stencil8"
---32-bit float depth buffer and 8-bit stencil buffer.
---| "depth32fstencil8"
---The DXT1 format. RGB data at 4 bits per pixel (compared to 32 bits for ImageData and regular Images.) Suitable for fully opaque images on desktop systems.
---| "DXT1"
---Gamma-correct (sRGB) version of DXT1.
---| "DXT1srgb"
---The DXT3 format. RGBA data at 8 bits per pixel. Smooth variations in opacity do not mix well with this format.
---| "DXT3"
---Gamma-correct (sRGB) version of DXT3.
---| "DXT3srgb"
---The DXT5 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on desktop systems.
---| "DXT5"
---Gamma-correct (sRGB) version of DXT5.
---| "DXT5srgb"
---The BC4 format (also known as 3Dc+ or ATI1.) Stores just the red channel, at 4 bits per pixel.
---| "BC4"
---The signed variant of the BC4 format. Same as above but pixel values in the texture are in the range of [-1, 1] instead of [0, 1] in shaders.
---| "BC4s"
---The BC5 format (also known as 3Dc or ATI2.) Stores red and green channels at 8 bits per pixel.
---| "BC5"
---The signed variant of the BC5 format.
---| "BC5s"
---The BC6H format. Stores half-precision floating-point RGB data in the range of [0, 65504] at 8 bits per pixel. Suitable for HDR images on desktop systems.
---| "BC6h"
---The signed variant of the BC6H format. Stores RGB data in the range of [-65504, +65504].
---| "BC6hs"
---The BC7 format (also known as BPTC.) Stores RGB or RGBA data at 8 bits per pixel.
---| "BC7"
---Gamma-correct (sRGB) version of BC7.
---| "BC7srgb"
---The 2 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 2 bits per pixel. Textures compressed with PVRTC1 formats must be square and power-of-two sized.
---| "PVR1rgb2"
---Gamma-correct (sRGB) version of PVR1rgb2.
---| "PVR1rgb2srgb"
---The 4 bit per pixel RGB variant of the PVRTC1 format. Stores RGB data at 4 bits per pixel.
---| "PVR1rgb4"
---Gamma-correct (sRGB) version of PVR1rgb4.
---| "PVR1rgb4srgb"
---The 2 bit per pixel RGBA variant of the PVRTC1 format.
---| "PVR1rgba2"
---Gamma-correct (sRGB) version of PVR1rgba2.
---| "PVR1rgba2srgb"
---The 4 bit per pixel RGBA variant of the PVRTC1 format.
---| "PVR1rgba4"
---Gamma-correct (sRGB) version of PVR1rgba4.
---| "PVR1rgba4srgb"
---The ETC1 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on older Android devices.
---| "ETC1"
---The RGB variant of the ETC2 format. RGB data at 4 bits per pixel. Suitable for fully opaque images on newer mobile devices.
---| "ETC2rgb"
---Gamma-correct (sRGB) version of ETC2rgb.
---| "ETC2srgb"
---The RGBA variant of the ETC2 format. RGBA data at 8 bits per pixel. Recommended for images with varying opacity on newer mobile devices.
---| "ETC2rgba"
---Gamma-correct (sRGB) version of ETC2rgba.
---| "ETC2srgba"
---The RGBA variant of the ETC2 format where pixels are either fully transparent or fully opaque. RGBA data at 4 bits per pixel.
---| "ETC2rgba1"
---Gamma-correct (sRGB) version of ETC2rgba1.
---| "ETC2srgba1"
---The single-channel variant of the EAC format. Stores just the red channel, at 4 bits per pixel.
---| "EACr"
---The signed single-channel variant of the EAC format. Same as above but pixel values in the texture are in the range of [-1, 1] instead of [0, 1] in shaders.
---| "EACrs"
---The two-channel variant of the EAC format. Stores red and green channels at 8 bits per pixel.
---| "EACrg"
---The signed two-channel variant of the EAC format.
---| "EACrgs"
---The 4x4 pixels per block variant of the ASTC format. RGBA data at 8 bits per pixel.
---| "ASTC4x4"
---The 5x4 pixels per block variant of the ASTC format. RGBA data at 6.4 bits per pixel.
---| "ASTC5x4"
---The 5x5 pixels per block variant of the ASTC format. RGBA data at 5.12 bits per pixel.
---| "ASTC5x5"
---The 6x5 pixels per block variant of the ASTC format. RGBA data at 4.27 bits per pixel.
---| "ASTC6x5"
---The 6x6 pixels per block variant of the ASTC format. RGBA data at 3.56 bits per pixel.
---| "ASTC6x6"
---The 8x5 pixels per block variant of the ASTC format. RGBA data at 3.2 bits per pixel.
---| "ASTC8x5"
---The 8x6 pixels per block variant of the ASTC format. RGBA data at 2.67 bits per pixel.
---| "ASTC8x6"
---The 8x8 pixels per block variant of the ASTC format. RGBA data at 2 bits per pixel.
---| "ASTC8x8"
---The 10x5 pixels per block variant of the ASTC format. RGBA data at 2.56 bits per pixel.
---| "ASTC10x5"
---The 10x6 pixels per block variant of the ASTC format. RGBA data at 2.13 bits per pixel.
---| "ASTC10x6"
---The 10x8 pixels per block variant of the ASTC format. RGBA data at 1.6 bits per pixel.
---| "ASTC10x8"
---The 10x10 pixels per block variant of the ASTC format. RGBA data at 1.28 bits per pixel.
---| "ASTC10x10"
---The 12x10 pixels per block variant of the ASTC format. RGBA data at 1.07 bits per pixel.
---| "ASTC12x10"
---The 12x12 pixels per block variant of the ASTC format. RGBA data at 0.89 bits per pixel.
---| "ASTC12x12"
---Gamma-correct (sRGB) version of ASTC4x4.
---| "ASTC4x4srgb"
---Gamma-correct (sRGB) version of ASTC5x4.
---| "ASTC5x4srgb"
---Gamma-correct (sRGB) version of ASTC5x5.
---| "ASTC5x5srgb"
---Gamma-correct (sRGB) version of ASTC6x5.
---| "ASTC6x5srgb"
---Gamma-correct (sRGB) version of ASTC6x6.
---| "ASTC6x6srgb"
---Gamma-correct (sRGB) version of ASTC8x5.
---| "ASTC8x5srgb"
---Gamma-correct (sRGB) version of ASTC8x6.
---| "ASTC8x6srgb"
---Gamma-correct (sRGB) version of ASTC8x8.
---| "ASTC8x8srgb"
---Gamma-correct (sRGB) version of ASTC10x5.
---| "ASTC10x5srgb"
---Gamma-correct (sRGB) version of ASTC10x6.
---| "ASTC10x6srgb"
---Gamma-correct (sRGB) version of ASTC10x8.
---| "ASTC10x8srgb"
---Gamma-correct (sRGB) version of ASTC10x10.
---| "ASTC10x10srgb"
---Gamma-correct (sRGB) version of ASTC12x10.
---| "ASTC12x10srgb"
---Gamma-correct (sRGB) version of ASTC12x12.
---| "ASTC12x12srgb"
---@alias love.PixelFormat love.image.PixelFormat

---Represents compressed image data designed to stay compressed in RAM.
---
---CompressedImageData encompasses standard compressed texture formats such as  DXT1, DXT5, and BC5 / 3Dc.
---
---You can't draw CompressedImageData directly to the screen. Create a Texture from it with love.graphics.newImage or love.graphics.newTexture for that.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData)
---
---@class love.image.CompressedImageData: love.Data, love.Object
local CompressedImageData = {}
---@alias love.CompressedImageData love.image.CompressedImageData

---Creates a new copy of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:clone)
---
---@return love.image.CompressedImageData clone The new copy.
function CompressedImageData:clone()
end

---Gets the width and height of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getDimensions)
---
---@return number width The width of the CompressedImageData.
---@return number height The height of the CompressedImageData.
function CompressedImageData:getDimensions()
end

---Gets the width and height of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getDimensions)
---
---@param level number A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@return number width The width of a specific mipmap level of the CompressedImageData.
---@return number height The height of a specific mipmap level of the CompressedImageData.
function CompressedImageData:getDimensions(level)
end

---Gets the format of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getFormat)
---
---@return love.image.PixelFormat format The compressed pixel format of the CompressedImageData.
function CompressedImageData:getFormat()
end

---Gets the height of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getHeight)
---
---@return number height The height of the CompressedImageData.
function CompressedImageData:getHeight()
end

---Gets the height of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getHeight)
---
---@param level number A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@return number height The height of a specific mipmap level of the CompressedImageData.
function CompressedImageData:getHeight(level)
end

---Gets the number of mipmap levels in the CompressedImageData. The base mipmap level (original image) is included in the count.
---
---Mipmap filtering cannot be activated for an Image:setMipmapFilter will error. Most tools which can create compressed textures are able to automatically generate mipmaps for them in the same file.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getMipmapCount)
---
---@return number mipmaps The number of mipmap levels stored in the CompressedImageData.
function CompressedImageData:getMipmapCount()
end

---Gets whether the CompressedImageData's pixels are treated as linear rather than sRGB-encoded. When gamma-correct rendering is enabled, a Texture created from CompressedImageData that is not linear uses the sRGB variant of its pixel format. CompressedImageData is not linear by default.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:isLinear)
---
---@return boolean linear Whether the CompressedImageData is treated as linear.
function CompressedImageData:isLinear()
end

---Gets the width of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getWidth)
---
---@return number width The width of the CompressedImageData.
function CompressedImageData:getWidth()
end

---Gets the width of the CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:getWidth)
---
---@param level number A mipmap level. Must be in the range of CompressedImageData:getMipmapCount().
---@return number width The width of a specific mipmap level of the CompressedImageData.
function CompressedImageData:getWidth(level)
end

---Sets whether the CompressedImageData's pixels are treated as linear rather than sRGB-encoded. When gamma-correct rendering is enabled, a Texture created from CompressedImageData that is not linear uses the sRGB variant of its pixel format.
---
---[Open in Browser](https://love2d.org/wiki/CompressedImageData:setLinear)
---
---@param linear boolean Whether the CompressedImageData is treated as linear.
function CompressedImageData:setLinear(linear)
end

---Raw (decoded) image data.
---
---You can't draw ImageData directly to screen. See Image for that.
---
---[Open in Browser](https://love2d.org/wiki/ImageData)
---
---@class love.image.ImageData: love.Data, love.Object
local ImageData = {}
---@alias love.ImageData love.image.ImageData

---Creates a new copy of the ImageData, including its pixel format and linear flag.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:clone)
---
---@return love.image.ImageData clone The new copy.
function ImageData:clone()
end

---Encodes the ImageData and optionally writes it to the save directory. Raises an error if no encoder for the format supports the ImageData's pixel format.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:encode)
---
---@param format love.image.ImageFormat The format to encode the image as.
---@param filename (string)? The filename to write the file to. If nil, no file will be written but the FileData will still be returned, named 'Image.' followed by the format.
---@return love.filesystem.FileData filedata The encoded image as a new FileData object.
function ImageData:encode(format, filename)
end

---Gets the width and height of the ImageData in pixels.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:getDimensions)
---
---@return number width The width of the ImageData in pixels.
---@return number height The height of the ImageData in pixels.
function ImageData:getDimensions()
end

---Gets the height of the ImageData in pixels.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:getHeight)
---
---@return number height The height of the ImageData in pixels.
function ImageData:getHeight()
end

---Gets the color of a pixel at a specific position in the image.
---
---Valid x and y values start at 0 and go up to image width and height minus 1. Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:getPixel)
---
---@param x number The position of the pixel on the x-axis.
---@param y number The position of the pixel on the y-axis.
---@return number r The red component (0-1).
---@return number g The green component (0-1).
---@return number b The blue component (0-1).
---@return number a The alpha component (0-1).
function ImageData:getPixel(x, y)
end

---Gets the width of the ImageData in pixels.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:getWidth)
---
---@return number width The width of the ImageData in pixels.
function ImageData:getWidth()
end

---Gets whether the ImageData's pixels are treated as linear rather than sRGB-encoded. When gamma-correct rendering is enabled, a Texture created from ImageData that is not linear uses the sRGB variant of its pixel format. ImageData is not linear by default.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:isLinear)
---
---@return boolean linear Whether the ImageData is treated as linear.
function ImageData:isLinear()
end

---Transform an image by applying a function to every pixel.
---
---This function is a higher-order function. It takes another function as a parameter, and calls it once for each pixel in the ImageData.
---
---The passed function is called with six parameters for each pixel in turn. The parameters are numbers that represent the x and y coordinates of the pixel and its red, green, blue and alpha values. The function should return the new red, green, blue, and alpha values for that pixel.
---
---function pixelFunction(x, y, r, g, b, a)
---
---    -- template for defining your own pixel mapping function
---
---    -- perform computations giving the new values for r, g, b and a
---
---    -- ...
---
---    return r, g, b, a
---
---end
---
---[Open in Browser](https://love2d.org/wiki/ImageData:mapPixel)
---
---@param pixelFunction fun(x: number, y: number, r: number, g: number, b: number, a: number):(number,number,number,number) Function to apply to every pixel.
---@param x (number)? The x-axis of the top-left corner of the area within the ImageData to apply the function to.
---@param y (number)? The y-axis of the top-left corner of the area within the ImageData to apply the function to.
---@param width (number)? The width of the area within the ImageData to apply the function to.
---@param height (number)? The height of the area within the ImageData to apply the function to.
function ImageData:mapPixel(pixelFunction, x, y, width, height)
end

---Paste into ImageData from another source ImageData.
---
---Note that this function just replaces the contents in the destination rectangle; it does not do any alpha blending.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:paste)
---
---@param source love.image.ImageData Source ImageData from which to copy.
---@param dx number Destination top-left position on x-axis.
---@param dy number Destination top-left position on y-axis.
---@param sx (number)? Source top-left position on x-axis.
---@param sy (number)? Source top-left position on y-axis.
---@param sw (number)? Source width.
---@param sh (number)? Source height.
function ImageData:paste(source, dx, dy, sx, sy, sw, sh)
end

---Destroys the ImageData's Lua reference, like Object:release. When LuaJIT's FFI is available it also drops the pixel access data the ImageData's Lua methods cache.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:release)
---
---@return boolean success True if the object was released by this call, false if it had been previously released.
function ImageData:release()
end

---Sets the color of a pixel at a specific position in the image.
---
---Valid x and y values start at 0 and go up to image width and height minus 1. Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:setPixel)
---
---@param x number The position of the pixel on the x-axis.
---@param y number The position of the pixel on the y-axis.
---@param r number The red component (0-1).
---@param g number The green component (0-1).
---@param b number The blue component (0-1).
---@param a (number)? The alpha component (0-1).
function ImageData:setPixel(x, y, r, g, b, a)
end

---Sets the color of a pixel at a specific position in the image.
---
---Valid x and y values start at 0 and go up to image width and height minus 1. Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:setPixel)
---
---@param x number The position of the pixel on the x-axis.
---@param y number The position of the pixel on the y-axis.
---@param color (number)[] A numerical indexed table with the red, green, blue and (optionally) alpha values as numbers.
function ImageData:setPixel(x, y, color)
end

---Sets whether the ImageData's pixels are treated as linear rather than sRGB-encoded. When gamma-correct rendering is enabled, a Texture created from ImageData that is not linear uses the sRGB variant of its pixel format.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:setLinear)
---
---@param linear boolean Whether the ImageData is treated as linear.
function ImageData:setLinear(linear)
end

---Gets the pixel format of the ImageData.
---
---[Open in Browser](https://love2d.org/wiki/ImageData:getFormat)
---
---@return love.image.PixelFormat format The pixel format the ImageData was created with.
function ImageData:getFormat()
end

---Determines whether a file can be loaded as CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/love.image.isCompressed)
---
---@param filename string|love.filesystem.File The filename or File of the potentially compressed image file.
---@return boolean compressed Whether the file can be loaded as CompressedImageData or not.
function love.image.isCompressed(filename)
end

---Determines whether a file can be loaded as CompressedImageData.
---
---[Open in Browser](https://love2d.org/wiki/love.image.isCompressed)
---
---@param data love.Data A Data object (such as a FileData) potentially containing a compressed image.
---@return boolean compressed Whether the Data can be loaded as CompressedImageData or not.
function love.image.isCompressed(data)
end

---Create a new CompressedImageData object from a compressed image file (such as DDS, KTX, PVR or ASTC). The formats it can hold are the compressed PixelFormats.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newCompressedData)
---
---@param filename string|love.filesystem.File The filename or File of the compressed image file.
---@return love.image.CompressedImageData compressedImageData The new CompressedImageData object.
function love.image.newCompressedData(filename)
end

---Create a new CompressedImageData object from a compressed image file (such as DDS, KTX, PVR or ASTC). The formats it can hold are the compressed PixelFormats.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newCompressedData)
---
---@param data love.Data A Data object (such as a FileData) containing a compressed image.
---@return love.image.CompressedImageData compressedImageData The new CompressedImageData object.
function love.image.newCompressedData(data)
end

---Splits an ImageData holding the six faces of a cube map into six new ImageData objects, ordered +x, -x, +y, -y, +z, -z. The source layout is detected from its dimensions: a 3x4 or 4x3 cross of square faces, or the six faces stacked vertically or placed side by side horizontally. Raises an error if the dimensions match none of these layouts.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newCubeFaces)
---
---@param imagedata love.image.ImageData The ImageData containing all six cube faces.
---@return love.image.ImageData px The +x face.
---@return love.image.ImageData nx The -x face.
---@return love.image.ImageData py The +y face.
---@return love.image.ImageData ny The -y face.
---@return love.image.ImageData pz The +z face.
---@return love.image.ImageData nz The -z face.
function love.image.newCubeFaces(imagedata)
end

---Creates a new ImageData object.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newImageData)
---
---@param width number The width of the ImageData.
---@param height number The height of the ImageData.
---@param format (love.image.PixelFormat)? The pixel format of the ImageData.
---@param rawdata (string|love.Data)? Optional raw byte data to load into the ImageData, in the format specified by ''format''. Its size must match the ImageData's size in bytes. Without it every pixel's components (including alpha) are zero.
---@return love.image.ImageData imageData The new ImageData object.
function love.image.newImageData(width, height, format, rawdata)
end

---Creates a new ImageData object.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newImageData)
---
---@param filename string|love.filesystem.File The filename or File of the image file.
---@return love.image.ImageData imageData The new ImageData object.
function love.image.newImageData(filename)
end

---Creates a new ImageData object.
---
---[Open in Browser](https://love2d.org/wiki/love.image.newImageData)
---
---@param filedata love.Data The encoded file data (such as a FileData) to decode into image data.
---@return love.image.ImageData imageData The new ImageData object.
function love.image.newImageData(filedata)
end

---Provides an interface to the user's joystick.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick)
---
---@class love.joystick
love.joystick = {}

---Virtual gamepad axes.
---
---[Open in Browser](https://love2d.org/wiki/GamepadAxis)
---
---@alias love.joystick.GamepadAxis
---The x-axis of the left thumbstick.
---| "leftx"
---The y-axis of the left thumbstick.
---| "lefty"
---The x-axis of the right thumbstick.
---| "rightx"
---The y-axis of the right thumbstick.
---| "righty"
---Left analog trigger.
---| "triggerleft"
---Right analog trigger.
---| "triggerright"
---@alias love.GamepadAxis love.joystick.GamepadAxis

---Virtual gamepad buttons.
---
---[Open in Browser](https://love2d.org/wiki/GamepadButton)
---
---@alias love.joystick.GamepadButton
---Bottom face button (A).
---| "a"
---Right face button (B).
---| "b"
---Left face button (X).
---| "x"
---Top face button (Y).
---| "y"
---Back button.
---| "back"
---Guide button.
---| "guide"
---Start button.
---| "start"
---Left stick click button.
---| "leftstick"
---Right stick click button.
---| "rightstick"
---Left bumper.
---| "leftshoulder"
---Right bumper.
---| "rightshoulder"
---D-pad up.
---| "dpup"
---D-pad down.
---| "dpdown"
---D-pad left.
---| "dpleft"
---D-pad right.
---| "dpright"
---Xbox Series X controller share button, PS5 controller mic button, and Switch Pro controller capture button.
---| "misc1"
---First paddle button.
---| "paddle1"
---Second paddle button.
---| "paddle2"
---Third paddle button.
---| "paddle3"
---Fourth paddle button.
---| "paddle4"
---Controller touchpad press.
---| "touchpad"
---@alias love.GamepadButton love.joystick.GamepadButton

---Types of gamepad controllers.
---
---[Open in Browser](https://love2d.org/wiki/GamepadType)
---
---@alias love.joystick.GamepadType
---An unrecognized gamepad type.
---| "unknown"
---Xbox 360 controller.
---| "xbox360"
---Xbox One controller.
---| "xboxone"
---PS3 (Dualshock 3) controller.
---| "ps3"
---PS4 (Dualshock 4) controller.
---| "ps4"
---PS5 (Dualsense) controller.
---| "ps5"
---Switch Pro controller.
---| "switchpro"
---Amazon Luna controller.
---| "amazonluna"
---Stadia controller.
---| "stadia"
---Software-based gamepad whose state is set programmatically.
---| "virtual"
---nvidia Shield controller.
---| "shield"
---Left-hand joycon.
---| "joyconleft"
---Right-hand joycon.
---| "joyconright"
---Both left- and right-hand joycons together.
---| "joyconpair"
---@alias love.GamepadType love.joystick.GamepadType

---How a Joystick is connected to the system.
---
---[Open in Browser](https://love2d.org/wiki/JoystickConnectionType)
---
---@alias love.joystick.JoystickConnectionType
---The connection type can't be determined.
---| "unknown"
---Connected with a cable.
---| "wired"
---Connected wirelessly.
---| "wireless"
---@alias love.JoystickConnectionType love.joystick.JoystickConnectionType

---Joystick hat positions.
---
---[Open in Browser](https://love2d.org/wiki/JoystickHat)
---
---@alias love.joystick.JoystickHat
---Centered
---| "c"
---Down
---| "d"
---Left
---| "l"
---Left+Down
---| "ld"
---Left+Up
---| "lu"
---Right
---| "r"
---Right+Down
---| "rd"
---Right+Up
---| "ru"
---Up
---| "u"
---@alias love.JoystickHat love.joystick.JoystickHat

---Types of Joystick inputs.
---
---[Open in Browser](https://love2d.org/wiki/JoystickInputType)
---
---@alias love.joystick.JoystickInputType
---Analog axis.
---| "axis"
---Button.
---| "button"
---8-direction hat value.
---| "hat"
---@alias love.JoystickInputType love.joystick.JoystickInputType

---The battery state of a Joystick.
---
---[Open in Browser](https://love2d.org/wiki/JoystickPowerType)
---
---@alias love.joystick.JoystickPowerType
---The battery state can't be determined.
---| "unknown"
---Running on battery, not charging.
---| "onbattery"
---Plugged in, with no battery.
---| "nobattery"
---The battery is charging.
---| "charging"
---The battery is fully charged and plugged in.
---| "charged"
---@alias love.JoystickPowerType love.joystick.JoystickPowerType

---Types of Joysticks.
---
---[Open in Browser](https://love2d.org/wiki/JoystickType)
---
---@alias love.joystick.JoystickType
---An unrecognized joystick type.
---| "unknown"
---A gamepad.
---| "gamepad"
---Steering / racing wheel.
---| "wheel"
---Fighting game arcade stick.
---| "arcadestick"
---HOTAS / flight stick.
---| "flightstick"
---Dance pad.
---| "dancepad"
---Guitar.
---| "guitar"
---Drum kit.
---| "drumkit"
---Arcade pad.
---| "arcadepad"
---Standard throttle.
---| "throttle"
---@alias love.JoystickType love.joystick.JoystickType

---Represents a physical joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick)
---
---@class love.joystick.Joystick: love.Object
local Joystick = {}
---@alias love.Joystick love.joystick.Joystick

---Gets the direction of each axis.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getAxes)
---
---@return number axisDir1 Direction of axis1.
---@return number axisDir2 Direction of axis2.
---@return number axisDirN Direction of axisN.
function Joystick:getAxes()
end

---Gets the direction of an axis.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getAxis)
---
---@param axis number The index of the axis to be checked.
---@return number direction Current value of the axis.
function Joystick:getAxis(axis)
end

---Gets the number of axes on the joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getAxisCount)
---
---@return number axes The number of axes available.
function Joystick:getAxisCount()
end

---Gets the number of buttons on the joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getButtonCount)
---
---@return number buttons The number of buttons available.
function Joystick:getButtonCount()
end

---Gets the index of this Joystick in the list returned by love.joystick.getJoysticks.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getConnectedIndex)
---
---@return number|nil index The 1-based index of the Joystick in the list of connected Joysticks, or nil if it isn't connected.
function Joystick:getConnectedIndex()
end

---Gets whether the Joystick is connected with a cable or wirelessly.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getDeviceConnectionState)
---
---@return love.joystick.JoystickConnectionType state How the Joystick is connected.
function Joystick:getDeviceConnectionState()
end

---Gets the USB vendor ID, product ID, and product version numbers of joystick which consistent across operating systems.
---
---Can be used to show different icons, etc. for different gamepads.
---
---Some Linux distribution may not ship with SDL 2.0.6 or later, in which case this function will returns 0 for all the three values.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getDeviceInfo)
---
---@return number vendorID The USB vendor ID of the joystick.
---@return number productID The USB product ID of the joystick.
---@return number productVersion The product version of the joystick.
function Joystick:getDeviceInfo()
end

---Gets the battery state of the Joystick and its remaining charge.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getDevicePowerInfo)
---
---@return love.joystick.JoystickPowerType state The battery state of the Joystick.
---@return number|nil percent The remaining battery charge in percent, or nil if it can't be determined.
function Joystick:getDevicePowerInfo()
end

---Gets a stable GUID unique to the type of the physical joystick which does not change over time. For example, all Sony Dualshock 3 controllers in OS X have the same GUID. The value is platform-dependent.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGUID)
---
---@return string guid The Joystick type's OS-dependent unique identifier.
function Joystick:getGUID()
end

---Gets the direction of a virtual gamepad axis. If the Joystick isn't recognized as a gamepad or isn't connected, this function will always return 0.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGamepadAxis)
---
---@param axis love.joystick.GamepadAxis The virtual axis to be checked.
---@return number direction Current value of the axis.
function Joystick:getGamepadAxis(axis)
end

---Gets the button, axis or hat that a virtual gamepad input is bound to.
---
---Returns nothing if the Joystick isn't recognized as a gamepad or the virtual gamepad axis is not bound to a Joystick input.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGamepadMapping)
---
---@param axis love.joystick.GamepadAxis The virtual gamepad axis to get the binding for.
---@return love.joystick.JoystickInputType inputtype The type of input the virtual gamepad axis is bound to.
---@return number inputindex The index of the Joystick's button, axis or hat that the virtual gamepad axis is bound to.
---@return love.joystick.JoystickHat hatdirection The direction of the hat, if the virtual gamepad axis is bound to a hat. nil otherwise.
function Joystick:getGamepadMapping(axis)
end

---Gets the button, axis or hat that a virtual gamepad input is bound to.
---
---The physical locations for the virtual gamepad axes and buttons correspond as closely as possible to the layout of a standard Xbox 360 controller.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGamepadMapping)
---
---@param button love.joystick.GamepadButton The virtual gamepad button to get the binding for.
---@return love.joystick.JoystickInputType inputtype The type of input the virtual gamepad button is bound to.
---@return number inputindex The index of the Joystick's button, axis or hat that the virtual gamepad button is bound to.
---@return love.joystick.JoystickHat hatdirection The direction of the hat, if the virtual gamepad button is bound to a hat. nil otherwise.
function Joystick:getGamepadMapping(button)
end

---Gets the full gamepad mapping string of this Joystick, or nil if it's not recognized as a gamepad.
---
---The mapping string contains binding information used to map the Joystick's buttons an axes to the standard gamepad layout, and can be used later with love.joystick.loadGamepadMappings.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGamepadMappingString)
---
---@return string|nil mappingstring A string containing the Joystick's gamepad mappings, or nil if the Joystick is not recognized as a gamepad.
function Joystick:getGamepadMappingString()
end

---Gets the GamepadType of the Joystick, if it's recognized as a gamepad.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getGamepadType)
---
---@return love.joystick.GamepadType gamepadtype The type of the gamepad, or "unknown" if it can't be determined.
function Joystick:getGamepadType()
end

---Gets the direction of the Joystick's hat.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getHat)
---
---@param hat number The index of the hat to be checked.
---@return love.joystick.JoystickHat direction The direction the hat is pushed.
function Joystick:getHat(hat)
end

---Gets the number of hats on the joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getHatCount)
---
---@return number hats How many hats the joystick has.
function Joystick:getHatCount()
end

---Gets the joystick's unique identifier. The identifier will remain the same for the life of the game, even when the Joystick is disconnected and reconnected, but it '''will''' change when the game is re-launched.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getID)
---
---@return number id The Joystick's unique identifier. Remains the same as long as the game is running.
---@return number|nil instanceid Unique instance identifier. Changes every time the Joystick is reconnected. nil if the Joystick is not connected.
function Joystick:getID()
end

---Gets the JoystickType of the Joystick.
---JoystickTypes are broader categories than GamepadTypes.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getJoystickType)
---
---@return love.joystick.JoystickType joysticktype The type of the joystick, or "unknown" if it can't be determined.
function Joystick:getJoystickType()
end

---Gets the name of the joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getName)
---
---@return string name The name of the joystick.
function Joystick:getName()
end

---Gets the player index of this Joystick. This corresponds to an indicator light on many common gamepads.
---
---Note that this is independent from the array index of this Joystick in the table returned by love.joystick.getJoysticks.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getPlayerIndex)
---
---@return number index The 1-based player index being used for this Joystick, or -1 if the player index has not been set or cannot be determined.
function Joystick:getPlayerIndex()
end

---Gets the latest data for the given sensor type for this Joystick.
---The returned values have meaning based on the sensor type, for example an accelerometer will return acceleration values along each axis.
---
---If the sensor was not enabled via Joystick:setSensorEnabled, this function may cause an error.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getSensorData)
---
---@param sensorType love.sensor.SensorType The type of sensor.
---@return number x The sensor's current 1st value.
---@return number y The sensor's current 2nd value.
---@return number z The sensor's current 3rd value.
function Joystick:getSensorData(sensorType)
end

---Gets the current vibration motor strengths on a Joystick with rumble support.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:getVibration)
---
---@return number left Current strength of the left vibration motor on the Joystick.
---@return number right Current strength of the right vibration motor on the Joystick.
function Joystick:getVibration()
end

---Gets whether the specified sensor exists in the Joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:hasSensor)
---
---@param sensorType love.sensor.SensorType Type of sensor to check.
---@return boolean available Sensor availability status.
function Joystick:hasSensor(sensorType)
end

---Gets whether the Joystick is connected.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isConnected)
---
---@return boolean connected True if the Joystick is currently connected, false otherwise.
function Joystick:isConnected()
end

---Checks if a button on the Joystick is pressed.
---
---LÖVE 0.9.0 had a bug which required the button indices passed to Joystick:isDown to be 0-based instead of 1-based, for example button 1 would be 0 for this function. It was fixed in 0.9.1.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isDown)
---
---@param button number The index of a button to check.
---@param ... number Additional button indices to check.
---@return boolean anyDown True if any supplied button is down, false if not.
function Joystick:isDown(button, ...)
end

---Checks if a button on the Joystick is pressed.
---
---LÖVE 0.9.0 had a bug which required the button indices passed to Joystick:isDown to be 0-based instead of 1-based, for example button 1 would be 0 for this function. It was fixed in 0.9.1.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isDown)
---
---@param buttons (number)[] A list of button indices to check.
---@return boolean anyDown True if any button in the list is down, false if not.
function Joystick:isDown(buttons)
end

---Gets whether the Joystick is recognized as a gamepad. If this is the case, the Joystick's buttons and axes can be used in a standardized manner across different operating systems and joystick models via Joystick:getGamepadAxis, Joystick:isGamepadDown, love.gamepadpressed, and related functions.
---
---LÖVE automatically recognizes most popular controllers with a similar layout to the Xbox 360 controller as gamepads, but you can add more with love.joystick.setGamepadMapping.
---
---If the Joystick is recognized as a gamepad, the physical locations for the virtual gamepad axes and buttons correspond as closely as possible to the layout of a standard Xbox 360 controller.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isGamepad)
---
---@return boolean isgamepad True if the Joystick is recognized as a gamepad, false otherwise.
function Joystick:isGamepad()
end

---Checks if a virtual gamepad button on the Joystick is pressed. If the Joystick is not recognized as a Gamepad or isn't connected, then this function will always return false.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isGamepadDown)
---
---@param button love.joystick.GamepadButton A gamepad button to check.
---@param ... love.joystick.GamepadButton Additional gamepad buttons to check.
---@return boolean anyDown True if any supplied button is down, false if not.
function Joystick:isGamepadDown(button, ...)
end

---Checks if a virtual gamepad button on the Joystick is pressed. If the Joystick is not recognized as a Gamepad or isn't connected, then this function will always return false.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isGamepadDown)
---
---@param buttons (love.joystick.GamepadButton)[] A list of gamepad buttons to check.
---@return boolean anyDown True if any button in the list is down, false if not.
function Joystick:isGamepadDown(buttons)
end

---Gets whether the specified sensor is currently enabled on this Joystick.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isSensorEnabled)
---
---@param sensorType love.sensor.SensorType Type of sensor to check.
---@return boolean enabled Whether the sensor is currently enabled.
function Joystick:isSensorEnabled(sensorType)
end

---Gets whether the Joystick supports vibration.
---
---The very first call to this function may take more time than expected because SDL's Haptic / Force Feedback subsystem needs to be initialized.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:isVibrationSupported)
---
---@return boolean supported True if rumble / force feedback vibration is supported on this Joystick, false if not.
function Joystick:isVibrationSupported()
end

---Sets the player index of this Joystick. This corresponds to an indicator light on many common gamepads.
---
---Note that this is independent from the array index of this Joystick in the table returned by love.joystick.getJoysticks.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:setPlayerIndex)
---
---@param index number The 1-based player index to use for this Joystick.
function Joystick:setPlayerIndex(index)
end

---Enables or disables the specified sensor on this Joystick.
---
---The given sensor type must exist on this Joystick, otherwise this function may cause an error.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:setSensorEnabled)
---
---@param sensorType love.sensor.SensorType Type of sensor to enable or disable.
---@param enable boolean True to enable the given sensor, false to disable it.
function Joystick:setSensorEnabled(sensorType, enable)
end

---Sets the vibration motor speeds on a Joystick with rumble support. Most common gamepads have this functionality, although not all drivers give proper support. Use Joystick:isVibrationSupported to check.
---
---If the Joystick only has a single vibration motor, it will still work but it will use the largest value of the left and right parameters.
---
---The very first call to this function may take more time than expected because SDL's Haptic / Force Feedback subsystem needs to be initialized.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:setVibration)
---
---@param left number Strength of the left vibration motor on the Joystick. Must be in the range of [0, 1].
---@param right (number)? Strength of the right vibration motor on the Joystick. Must be in the range of [0, 1].
---@param duration (number)? The duration of the vibration in seconds. A negative value means infinite duration.
---@return boolean success True if the vibration was successfully applied, false if not.
function Joystick:setVibration(left, right, duration)
end

---Sets the vibration motor speeds on a Joystick with rumble support. Most common gamepads have this functionality, although not all drivers give proper support. Use Joystick:isVibrationSupported to check.
---
---Disables vibration.
---
---[Open in Browser](https://love2d.org/wiki/Joystick:setVibration)
---
---@return boolean success True if the vibration was successfully disabled, false if not.
function Joystick:setVibration()
end

---Gets the full gamepad mapping string of the Joysticks which have the given GUID, or nil if the GUID isn't recognized as a gamepad.
---
---The mapping string contains binding information used to map the Joystick's buttons an axes to the standard gamepad layout, and can be used later with love.joystick.loadGamepadMappings.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.getGamepadMappingString)
---
---@param guid string The GUID value to get the mapping string for.
---@return string|nil mappingstring A string containing the Joystick's gamepad mappings, or nil if the GUID is not recognized as a gamepad.
function love.joystick.getGamepadMappingString(guid)
end

---Gets the number of connected joysticks.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.getJoystickCount)
---
---@return number joystickcount The number of connected joysticks.
function love.joystick.getJoystickCount()
end

---Gets a list of connected Joysticks.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.getJoysticks)
---
---@return (love.joystick.Joystick)[] joysticks The list of currently connected Joysticks.
function love.joystick.getJoysticks()
end

---Gets whether joystick input events are produced while the window doesn't have focus.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.hasBackgroundEvents)
---
---@return boolean enabled Whether joystick events are produced while the window is in the background.
function love.joystick.hasBackgroundEvents()
end

---Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings.
---
---It also recognizes any SDL gamecontroller mapping string, such as those created with Steam's Big Picture controller configure interface, or this nice database. If a new mapping is loaded for an already known controller GUID, the later version will overwrite the one currently loaded.
---
---Loads a gamepad mappings string from a file.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.loadGamepadMappings)
---
---@param filename string The filename to load the mappings string from.
function love.joystick.loadGamepadMappings(filename)
end

---Loads a gamepad mappings string or file created with love.joystick.saveGamepadMappings.
---
---It also recognizes any SDL gamecontroller mapping string, such as those created with Steam's Big Picture controller configure interface, or this nice database. If a new mapping is loaded for an already known controller GUID, the later version will overwrite the one currently loaded.
---
---Loads a gamepad mappings string directly.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.loadGamepadMappings)
---
---@param mappings string The mappings string to load.
function love.joystick.loadGamepadMappings(mappings)
end

---Saves the virtual gamepad mappings of all recognized as gamepads and have either been recently used or their gamepad bindings have been modified.
---
---The mappings are stored as a string for use with love.joystick.loadGamepadMappings.
---
---Saves the gamepad mappings of all relevant joysticks to a file.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.saveGamepadMappings)
---
---@param filename string The filename to save the mappings string to.
---@return string mappings The mappings string that was written to the file.
function love.joystick.saveGamepadMappings(filename)
end

---Saves the virtual gamepad mappings of all recognized as gamepads and have either been recently used or their gamepad bindings have been modified.
---
---The mappings are stored as a string for use with love.joystick.loadGamepadMappings.
---
---Returns the mappings string without writing to a file.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.saveGamepadMappings)
---
---@return string mappings The mappings string.
function love.joystick.saveGamepadMappings()
end

---Sets whether joystick input events are produced while the window doesn't have focus. They are not by default.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.setBackgroundEvents)
---
---@param enable boolean Whether joystick events should be produced while the window is in the background.
function love.joystick.setBackgroundEvents(enable)
end

---Binds a virtual gamepad input to a button, axis or hat for all Joysticks of a certain type. For example, if this function is used with a GUID returned by a Dualshock 3 controller in OS X, the binding will affect Joystick:getGamepadAxis and Joystick:isGamepadDown for ''all'' Dualshock 3 controllers used with the game when run in OS X.
---
---LÖVE includes built-in gamepad bindings for many common controllers. This function lets you change the bindings or add new ones for types of Joysticks which aren't recognized as gamepads by default.
---
---The virtual gamepad buttons and axes are designed around the Xbox 360 controller layout.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.setGamepadMapping)
---
---@param guid string The OS-dependent GUID for the type of Joystick the binding will affect.
---@param button love.joystick.GamepadButton The virtual gamepad button to bind.
---@param inputtype love.joystick.JoystickInputType The type of input to bind the virtual gamepad button to.
---@param inputindex number The index of the axis, button, or hat to bind the virtual gamepad button to.
---@param hatdir (love.joystick.JoystickHat)? The direction of the hat. Required if inputtype is 'hat', ignored otherwise.
---@return boolean success Whether the virtual gamepad button was successfully bound.
function love.joystick.setGamepadMapping(guid, button, inputtype, inputindex, hatdir)
end

---Binds a virtual gamepad input to a button, axis or hat for all Joysticks of a certain type. For example, if this function is used with a GUID returned by a Dualshock 3 controller in OS X, the binding will affect Joystick:getGamepadAxis and Joystick:isGamepadDown for ''all'' Dualshock 3 controllers used with the game when run in OS X.
---
---LÖVE includes built-in gamepad bindings for many common controllers. This function lets you change the bindings or add new ones for types of Joysticks which aren't recognized as gamepads by default.
---
---The virtual gamepad buttons and axes are designed around the Xbox 360 controller layout.
---
---The physical locations for the bound gamepad axes and buttons should correspond as closely as possible to the layout of a standard Xbox 360 controller.
---
---[Open in Browser](https://love2d.org/wiki/love.joystick.setGamepadMapping)
---
---@param guid string The OS-dependent GUID for the type of Joystick the binding will affect.
---@param axis love.joystick.GamepadAxis The virtual gamepad axis to bind.
---@param inputtype love.joystick.JoystickInputType The type of input to bind the virtual gamepad axis to.
---@param inputindex number The index of the axis, button, or hat to bind the virtual gamepad axis to.
---@param hatdir (love.joystick.JoystickHat)? The direction of the hat. Required if inputtype is 'hat', ignored otherwise.
---@return boolean success Whether the virtual gamepad axis was successfully bound.
function love.joystick.setGamepadMapping(guid, axis, inputtype, inputindex, hatdir)
end

---Provides an interface to the user's keyboard.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard)
---
---@class love.keyboard
love.keyboard = {}

---All the keys you can press. Note that some keys may not be available on your keyboard or system.
---
---A key without a name in this list is reported as the UTF-8 string of its character, and such strings are accepted as keys too.
---
---[Open in Browser](https://love2d.org/wiki/KeyConstant)
---
---@alias love.keyboard.KeyConstant
---An unknown key
---| "unknown"
---Return key
---| "return"
---Escape key
---| "escape"
---Backspace key
---| "backspace"
---Tab key
---| "tab"
---Space key
---| "space"
---Exclamation mark key
---| "!"
---Double quote key
---| """
---Hash key
---| "#"
---Percent key
---| "%"
---Dollar key
---| "$"
---Ampersand key
---| "&"
---Single quote key
---| "'"
---Left parenthesis key
---| "("
---Right parenthesis key
---| ")"
---Asterisk key
---| "*"
---Plus key
---| "+"
---Comma key
---| ","
---Hyphen-minus key
---| "-"
---Full stop key
---| "."
---Slash key
---| "/"
---The zero key
---| "0"
---The one key
---| "1"
---The two key
---| "2"
---The three key
---| "3"
---The four key
---| "4"
---The five key
---| "5"
---The six key
---| "6"
---The seven key
---| "7"
---The eight key
---| "8"
---The nine key
---| "9"
---Colon key
---| ":"
---Semicolon key
---| ";"
---Less-than key
---| "<"
---Equal key
---| "="
---Greater-than key
---| ">"
---Question mark key
---| "?"
---At sign key
---| "@"
---Left square bracket key
---| "["
---Backslash key
---| "\"
---Right square bracket key
---| "]"
---Caret key
---| "^"
---Underscore key
---| "_"
---Grave accent key
---| "`"
---The A key
---| "a"
---The B key
---| "b"
---The C key
---| "c"
---The D key
---| "d"
---The E key
---| "e"
---The F key
---| "f"
---The G key
---| "g"
---The H key
---| "h"
---The I key
---| "i"
---The J key
---| "j"
---The K key
---| "k"
---The L key
---| "l"
---The M key
---| "m"
---The N key
---| "n"
---The O key
---| "o"
---The P key
---| "p"
---The Q key
---| "q"
---The R key
---| "r"
---The S key
---| "s"
---The T key
---| "t"
---The U key
---| "u"
---The V key
---| "v"
---The W key
---| "w"
---The X key
---| "x"
---The Y key
---| "y"
---The Z key
---| "z"
---Caps-lock key
---| "capslock"
---The 1st function key
---| "f1"
---The 2nd function key
---| "f2"
---The 3rd function key
---| "f3"
---The 4th function key
---| "f4"
---The 5th function key
---| "f5"
---The 6th function key
---| "f6"
---The 7th function key
---| "f7"
---The 8th function key
---| "f8"
---The 9th function key
---| "f9"
---The 10th function key
---| "f10"
---The 11th function key
---| "f11"
---The 12th function key
---| "f12"
---Print screen key
---| "printscreen"
---Scroll-lock key
---| "scrolllock"
---Pause key
---| "pause"
---Insert key
---| "insert"
---Home key
---| "home"
---Page up key
---| "pageup"
---Delete key
---| "delete"
---End key
---| "end"
---Page down key
---| "pagedown"
---Right cursor key
---| "right"
---Left cursor key
---| "left"
---Down cursor key
---| "down"
---Up cursor key
---| "up"
---Num-lock key
---| "numlock"
---The numpad division key
---| "kp/"
---The numpad multiplication key
---| "kp*"
---The numpad substraction key
---| "kp-"
---The numpad addition key
---| "kp+"
---The numpad enter key
---| "kpenter"
---The numpad zero key
---| "kp0"
---The numpad one key
---| "kp1"
---The numpad two key
---| "kp2"
---The numpad three key
---| "kp3"
---The numpad four key
---| "kp4"
---The numpad five key
---| "kp5"
---The numpad six key
---| "kp6"
---The numpad seven key
---| "kp7"
---The numpad eight key
---| "kp8"
---The numpad nine key
---| "kp9"
---The numpad decimal point key
---| "kp."
---The numpad comma key
---| "kp,"
---The numpad equals key
---| "kp="
---Application key (the Windows contextual menu key)
---| "application"
---Power key
---| "power"
---The 13th function key
---| "f13"
---The 14th function key
---| "f14"
---The 15th function key
---| "f15"
---The 16th function key
---| "f16"
---The 17th function key
---| "f17"
---The 18th function key
---| "f18"
---The 19th function key
---| "f19"
---The 20th function key
---| "f20"
---The 21th function key
---| "f21"
---The 22th function key
---| "f22"
---The 23th function key
---| "f23"
---The 24th function key
---| "f24"
---Execute key
---| "execute"
---Help key
---| "help"
---Menu key
---| "menu"
---Select key
---| "select"
---Stop key
---| "stop"
---Again key
---| "again"
---Undo key
---| "undo"
---Cut key
---| "cut"
---Copy key
---| "copy"
---Paste key
---| "paste"
---Find key
---| "find"
---Mute key
---| "mute"
---Volume up key
---| "volumeup"
---Volume down key
---| "volumedown"
---Alt-erase key
---| "alterase"
---System request key
---| "sysreq"
---Cancel key
---| "cancel"
---Clear key
---| "clear"
---Prior key
---| "prior"
---Return2 key
---| "return2"
---Separator key
---| "separator"
---Out key
---| "out"
---Oper key
---| "oper"
---Clear-again key
---| "clearagain"
---Thousands separator key
---| "thousandsseparator"
---Decimal separator key
---| "decimalseparator"
---Currency unit key
---| "currencyunit"
---Currency sub-unit key
---| "currencysubunit"
---Left control key
---| "lctrl"
---Left shift key
---| "lshift"
---Left alt key
---| "lalt"
---Left GUI key (command, windows or super)
---| "lgui"
---Right control key
---| "rctrl"
---Right shift key
---| "rshift"
---Right alt key
---| "ralt"
---Right GUI key (command, windows or super)
---| "rgui"
---Mode key
---| "mode"
---Audio next track key
---| "audionext"
---Audio previous track key
---| "audioprev"
---Audio stop key
---| "audiostop"
---Audio play key
---| "audioplay"
---Audio mute key
---| "audiomute"
---Media select key
---| "mediaselect"
---Application search key
---| "appsearch"
---Application home key
---| "apphome"
---Application back key
---| "appback"
---Application forward key
---| "appforward"
---Application stop key
---| "appstop"
---Application refresh key
---| "apprefresh"
---Application bookmarks key
---| "appbookmarks"
---Eject key
---| "eject"
---Sleep key
---| "sleep"
---@alias love.KeyConstant love.keyboard.KeyConstant

---Modifier keys are keys that have "active" state in addition of pressed/released state, thus modifier keys are small subset of KeyConstant.
---
---[Open in Browser](https://love2d.org/wiki/ModifierKey)
---
---@alias love.keyboard.ModifierKey
---Num-lock key
---| "numlock"
---Caps-lock key
---| "capslock"
---Scroll-lock key
---| "scrolllock"
---Mode key
---| "mode"
---@alias love.ModifierKey love.keyboard.ModifierKey

---Keyboard scancodes.
---
---Scancodes are keyboard layout-independent, so the scancode "w" will be generated if the key in the same place as the "w" key on an American QWERTY keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---Using scancodes, rather than keycodes, is useful because keyboards with layouts differing from the US/UK layout(s) might have keys that generate 'unknown' keycodes, but the scancodes will still be detected. This however would necessitate having a list for each keyboard layout one would choose to support.
---
---One could use textinput or textedited instead, but those only give back the end result of keys used, i.e. you can't get modifiers on their own from it, only the final symbols that were generated.
---
---[Open in Browser](https://love2d.org/wiki/Scancode)
---
---@alias love.keyboard.Scancode
---An unknown key.
---| "unknown"
---The 'A' key on an American layout.
---| "a"
---The 'B' key on an American layout.
---| "b"
---The 'C' key on an American layout.
---| "c"
---The 'D' key on an American layout.
---| "d"
---The 'E' key on an American layout.
---| "e"
---The 'F' key on an American layout.
---| "f"
---The 'G' key on an American layout.
---| "g"
---The 'H' key on an American layout.
---| "h"
---The 'I' key on an American layout.
---| "i"
---The 'J' key on an American layout.
---| "j"
---The 'K' key on an American layout.
---| "k"
---The 'L' key on an American layout.
---| "l"
---The 'M' key on an American layout.
---| "m"
---The 'N' key on an American layout.
---| "n"
---The 'O' key on an American layout.
---| "o"
---The 'P' key on an American layout.
---| "p"
---The 'Q' key on an American layout.
---| "q"
---The 'R' key on an American layout.
---| "r"
---The 'S' key on an American layout.
---| "s"
---The 'T' key on an American layout.
---| "t"
---The 'U' key on an American layout.
---| "u"
---The 'V' key on an American layout.
---| "v"
---The 'W' key on an American layout.
---| "w"
---The 'X' key on an American layout.
---| "x"
---The 'Y' key on an American layout.
---| "y"
---The 'Z' key on an American layout.
---| "z"
---The '1' key on an American layout.
---| "1"
---The '2' key on an American layout.
---| "2"
---The '3' key on an American layout.
---| "3"
---The '4' key on an American layout.
---| "4"
---The '5' key on an American layout.
---| "5"
---The '6' key on an American layout.
---| "6"
---The '7' key on an American layout.
---| "7"
---The '8' key on an American layout.
---| "8"
---The '9' key on an American layout.
---| "9"
---The '0' key on an American layout.
---| "0"
---The 'return' / 'enter' key on an American layout.
---| "return"
---The 'escape' key on an American layout.
---| "escape"
---The 'backspace' key on an American layout.
---| "backspace"
---The 'tab' key on an American layout.
---| "tab"
---The spacebar on an American layout.
---| "space"
---The minus key on an American layout.
---| "-"
---The equals key on an American layout.
---| "="
---The left-bracket key on an American layout.
---| "["
---The right-bracket key on an American layout.
---| "]"
---The backslash key on an American layout.
---| "\"
---The non-U.S. hash scancode.
---| "nonus#"
---The semicolon key on an American layout.
---| ";"
---The apostrophe key on an American layout.
---| "'"
---The back-tick / grave key on an American layout.
---| "`"
---The comma key on an American layout.
---| ","
---The period key on an American layout.
---| "."
---The forward-slash key on an American layout.
---| "/"
---The capslock key on an American layout.
---| "capslock"
---The F1 key on an American layout.
---| "f1"
---The F2 key on an American layout.
---| "f2"
---The F3 key on an American layout.
---| "f3"
---The F4 key on an American layout.
---| "f4"
---The F5 key on an American layout.
---| "f5"
---The F6 key on an American layout.
---| "f6"
---The F7 key on an American layout.
---| "f7"
---The F8 key on an American layout.
---| "f8"
---The F9 key on an American layout.
---| "f9"
---The F10 key on an American layout.
---| "f10"
---The F11 key on an American layout.
---| "f11"
---The F12 key on an American layout.
---| "f12"
---The printscreen key on an American layout.
---| "printscreen"
---The scroll-lock key on an American layout.
---| "scrolllock"
---The pause key on an American layout.
---| "pause"
---The insert key on an American layout.
---| "insert"
---The home key on an American layout.
---| "home"
---The page-up key on an American layout.
---| "pageup"
---The forward-delete key on an American layout.
---| "delete"
---The end key on an American layout.
---| "end"
---The page-down key on an American layout.
---| "pagedown"
---The right-arrow key on an American layout.
---| "right"
---The left-arrow key on an American layout.
---| "left"
---The down-arrow key on an American layout.
---| "down"
---The up-arrow key on an American layout.
---| "up"
---The numlock / clear key on an American layout.
---| "numlock"
---The keypad forward-slash key on an American layout.
---| "kp/"
---The keypad '*' key on an American layout.
---| "kp*"
---The keypad minus key on an American layout.
---| "kp-"
---The keypad plus key on an American layout.
---| "kp+"
---The keypad enter key on an American layout.
---| "kpenter"
---The keypad '1' key on an American layout.
---| "kp1"
---The keypad '2' key on an American layout.
---| "kp2"
---The keypad '3' key on an American layout.
---| "kp3"
---The keypad '4' key on an American layout.
---| "kp4"
---The keypad '5' key on an American layout.
---| "kp5"
---The keypad '6' key on an American layout.
---| "kp6"
---The keypad '7' key on an American layout.
---| "kp7"
---The keypad '8' key on an American layout.
---| "kp8"
---The keypad '9' key on an American layout.
---| "kp9"
---The keypad '0' key on an American layout.
---| "kp0"
---The keypad period key on an American layout.
---| "kp."
---The non-U.S. backslash scancode.
---| "nonusbackslash"
---The application key on an American layout. Windows contextual menu, compose key.
---| "application"
---The system power scancode.
---| "power"
---The keypad equals key on an American layout.
---| "kp="
---The F13 key on an American layout.
---| "f13"
---The F14 key on an American layout.
---| "f14"
---The F15 key on an American layout.
---| "f15"
---The F16 key on an American layout.
---| "f16"
---The F17 key on an American layout.
---| "f17"
---The F18 key on an American layout.
---| "f18"
---The F19 key on an American layout.
---| "f19"
---The F20 key on an American layout.
---| "f20"
---The F21 key on an American layout.
---| "f21"
---The F22 key on an American layout.
---| "f22"
---The F23 key on an American layout.
---| "f23"
---The F24 key on an American layout.
---| "f24"
---The 'execute' key on an American layout.
---| "execute"
---The 'help' key on an American layout.
---| "help"
---The 'menu' key on an American layout.
---| "menu"
---The 'select' key on an American layout.
---| "select"
---The 'stop' key on an American layout.
---| "stop"
---The 'again' key on an American layout.
---| "again"
---The 'undo' key on an American layout.
---| "undo"
---The 'cut' key on an American layout.
---| "cut"
---The 'copy' key on an American layout.
---| "copy"
---The 'paste' key on an American layout.
---| "paste"
---The 'find' key on an American layout.
---| "find"
---The mute key on an American layout.
---| "mute"
---The volume up key on an American layout.
---| "volumeup"
---The volume down key on an American layout.
---| "volumedown"
---The keypad comma key on an American layout.
---| "kp,"
---The keypad equals key on AS/400 keyboards.
---| "kp=400"
---The 1st international key on an American layout. Used on Asian keyboards.
---| "international1"
---The 2nd international key on an American layout.
---| "international2"
---The 3rd international  key on an American layout. Yen.
---| "international3"
---The 4th international key on an American layout.
---| "international4"
---The 5th international key on an American layout.
---| "international5"
---The 6th international key on an American layout.
---| "international6"
---The 7th international key on an American layout.
---| "international7"
---The 8th international key on an American layout.
---| "international8"
---The 9th international key on an American layout.
---| "international9"
---Hangul/English toggle scancode.
---| "lang1"
---Hanja conversion scancode.
---| "lang2"
---Katakana scancode.
---| "lang3"
---Hiragana scancode.
---| "lang4"
---Zenkaku/Hankaku scancode.
---| "lang5"
---The lang6 scancode.
---| "lang6"
---The lang7 scancode.
---| "lang7"
---The lang8 scancode.
---| "lang8"
---The lang9 scancode.
---| "lang9"
---The alt-erase key on an American layout.
---| "alterase"
---The sysreq key on an American layout.
---| "sysreq"
---The 'cancel' key on an American layout.
---| "cancel"
---The 'clear' key on an American layout.
---| "clear"
---The 'prior' key on an American layout.
---| "prior"
---The 'return2' key on an American layout.
---| "return2"
---The 'separator' key on an American layout.
---| "separator"
---The 'out' key on an American layout.
---| "out"
---The 'oper' key on an American layout.
---| "oper"
---The 'clearagain' key on an American layout.
---| "clearagain"
---The 'crsel' key on an American layout.
---| "crsel"
---The 'exsel' key on an American layout.
---| "exsel"
---The keypad 00 key on an American layout.
---| "kp00"
---The keypad 000 key on an American layout.
---| "kp000"
---The thousands-separator key on an American layout.
---| "thousandsseparator"
---The decimal separator key on an American layout.
---| "decimalseparator"
---The currency unit key on an American layout.
---| "currencyunit"
---The currency sub-unit key on an American layout.
---| "currencysubunit"
---The keypad left parenthesis key.
---| "kp("
---The keypad right parenthesis key.
---| "kp)"
---The keypad left brace key.
---| "kp{"
---The keypad right brace key.
---| "kp}"
---The keypad tab key.
---| "kptab"
---The keypad backspace key.
---| "kpbackspace"
---The keypad A key.
---| "kpa"
---The keypad B key.
---| "kpb"
---The keypad C key.
---| "kpc"
---The keypad D key.
---| "kpd"
---The keypad E key.
---| "kpe"
---The keypad F key.
---| "kpf"
---The keypad XOR key.
---| "kpxor"
---The keypad power (exponent) key.
---| "kpower"
---The keypad percent key.
---| "kp%"
---The keypad less-than key.
---| "kp<"
---The keypad greater-than key.
---| "kp>"
---The keypad ampersand key.
---| "kp&"
---The keypad double-ampersand key.
---| "kp&&"
---The keypad vertical bar key.
---| "kp|"
---The keypad double vertical bar key.
---| "kp||"
---The keypad colon key.
---| "kp:"
---The keypad hash key.
---| "kp#"
---The keypad space key.
---| "kp "
---The keypad at-sign key.
---| "kp@"
---The keypad exclamation mark key.
---| "kp!"
---The keypad memory store key.
---| "kpmemstore"
---The keypad memory recall key.
---| "kpmemrecall"
---The keypad memory clear key.
---| "kpmemclear"
---The keypad memory add key.
---| "kpmem+"
---The keypad memory subtract key.
---| "kpmem-"
---The keypad memory multiply key.
---| "kpmem*"
---The keypad memory divide key.
---| "kpmem/"
---The keypad plus-minus key.
---| "kp+-"
---The keypad clear key.
---| "kpclear"
---The keypad clear entry key.
---| "kpclearentry"
---The keypad binary key.
---| "kpbinary"
---The keypad octal key.
---| "kpoctal"
---The keypad decimal key.
---| "kpdecimal"
---The keypad hexadecimal key.
---| "kphex"
---The left control key on an American layout.
---| "lctrl"
---The left shift key on an American layout.
---| "lshift"
---The left alt / option key on an American layout.
---| "lalt"
---The left GUI (command / windows / super) key on an American layout.
---| "lgui"
---The right control key on an American layout.
---| "rctrl"
---The right shift key on an American layout.
---| "rshift"
---The right alt / option key on an American layout.
---| "ralt"
---The right GUI (command / windows / super) key on an American layout.
---| "rgui"
---The mode (AltGr) key.
---| "mode"
---The audio next track key on an American layout.
---| "audionext"
---The audio previous track key on an American layout.
---| "audioprev"
---The audio stop key on an American layout.
---| "audiostop"
---The audio play key on an American layout.
---| "audioplay"
---The audio mute key on an American layout.
---| "audiomute"
---The media select key on an American layout.
---| "mediaselect"
---The AC Search key on an American layout.
---| "acsearch"
---The AC Home key on an American layout.
---| "achome"
---The AC Back key on an American layout.
---| "acback"
---The AC Forward key on an American layout.
---| "acforward"
---Th AC Stop key on an American layout.
---| "acstop"
---The AC Refresh key on an American layout.
---| "acrefresh"
---The AC Bookmarks key on an American layout.
---| "acbookmarks"
---The eject scancode.
---| "eject"
---The system sleep scancode.
---| "sleep"
---@alias love.Scancode love.keyboard.Scancode

---Gets the key corresponding to the given hardware scancode.
---
---Unlike key constants, Scancodes are keyboard layout-independent. For example the scancode 'w' will be generated if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---Scancodes are useful for creating default controls that have the same physical locations on on all systems.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.getKeyFromScancode)
---
---@param scancode love.keyboard.Scancode The scancode to get the key from.
---@return love.keyboard.KeyConstant key The key corresponding to the given scancode, or 'unknown' if the scancode doesn't map to a KeyConstant on the current system.
function love.keyboard.getKeyFromScancode(scancode)
end

---Gets the hardware scancode corresponding to the given key.
---
---Unlike key constants, Scancodes are keyboard layout-independent. For example the scancode 'w' will be generated if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---Scancodes are useful for creating default controls that have the same physical locations on on all systems.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.getScancodeFromKey)
---
---@param key love.keyboard.KeyConstant The key to get the scancode from.
---@return love.keyboard.Scancode scancode The scancode corresponding to the given key, or 'unknown' if the given key has no known physical representation on the current system.
function love.keyboard.getScancodeFromKey(key)
end

---Gets whether key repeat is enabled.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.hasKeyRepeat)
---
---@return boolean enabled Whether key repeat is enabled.
function love.keyboard.hasKeyRepeat()
end

---Gets whether screen keyboard is supported.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.hasScreenKeyboard)
---
---@return boolean supported Whether screen keyboard is supported.
function love.keyboard.hasScreenKeyboard()
end

---Gets whether text input events are enabled.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.hasTextInput)
---
---@return boolean enabled Whether text input events are enabled.
function love.keyboard.hasTextInput()
end

---Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isDown)
---
---@param key love.keyboard.KeyConstant The key to check.
---@return boolean down True if the key is down, false if not.
function love.keyboard.isDown(key)
end

---Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isDown)
---
---@param key love.keyboard.KeyConstant A key to check.
---@param ... love.keyboard.KeyConstant Additional keys to check.
---@return boolean anyDown True if any supplied key is down, false if not.
function love.keyboard.isDown(key, ...)
end

---Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isDown)
---
---@param keys (love.keyboard.KeyConstant)[] A list of keys to check.
---@return boolean anyDown True if any key in the list is down, false if not.
function love.keyboard.isDown(keys)
end

---Checks whether a modifier key is active (toggled on), such as caps lock, num lock or scroll lock. This is separate from whether the key is pressed.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isModifierActive)
---
---@param modifier love.keyboard.ModifierKey Modifier key to check.
---@return boolean active Whether the specified modifier key is active.
function love.keyboard.isModifierActive(modifier)
end

---Checks whether the specified Scancodes are pressed. Not to be confused with love.keypressed or love.keyreleased.
---
---Unlike regular KeyConstants, Scancodes are keyboard layout-independent. The scancode 'w' is used if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isScancodeDown)
---
---@param scancode love.keyboard.Scancode A Scancode to check.
---@param ... love.keyboard.Scancode Additional Scancodes to check.
---@return boolean down True if any supplied Scancode is down, false if not.
function love.keyboard.isScancodeDown(scancode, ...)
end

---Checks whether the specified Scancodes are pressed. Not to be confused with love.keypressed or love.keyreleased.
---
---Unlike regular KeyConstants, Scancodes are keyboard layout-independent. The scancode 'w' is used if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isScancodeDown)
---
---@param scancodes (love.keyboard.Scancode)[] A list of Scancodes to check.
---@return boolean down True if any Scancode in the list is down, false if not.
function love.keyboard.isScancodeDown(scancodes)
end

---Gets whether the system's on-screen keyboard is currently shown.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.isScreenKeyboardVisible)
---
---@return boolean visible Whether the on-screen keyboard is visible.
function love.keyboard.isScreenKeyboardVisible()
end

---Enables or disables key repeat for love.keypressed. It is disabled by default.
---
---The interval between repeats depends on the user's system settings. This function doesn't affect whether love.textinput is called multiple times while a key is held down.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.setKeyRepeat)
---
---@param enable boolean Whether repeat keypress events should be enabled when a key is held down.
function love.keyboard.setKeyRepeat(enable)
end

---Enables or disables text input events. It is enabled by default on Windows, Mac, and Linux, and disabled by default on iOS and Android.
---
---On touch devices, this shows the system's native on-screen keyboard when it's enabled.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.setTextInput)
---
---@param enable boolean Whether text input events should be enabled.
function love.keyboard.setTextInput(enable)
end

---Enables or disables text input events. It is enabled by default on Windows, Mac, and Linux, and disabled by default on iOS and Android.
---
---On touch devices, this shows the system's native on-screen keyboard when it's enabled.
---
---On iOS and Android this variant tells the OS that the specified rectangle is where text will show up in the game, which prevents the system on-screen keyboard from covering the text.
---
---[Open in Browser](https://love2d.org/wiki/love.keyboard.setTextInput)
---
---@param enable boolean Whether text input events should be enabled.
---@param x number Text rectangle x position.
---@param y number Text rectangle y position.
---@param w number Text rectangle width.
---@param h number Text rectangle height.
function love.keyboard.setTextInput(enable, x, y, w, h)
end

---Provides system-independent mathematical functions.
---
---[Open in Browser](https://love2d.org/wiki/love.math)
---
---@class love.math
love.math = {}

---The layout of matrix elements (row-major or column-major).
---
---[Open in Browser](https://love2d.org/wiki/MatrixLayout)
---
---@alias love.math.MatrixLayout
---The matrix elements are listed row by row: e1_1, e1_2, e1_3, e1_4, e2_1, ...
---| "row"
---The matrix elements are listed column by column: e1_1, e2_1, e3_1, e4_1, e1_2, ...
---| "column"
---@alias love.MatrixLayout love.math.MatrixLayout

---A Bézier curve object that can evaluate and render Bézier curves of arbitrary degree.
---
---For more information on Bézier curves check this great article on Wikipedia.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve)
---
---@class love.math.BezierCurve: love.Object
local BezierCurve = {}
---@alias love.BezierCurve love.math.BezierCurve

---Evaluate Bézier curve at parameter t. The parameter must be between 0 and 1 (inclusive).
---
---This function can be used to move objects along paths or tween parameters. However it should not be used to render the curve, see BezierCurve:render for that purpose.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:evaluate)
---
---@param t number Where to evaluate the curve.
---@return number x x coordinate of the curve at parameter t.
---@return number y y coordinate of the curve at parameter t.
function BezierCurve:evaluate(t)
end

---Get coordinates of the i-th control point. Indices start with 1.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:getControlPoint)
---
---@param i number Index of the control point.
---@return number x Position of the control point along the x axis.
---@return number y Position of the control point along the y axis.
function BezierCurve:getControlPoint(i)
end

---Get the number of control points in the Bézier curve.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:getControlPointCount)
---
---@return number count The number of control points.
function BezierCurve:getControlPointCount()
end

---Get degree of the Bézier curve. The degree is equal to number-of-control-points - 1.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:getDegree)
---
---@return number degree Degree of the Bézier curve.
function BezierCurve:getDegree()
end

---Get the derivative of the Bézier curve.
---
---This function can be used to rotate sprites moving along a curve in the direction of the movement and compute the direction perpendicular to the curve at some parameter t.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:getDerivative)
---
---@return love.math.BezierCurve derivative The derivative curve.
function BezierCurve:getDerivative()
end

---Gets a BezierCurve that corresponds to the specified segment of this BezierCurve.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:getSegment)
---
---@param startpoint number The starting point along the curve. Must be between 0 and 1.
---@param endpoint number The end of the segment. Must be between 0 and 1.
---@return love.math.BezierCurve curve A BezierCurve that corresponds to the specified segment.
function BezierCurve:getSegment(startpoint, endpoint)
end

---Insert control point as the new i-th control point. Existing control points from i onwards are pushed back by 1. Indices start with 1. Negative indices wrap around: -1 is the last control point, -2 the one before the last, etc.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:insertControlPoint)
---
---@param x number Position of the control point along the x axis.
---@param y number Position of the control point along the y axis.
---@param i (number)? Index of the control point.
function BezierCurve:insertControlPoint(x, y, i)
end

---Removes the specified control point.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:removeControlPoint)
---
---@param index number The index of the control point to remove.
function BezierCurve:removeControlPoint(index)
end

---Get a list of coordinates to be used with love.graphics.line.
---
---This function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter.
---
---If you are just interested to know the position on the curve given a parameter, use BezierCurve:evaluate.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:render)
---
---@param depth (number)? Number of recursive subdivision steps.
---@return (number)[] coordinates List of x,y-coordinate pairs of points on the curve.
function BezierCurve:render(depth)
end

---Get a list of coordinates on a specific part of the curve, to be used with love.graphics.line.
---
---This function samples the Bézier curve using recursive subdivision. You can control the recursion depth using the depth parameter.
---
---If you are just need to know the position on the curve given a parameter, use BezierCurve:evaluate.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:renderSegment)
---
---@param startpoint number The starting point along the curve. Must be between 0 and 1.
---@param endpoint number The end of the segment to render. Must be between 0 and 1.
---@param depth (number)? Number of recursive subdivision steps.
---@return (number)[] coordinates List of x,y-coordinate pairs of points on the specified part of the curve.
function BezierCurve:renderSegment(startpoint, endpoint, depth)
end

---Rotate the Bézier curve by an angle.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:rotate)
---
---@param angle number Rotation angle in radians.
---@param ox (number)? X coordinate of the rotation center.
---@param oy (number)? Y coordinate of the rotation center.
function BezierCurve:rotate(angle, ox, oy)
end

---Scale the Bézier curve by a factor.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:scale)
---
---@param s number Scale factor.
---@param ox (number)? X coordinate of the scaling center.
---@param oy (number)? Y coordinate of the scaling center.
function BezierCurve:scale(s, ox, oy)
end

---Set coordinates of the i-th control point. Indices start with 1.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:setControlPoint)
---
---@param i number Index of the control point.
---@param x number Position of the control point along the x axis.
---@param y number Position of the control point along the y axis.
function BezierCurve:setControlPoint(i, x, y)
end

---Move the Bézier curve by an offset.
---
---[Open in Browser](https://love2d.org/wiki/BezierCurve:translate)
---
---@param dx number Offset along the x axis.
---@param dy number Offset along the y axis.
function BezierCurve:translate(dx, dy)
end

---A random number generation object which has its own random state.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator)
---
---@class love.math.RandomGenerator: love.Object
local RandomGenerator = {}
---@alias love.RandomGenerator love.math.RandomGenerator

---Gets the seed of the random number generator object.
---
---The seed is split into two numbers due to Lua's use of doubles for all number values - doubles can't accurately represent integer  values above 2^53, but the seed value is an integer number in the range of 2^64 - 1.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:getSeed)
---
---@return number low Integer number representing the lower 32 bits of the RandomGenerator's 64 bit seed value.
---@return number high Integer number representing the higher 32 bits of the RandomGenerator's 64 bit seed value.
function RandomGenerator:getSeed()
end

---Gets the current state of the random number generator. This returns an opaque string which is only useful for later use with RandomGenerator:setState in the same major version of LÖVE.
---
---This is different from RandomGenerator:getSeed in that getState gets the RandomGenerator's current state, whereas getSeed gets the previously set seed number.
---
---The value of the state string does not depend on the current operating system.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:getState)
---
---@return string state The current state of the RandomGenerator object, represented as a string.
function RandomGenerator:getState()
end

---Generates a pseudo-random number in a platform independent manner.
---
---Get uniformly distributed pseudo-random number within 1.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:random)
---
---@return number number The pseudo-random number.
function RandomGenerator:random()
end

---Generates a pseudo-random number in a platform independent manner.
---
---Get uniformly distributed pseudo-random integer number within max.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:random)
---
---@param max number The maximum possible value it should return.
---@return number number The pseudo-random integer number.
function RandomGenerator:random(max)
end

---Generates a pseudo-random number in a platform independent manner.
---
---Get uniformly distributed pseudo-random integer number within max.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:random)
---
---@param min number The minimum possible value it should return.
---@param max number The maximum possible value it should return.
---@return number number The pseudo-random integer number.
function RandomGenerator:random(min, max)
end

---Get a normally distributed pseudo random number.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:randomNormal)
---
---@param stddev (number)? Standard deviation of the distribution.
---@param mean (number)? The mean of the distribution.
---@return number number Normally distributed random number with variance (stddev)² and the specified mean.
function RandomGenerator:randomNormal(stddev, mean)
end

---Sets the seed of the random number generator using the specified integer number.
---
---Due to Lua's use of double-precision floating point numbers, values above 2^53 cannot be accurately represented. Use the other variant of this function if your seed will have a larger value.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:setSeed)
---
---@param seed number The integer number with which you want to seed the randomization. Must be within the range of 2^53.
function RandomGenerator:setSeed(seed)
end

---Sets the seed of the random number generator using the specified integer number.
---
---Combines two 32-bit integer numbers into a 64-bit integer value and sets the seed of the random number generator using the value.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:setSeed)
---
---@param low number The lower 32 bits of the seed value. Must be within the range of 2^32 - 1.
---@param high number The higher 32 bits of the seed value. Must be within the range of 2^32 - 1.
function RandomGenerator:setSeed(low, high)
end

---Sets the current state of the random number generator. The value used as an argument for this function is an opaque string and should only originate from a previous call to RandomGenerator:getState in the same major version of LÖVE.
---
---This is different from RandomGenerator:setSeed in that setState directly sets the RandomGenerator's current implementation-dependent state, whereas setSeed gives it a new seed value.
---
---The effect of the state string does not depend on the current operating system.
---
---[Open in Browser](https://love2d.org/wiki/RandomGenerator:setState)
---
---@param state string The new state of the RandomGenerator object, represented as a string. This should originate from a previous call to RandomGenerator:getState.
function RandomGenerator:setState(state)
end

---Object containing a coordinate system transformation.
---
---The love.graphics module has several functions and function variants which accept Transform objects.
---
---[Open in Browser](https://love2d.org/wiki/Transform)
---
---@class love.math.Transform: love.Object
local Transform = {}
---@alias love.Transform love.math.Transform

---Applies the given other Transform object to this one.
---
---This effectively multiplies this Transform's internal transformation matrix with the other Transform's (i.e. self * other), and stores the result in this object.
---
---[Open in Browser](https://love2d.org/wiki/Transform:apply)
---
---@param other love.math.Transform The other Transform object to apply to this Transform.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:apply(other)
end

---Creates a new copy of this Transform.
---
---[Open in Browser](https://love2d.org/wiki/Transform:clone)
---
---@return love.math.Transform clone The copy of this Transform.
function Transform:clone()
end

---Gets the internal 4x4 transformation matrix stored by this Transform. The matrix is returned in row-major order.
---
---[Open in Browser](https://love2d.org/wiki/Transform:getMatrix)
---
---@return number e1_1 The first column of the first row of the matrix.
---@return number e1_2 The second column of the first row of the matrix.
---@return number e1_3 The third column of the first row of the matrix.
---@return number e1_4 The fourth column of the first row of the matrix.
---@return number e2_1 The first column of the second row of the matrix.
---@return number e2_2 The second column of the second row of the matrix.
---@return number e2_3 The third column of the second row of the matrix.
---@return number e2_4 The fourth column of the second row of the matrix.
---@return number e3_1 The first column of the third row of the matrix.
---@return number e3_2 The second column of the third row of the matrix.
---@return number e3_3 The third column of the third row of the matrix.
---@return number e3_4 The fourth column of the third row of the matrix.
---@return number e4_1 The first column of the fourth row of the matrix.
---@return number e4_2 The second column of the fourth row of the matrix.
---@return number e4_3 The third column of the fourth row of the matrix.
---@return number e4_4 The fourth column of the fourth row of the matrix.
function Transform:getMatrix()
end

---Creates a new Transform containing the inverse of this Transform.
---
---[Open in Browser](https://love2d.org/wiki/Transform:inverse)
---
---@return love.math.Transform inverse A new Transform object representing the inverse of this Transform's matrix.
function Transform:inverse()
end

---Sets this Transform to the inverse of another Transform, without creating a new object.
---
---[Open in Browser](https://love2d.org/wiki/Transform:inverseOf)
---
---@param other love.math.Transform The Transform whose inverse is stored in this Transform.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:inverseOf(other)
end

---Applies the reverse of the Transform object's transformation to the given 2D position.
---
---This effectively converts the given position from the local coordinate space of the Transform into global coordinates.
---
---One use of this method can be to convert a screen-space mouse position into global world coordinates, if the given Transform has transformations applied that are used for a camera system in-game.
---
---[Open in Browser](https://love2d.org/wiki/Transform:inverseTransformPoint)
---
---@param localX number The x component of the position with the transform applied.
---@param localY number The y component of the position with the transform applied.
---@return number globalX The x component of the position in global coordinates.
---@return number globalY The y component of the position in global coordinates.
function Transform:inverseTransformPoint(localX, localY)
end

---Checks whether the Transform is an affine transformation.
---
---[Open in Browser](https://love2d.org/wiki/Transform:isAffine2DTransform)
---
---@return boolean affine true if the transform object is an affine transformation, false otherwise.
function Transform:isAffine2DTransform()
end

---Resets the Transform to an identity state. All previously applied transformations are erased.
---
---[Open in Browser](https://love2d.org/wiki/Transform:reset)
---
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:reset()
end

---Applies a rotation to the Transform's coordinate system. This method does not reset any previously applied transformations.
---
---[Open in Browser](https://love2d.org/wiki/Transform:rotate)
---
---@param angle number The relative angle in radians to rotate this Transform by.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:rotate(angle)
end

---Scales the Transform's coordinate system. This method does not reset any previously applied transformations.
---
---[Open in Browser](https://love2d.org/wiki/Transform:scale)
---
---@param sx number The relative scale factor along the x-axis.
---@param sy (number)? The relative scale factor along the y-axis.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:scale(sx, sy)
end

---Directly sets the Transform's internal 4x4 transformation matrix.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setMatrix)
---
---@param e1_1 number The first column of the first row of the matrix.
---@param e1_2 number The second column of the first row of the matrix.
---@param e1_3 number The third column of the first row of the matrix.
---@param e1_4 number The fourth column of the first row of the matrix.
---@param e2_1 number The first column of the second row of the matrix.
---@param e2_2 number The second column of the second row of the matrix.
---@param e2_3 number The third column of the second row of the matrix.
---@param e2_4 number The fourth column of the second row of the matrix.
---@param e3_1 number The first column of the third row of the matrix.
---@param e3_2 number The second column of the third row of the matrix.
---@param e3_3 number The third column of the third row of the matrix.
---@param e3_4 number The fourth column of the third row of the matrix.
---@param e4_1 number The first column of the fourth row of the matrix.
---@param e4_2 number The second column of the fourth row of the matrix.
---@param e4_3 number The third column of the fourth row of the matrix.
---@param e4_4 number The fourth column of the fourth row of the matrix.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setMatrix(e1_1, e1_2, e1_3, e1_4, e2_1, e2_2, e2_3, e2_4, e3_1, e3_2, e3_3, e3_4, e4_1, e4_2, e4_3, e4_4)
end

---Directly sets the Transform's internal 4x4 transformation matrix.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setMatrix)
---
---@param layout love.math.MatrixLayout How to interpret the matrix element arguments (row-major or column-major).
---@param e1_1 number The first column of the first row of the matrix.
---@param e1_2 number The second column of the first row or the first column of the second row of the matrix, depending on the specified layout.
---@param e1_3 number The third column/row of the first row/column of the matrix.
---@param e1_4 number The fourth column/row of the first row/column of the matrix.
---@param e2_1 number The first column/row of the second row/column of the matrix.
---@param e2_2 number The second column/row of the second row/column of the matrix.
---@param e2_3 number The third column/row of the second row/column of the matrix.
---@param e2_4 number The fourth column/row of the second row/column of the matrix.
---@param e3_1 number The first column/row of the third row/column of the matrix.
---@param e3_2 number The second column/row of the third row/column of the matrix.
---@param e3_3 number The third column/row of the third row/column of the matrix.
---@param e3_4 number The fourth column/row of the third row/column of the matrix.
---@param e4_1 number The first column/row of the fourth row/column of the matrix.
---@param e4_2 number The second column/row of the fourth row/column of the matrix.
---@param e4_3 number The third column/row of the fourth row/column of the matrix.
---@param e4_4 number The fourth column of the fourth row of the matrix.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setMatrix(layout, e1_1, e1_2, e1_3, e1_4, e2_1, e2_2, e2_3, e2_4, e3_1, e3_2, e3_3, e3_4, e4_1, e4_2, e4_3, e4_4)
end

---Directly sets the Transform's internal 4x4 transformation matrix.
---
---The table is read in row-major order.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setMatrix)
---
---@param matrix table A flat table of the 16 matrix elements, or a table of 4 row tables with 4 elements each.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setMatrix(matrix)
end

---Directly sets the Transform's internal 4x4 transformation matrix.
---
---The table holds the 16 elements in a flat array.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setMatrix)
---
---@param layout love.math.MatrixLayout How to interpret the matrix element arguments (row-major or column-major).
---@param matrix (number)[] A flat table containing the 16 matrix elements.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setMatrix(layout, matrix)
end

---Directly sets the Transform's internal 4x4 transformation matrix.
---
---The table holds 4 tables of 4 elements each: rows for 'row' layout, columns for 'column' layout.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setMatrix)
---
---@param layout love.math.MatrixLayout How to interpret the matrix element arguments (row-major or column-major).
---@param matrix (table)[] A table of 4 tables, with each sub-table containing 4 matrix elements.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setMatrix(layout, matrix)
end

---Resets the Transform to the specified transformation parameters.
---
---[Open in Browser](https://love2d.org/wiki/Transform:setTransformation)
---
---@param x (number)? The position of the Transform on the x-axis.
---@param y (number)? The position of the Transform on the y-axis.
---@param angle (number)? The orientation of the Transform in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:setTransformation(x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Applies a shear factor (skew) to the Transform's coordinate system. This method does not reset any previously applied transformations.
---
---[Open in Browser](https://love2d.org/wiki/Transform:shear)
---
---@param kx number The shear factor along the x-axis.
---@param ky number The shear factor along the y-axis.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:shear(kx, ky)
end

---Applies the Transform object's transformation to the given 2D position.
---
---This effectively converts the given position from global coordinates into the local coordinate space of the Transform.
---
---[Open in Browser](https://love2d.org/wiki/Transform:transformPoint)
---
---@param globalX number The x component of the position in global coordinates.
---@param globalY number The y component of the position in global coordinates.
---@return number localX The x component of the position with the transform applied.
---@return number localY The y component of the position with the transform applied.
function Transform:transformPoint(globalX, globalY)
end

---Applies a translation to the Transform's coordinate system. This method does not reset any previously applied transformations.
---
---[Open in Browser](https://love2d.org/wiki/Transform:translate)
---
---@param dx number The relative translation along the x-axis.
---@param dy number The relative translation along the y-axis.
---@return love.math.Transform transform The Transform object the method was called on. Allows easily chaining Transform methods.
function Transform:translate(dx, dy)
end

---Converts a color from 0..255 to 0..1 range. Components are rounded to whole numbers before conversion and the results are clamped to 0..1.
---
---[Open in Browser](https://love2d.org/wiki/love.math.colorFromBytes)
---
---@param rb number Red color component in 0..255 range.
---@param gb number Green color component in 0..255 range.
---@param bb number Blue color component in 0..255 range.
---@param ab (number)? Alpha color component in 0..255 range.
---@return number r Red color component in 0..1 range.
---@return number g Green color component in 0..1 range.
---@return number b Blue color component in 0..1 range.
---@return number a Alpha color component in 0..1 range or nil if alpha is not specified.
function love.math.colorFromBytes(rb, gb, bb, ab)
end

---Converts a color from 0..255 to 0..1 range. Components are rounded to whole numbers before conversion and the results are clamped to 0..1.
---
---[Open in Browser](https://love2d.org/wiki/love.math.colorFromBytes)
---
---@param color (number)[] An array with the red, green, blue and optionally alpha components in 0..255 range.
---@return number r Red color component in 0..1 range.
---@return number g Green color component in 0..1 range.
---@return number b Blue color component in 0..1 range.
---@return number a Alpha color component in 0..1 range or nil if alpha is not specified.
function love.math.colorFromBytes(color)
end

---Converts a color from 0..1 to 0..255 range. Components are clamped to 0..1 and the results are rounded to whole numbers.
---
---[Open in Browser](https://love2d.org/wiki/love.math.colorToBytes)
---
---@param r number Red color component.
---@param g number Green color component.
---@param b number Blue color component.
---@param a (number)? Alpha color component.
---@return number rb Red color component in 0..255 range.
---@return number gb Green color component in 0..255 range.
---@return number bb Blue color component in 0..255 range.
---@return number ab Alpha color component in 0..255 range or nil if alpha is not specified.
function love.math.colorToBytes(r, g, b, a)
end

---Converts a color from 0..1 to 0..255 range. Components are clamped to 0..1 and the results are rounded to whole numbers.
---
---[Open in Browser](https://love2d.org/wiki/love.math.colorToBytes)
---
---@param color (number)[] An array with the red, green, blue and optionally alpha components in 0..1 range.
---@return number rb Red color component in 0..255 range.
---@return number gb Green color component in 0..255 range.
---@return number bb Blue color component in 0..255 range.
---@return number ab Alpha color component in 0..255 range or nil if alpha is not specified.
function love.math.colorToBytes(color)
end

---Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-correct rendering and you need to do math in linear RGB in the few cases where LÖVE doesn't handle conversions automatically. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.gammaToLinear)
---
---@param r number The red channel of the sRGB color to convert.
---@param g number The green channel of the sRGB color to convert.
---@param b number The blue channel of the sRGB color to convert.
---@param a (number)? The alpha channel. It is returned unchanged because alpha is always linear.
---@return number lr The red channel of the converted color in linear RGB space.
---@return number lg The green channel of the converted color in linear RGB space.
---@return number lb The blue channel of the converted color in linear RGB space.
---@return number a The alpha channel, unchanged, or nil if no alpha was given.
function love.math.gammaToLinear(r, g, b, a)
end

---Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-correct rendering and you need to do math in linear RGB in the few cases where LÖVE doesn't handle conversions automatically. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.gammaToLinear)
---
---@param color (number)[] An array with the red, green, blue and optionally alpha channels of the sRGB color to convert.
---@return number lr The red channel of the converted color in linear RGB space.
---@return number lg The green channel of the converted color in linear RGB space.
---@return number lb The blue channel of the converted color in linear RGB space.
---@return number a The alpha channel, unchanged, or nil if no alpha was given.
function love.math.gammaToLinear(color)
end

---Converts a color from gamma-space (sRGB) to linear-space (RGB). This is useful when doing gamma-correct rendering and you need to do math in linear RGB in the few cases where LÖVE doesn't handle conversions automatically. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.gammaToLinear)
---
---@param c number The value of a color channel in sRGB space to convert.
---@return number lc The value of the color channel in linear RGB space.
function love.math.gammaToLinear(c)
end

---Gets the seed of the random number generator.
---
---The seed is split into two numbers due to Lua's use of doubles for all number values - doubles can't accurately represent integer  values above 2^53, but the seed can be an integer value up to 2^64.
---
---[Open in Browser](https://love2d.org/wiki/love.math.getRandomSeed)
---
---@return number low Integer number representing the lower 32 bits of the random number generator's 64 bit seed value.
---@return number high Integer number representing the higher 32 bits of the random number generator's 64 bit seed value.
function love.math.getRandomSeed()
end

---Gets the current state of the random number generator. This returns an opaque implementation-dependent string which is only useful for later use with love.math.setRandomState or RandomGenerator:setState.
---
---This is different from love.math.getRandomSeed in that getRandomState gets the random number generator's current state, whereas getRandomSeed gets the previously set seed number.
---
---The value of the state string does not depend on the current operating system.
---
---[Open in Browser](https://love2d.org/wiki/love.math.getRandomState)
---
---@return string state The current state of the random number generator, represented as a string.
function love.math.getRandomState()
end

---Checks whether a polygon is convex.
---
---PolygonShapes in love.physics, some forms of Meshes, and polygons drawn with love.graphics.polygon must be simple convex polygons.
---
---[Open in Browser](https://love2d.org/wiki/love.math.isConvex)
---
---@param vertices (number)[] The vertices of the polygon as a table in the form of {x1, y1, x2, y2, x3, y3, ...}.
---@return boolean convex Whether the given polygon is convex.
function love.math.isConvex(vertices)
end

---Checks whether a polygon is convex.
---
---PolygonShapes in love.physics, some forms of Meshes, and polygons drawn with love.graphics.polygon must be simple convex polygons.
---
---[Open in Browser](https://love2d.org/wiki/love.math.isConvex)
---
---@param x1 number The position of the first vertex of the polygon on the x-axis.
---@param y1 number The position of the first vertex of the polygon on the y-axis.
---@param x2 number The position of the second vertex of the polygon on the x-axis.
---@param y2 number The position of the second vertex of the polygon on the y-axis.
---@param ... number Additional position of the vertex of the polygon on the x-axis and y-axis.
---@return boolean convex Whether the given polygon is convex.
function love.math.isConvex(x1, y1, x2, y2, ...)
end

---Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linear RGB color values in an image, because the linear RGB color space has less precision than sRGB for dark colors, which can result in noticeable color banding when drawing.
---
---In general, colors chosen based on what they look like on-screen are already in gamma-space and should not be double-converted. Colors calculated using math are often in the linear RGB space. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.linearToGamma)
---
---@param lr number The red channel of the linear RGB color to convert.
---@param lg number The green channel of the linear RGB color to convert.
---@param lb number The blue channel of the linear RGB color to convert.
---@param a (number)? The alpha channel. It is returned unchanged because alpha is always linear.
---@return number cr The red channel of the converted color in gamma sRGB space.
---@return number cg The green channel of the converted color in gamma sRGB space.
---@return number cb The blue channel of the converted color in gamma sRGB space.
---@return number a The alpha channel, unchanged, or nil if no alpha was given.
function love.math.linearToGamma(lr, lg, lb, a)
end

---Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linear RGB color values in an image, because the linear RGB color space has less precision than sRGB for dark colors, which can result in noticeable color banding when drawing.
---
---In general, colors chosen based on what they look like on-screen are already in gamma-space and should not be double-converted. Colors calculated using math are often in the linear RGB space. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.linearToGamma)
---
---@param color (number)[] An array with the red, green, blue and optionally alpha channels of the linear RGB color to convert.
---@return number cr The red channel of the converted color in gamma sRGB space.
---@return number cg The green channel of the converted color in gamma sRGB space.
---@return number cb The blue channel of the converted color in gamma sRGB space.
---@return number a The alpha channel, unchanged, or nil if no alpha was given.
function love.math.linearToGamma(color)
end

---Converts a color from linear-space (RGB) to gamma-space (sRGB). This is useful when storing linear RGB color values in an image, because the linear RGB color space has less precision than sRGB for dark colors, which can result in noticeable color banding when drawing.
---
---In general, colors chosen based on what they look like on-screen are already in gamma-space and should not be double-converted. Colors calculated using math are often in the linear RGB space. Components are clamped to 0..1 first.
---
---[Open in Browser](https://love2d.org/wiki/love.math.linearToGamma)
---
---@param lc number The value of a color channel in linear RGB space to convert.
---@return number c The value of the color channel in gamma sRGB space.
function love.math.linearToGamma(lc)
end

---Creates a new BezierCurve object.
---
---The number of vertices in the control polygon determines the degree of the curve, e.g. three vertices define a quadratic (degree 2) Bézier curve, four vertices define a cubic (degree 3) Bézier curve, etc.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newBezierCurve)
---
---@param vertices (number)[] The vertices of the control polygon as a table in the form of {x1, y1, x2, y2, x3, y3, ...}.
---@return love.math.BezierCurve curve A Bézier curve object.
function love.math.newBezierCurve(vertices)
end

---Creates a new BezierCurve object.
---
---The number of vertices in the control polygon determines the degree of the curve, e.g. three vertices define a quadratic (degree 2) Bézier curve, four vertices define a cubic (degree 3) Bézier curve, etc.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newBezierCurve)
---
---@param x1 number The position of the first vertex of the control polygon on the x-axis.
---@param y1 number The position of the first vertex of the control polygon on the y-axis.
---@param x2 number The position of the second vertex of the control polygon on the x-axis.
---@param y2 number The position of the second vertex of the control polygon on the y-axis.
---@param ... number Additional position of the vertex of the control polygon on the x-axis and y-axis.
---@return love.math.BezierCurve curve A Bézier curve object.
function love.math.newBezierCurve(x1, y1, x2, y2, ...)
end

---Creates a new RandomGenerator object which is completely independent of other RandomGenerator objects and random functions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newRandomGenerator)
---
---@return love.math.RandomGenerator rng The new Random Number Generator object.
function love.math.newRandomGenerator()
end

---Creates a new RandomGenerator object which is completely independent of other RandomGenerator objects and random functions.
---
---See RandomGenerator:setSeed.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newRandomGenerator)
---
---@param seed number The initial seed number to use for this object.
---@return love.math.RandomGenerator rng The new Random Number Generator object.
function love.math.newRandomGenerator(seed)
end

---Creates a new RandomGenerator object which is completely independent of other RandomGenerator objects and random functions.
---
---See RandomGenerator:setSeed.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newRandomGenerator)
---
---@param low number The lower 32 bits of the seed number to use for this object.
---@param high number The higher 32 bits of the seed number to use for this object.
---@return love.math.RandomGenerator rng The new Random Number Generator object.
function love.math.newRandomGenerator(low, high)
end

---Creates a new Transform object.
---
---Creates a Transform with no transformations applied. Call methods on the returned object to apply transformations.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newTransform)
---
---@return love.math.Transform transform The new Transform object.
function love.math.newTransform()
end

---Creates a new Transform object.
---
---Creates a Transform with the specified transformation applied on creation.
---
---[Open in Browser](https://love2d.org/wiki/love.math.newTransform)
---
---@param x number The position of the new Transform on the x-axis.
---@param y number The position of the new Transform on the y-axis.
---@param angle (number)? The orientation of the new Transform in radians.
---@param sx (number)? Scale factor on the x-axis.
---@param sy (number)? Scale factor on the y-axis.
---@param ox (number)? Origin offset on the x-axis.
---@param oy (number)? Origin offset on the y-axis.
---@param kx (number)? Shearing / skew factor on the x-axis.
---@param ky (number)? Shearing / skew factor on the y-axis.
---@return love.math.Transform transform The new Transform object.
function love.math.newTransform(x, y, angle, sx, sy, ox, oy, kx, ky)
end

---Generates a noise value in 1 to 4 dimensions, between 0 and 1: Simplex noise for 1 and 2 dimensions and Perlin noise for 3 and 4 dimensions.
---
---Deprecated: use love.math.perlinNoise or love.math.simplexNoise instead.
---
---Generates Simplex noise from 1 dimension.
---
---[Open in Browser](https://love2d.org/wiki/love.math.noise)
---
---@param x number The number used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.noise(x)
end

---Generates a noise value in 1 to 4 dimensions, between 0 and 1: Simplex noise for 1 and 2 dimensions and Perlin noise for 3 and 4 dimensions.
---
---Deprecated: use love.math.perlinNoise or love.math.simplexNoise instead.
---
---Generates Simplex noise from 2 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.noise)
---
---@param x number The first value of the 2-dimensional vector used to generate the noise value.
---@param y number The second value of the 2-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.noise(x, y)
end

---Generates a noise value in 1 to 4 dimensions, between 0 and 1: Simplex noise for 1 and 2 dimensions and Perlin noise for 3 and 4 dimensions.
---
---Deprecated: use love.math.perlinNoise or love.math.simplexNoise instead.
---
---Generates Perlin noise from 3 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.noise)
---
---@param x number The first value of the 3-dimensional vector used to generate the noise value.
---@param y number The second value of the 3-dimensional vector used to generate the noise value.
---@param z number The third value of the 3-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.noise(x, y, z)
end

---Generates a noise value in 1 to 4 dimensions, between 0 and 1: Simplex noise for 1 and 2 dimensions and Perlin noise for 3 and 4 dimensions.
---
---Deprecated: use love.math.perlinNoise or love.math.simplexNoise instead.
---
---Generates Perlin noise from 4 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.noise)
---
---@param x number The first value of the 4-dimensional vector used to generate the noise value.
---@param y number The second value of the 4-dimensional vector used to generate the noise value.
---@param z number The third value of the 4-dimensional vector used to generate the noise value.
---@param w number The fourth value of the 4-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.noise(x, y, z, w)
end

---Generates a Perlin noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Perlin noise from 1 dimension.
---
---[Open in Browser](https://love2d.org/wiki/love.math.perlinNoise)
---
---@param x number The number used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.perlinNoise(x)
end

---Generates a Perlin noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Perlin noise from 2 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.perlinNoise)
---
---@param x number The first value of the 2-dimensional vector used to generate the noise value.
---@param y number The second value of the 2-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.perlinNoise(x, y)
end

---Generates a Perlin noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Perlin noise from 3 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.perlinNoise)
---
---@param x number The first value of the 3-dimensional vector used to generate the noise value.
---@param y number The second value of the 3-dimensional vector used to generate the noise value.
---@param z number The third value of the 3-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.perlinNoise(x, y, z)
end

---Generates a Perlin noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Perlin noise from 4 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.perlinNoise)
---
---@param x number The first value of the 4-dimensional vector used to generate the noise value.
---@param y number The second value of the 4-dimensional vector used to generate the noise value.
---@param z number The third value of the 4-dimensional vector used to generate the noise value.
---@param w number The fourth value of the 4-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.perlinNoise(x, y, z, w)
end

---Generates a pseudo-random number in a platform independent manner. The default love.run seeds this function at startup, so you generally don't need to seed it yourself.
---
---Get a uniformly distributed pseudo-random real number in the range [0, 1).
---
---[Open in Browser](https://love2d.org/wiki/love.math.random)
---
---@return number number The pseudo-random number.
function love.math.random()
end

---Generates a pseudo-random number in a platform independent manner. The default love.run seeds this function at startup, so you generally don't need to seed it yourself.
---
---Get a uniformly distributed pseudo-random integer in the range [1, max].
---
---[Open in Browser](https://love2d.org/wiki/love.math.random)
---
---@param max number The maximum possible value it should return.
---@return number number The pseudo-random integer number.
function love.math.random(max)
end

---Generates a pseudo-random number in a platform independent manner. The default love.run seeds this function at startup, so you generally don't need to seed it yourself.
---
---Get a uniformly distributed pseudo-random integer in the range [min, max].
---
---[Open in Browser](https://love2d.org/wiki/love.math.random)
---
---@param min number The minimum possible value it should return.
---@param max number The maximum possible value it should return.
---@return number number The pseudo-random integer number.
function love.math.random(min, max)
end

---Get a normally distributed pseudo random number.
---
---[Open in Browser](https://love2d.org/wiki/love.math.randomNormal)
---
---@param stddev (number)? Standard deviation of the distribution.
---@param mean (number)? The mean of the distribution.
---@return number number Normally distributed random number with variance (stddev)² and the specified mean.
function love.math.randomNormal(stddev, mean)
end

---Sets the seed of the random number generator using the specified integer number. This is called internally at startup, so you generally don't need to call it yourself.
---
---Due to Lua's use of double-precision floating point numbers, integer values above 2^53 cannot be accurately represented. Use the other variant of the function if you want to use a larger number.
---
---[Open in Browser](https://love2d.org/wiki/love.math.setRandomSeed)
---
---@param seed number The integer number with which you want to seed the randomization. Must be within the range of 0 to 2^53 - 1.
function love.math.setRandomSeed(seed)
end

---Sets the seed of the random number generator using the specified integer number. This is called internally at startup, so you generally don't need to call it yourself.
---
---Combines two 32-bit integer numbers into a 64-bit integer value and sets the seed of the random number generator using the value.
---
---[Open in Browser](https://love2d.org/wiki/love.math.setRandomSeed)
---
---@param low number The lower 32 bits of the seed value. Must be within the range of 0 to 2^32 - 1.
---@param high number The higher 32 bits of the seed value. Must be within the range of 0 to 2^32 - 1.
function love.math.setRandomSeed(low, high)
end

---Sets the current state of the random number generator. The value used as an argument for this function is an opaque implementation-dependent string and should only originate from a previous call to love.math.getRandomState.
---
---This is different from love.math.setRandomSeed in that setRandomState directly sets the random number generator's current implementation-dependent state, whereas setRandomSeed gives it a new seed value.
---
---The effect of the state string does not depend on the current operating system.
---
---[Open in Browser](https://love2d.org/wiki/love.math.setRandomState)
---
---@param state string The new state of the random number generator, represented as a string. This should originate from a previous call to love.math.getRandomState.
function love.math.setRandomState(state)
end

---Generates a Simplex noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Simplex noise from 1 dimension.
---
---[Open in Browser](https://love2d.org/wiki/love.math.simplexNoise)
---
---@param x number The number used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.simplexNoise(x)
end

---Generates a Simplex noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Simplex noise from 2 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.simplexNoise)
---
---@param x number The first value of the 2-dimensional vector used to generate the noise value.
---@param y number The second value of the 2-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.simplexNoise(x, y)
end

---Generates a Simplex noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Simplex noise from 3 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.simplexNoise)
---
---@param x number The first value of the 3-dimensional vector used to generate the noise value.
---@param y number The second value of the 3-dimensional vector used to generate the noise value.
---@param z number The third value of the 3-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.simplexNoise(x, y, z)
end

---Generates a Simplex noise value in 1 to 4 dimensions, between 0 and 1. The return value will always be the same, given the same arguments.
---
---It is widely used for procedural content generation.
---
---Generates Simplex noise from 4 dimensions.
---
---[Open in Browser](https://love2d.org/wiki/love.math.simplexNoise)
---
---@param x number The first value of the 4-dimensional vector used to generate the noise value.
---@param y number The second value of the 4-dimensional vector used to generate the noise value.
---@param z number The third value of the 4-dimensional vector used to generate the noise value.
---@param w number The fourth value of the 4-dimensional vector used to generate the noise value.
---@return number value The noise value, between 0 and 1.
function love.math.simplexNoise(x, y, z, w)
end

---Decomposes a simple convex or concave polygon into triangles.
---
---[Open in Browser](https://love2d.org/wiki/love.math.triangulate)
---
---@param polygon (number)[] Polygon to triangulate, in the form of {x1, y1, x2, y2, x3, y3, ...}. Must have at least 3 vertices and must not intersect itself.
---@return table triangles List of triangles the polygon is composed of, in the form of {{x1, y1, x2, y2, x3, y3},  {x1, y1, x2, y2, x3, y3}, ...}.
function love.math.triangulate(polygon)
end

---Decomposes a simple convex or concave polygon into triangles.
---
---[Open in Browser](https://love2d.org/wiki/love.math.triangulate)
---
---@param x1 number The position of the first vertex of the polygon on the x-axis.
---@param y1 number The position of the first vertex of the polygon on the y-axis.
---@param x2 number The position of the second vertex of the polygon on the x-axis.
---@param y2 number The position of the second vertex of the polygon on the y-axis.
---@param x3 number The position of the third vertex of the polygon on the x-axis.
---@param y3 number The position of the third vertex of the polygon on the y-axis.
---@param ... number Additional vertices of the polygon, as x and y position pairs.
---@return table triangles List of triangles the polygon is composed of, in the form of {{x1, y1, x2, y2, x3, y3},  {x1, y1, x2, y2, x3, y3}, ...}.
function love.math.triangulate(x1, y1, x2, y2, x3, y3, ...)
end

---Provides an interface to the user's mouse.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse)
---
---@class love.mouse
love.mouse = {}

---Types of hardware cursors.
---
---[Open in Browser](https://love2d.org/wiki/CursorType)
---
---@alias love.mouse.CursorType
---The cursor is using a custom image.
---| "image"
---An arrow pointer.
---| "arrow"
---An I-beam, normally used when mousing over editable or selectable text.
---| "ibeam"
---Wait graphic.
---| "wait"
---Small wait cursor with an arrow pointer.
---| "waitarrow"
---Crosshair symbol.
---| "crosshair"
---Double arrow pointing to the top-left and bottom-right.
---| "sizenwse"
---Double arrow pointing to the top-right and bottom-left.
---| "sizenesw"
---Double arrow pointing left and right.
---| "sizewe"
---Double arrow pointing up and down.
---| "sizens"
---Four-pointed arrow pointing up, down, left, and right.
---| "sizeall"
---Slashed circle or crossbones.
---| "no"
---Hand symbol.
---| "hand"
---@alias love.CursorType love.mouse.CursorType

---Represents a hardware cursor.
---
---[Open in Browser](https://love2d.org/wiki/Cursor)
---
---@class love.mouse.Cursor: love.Object
local Cursor = {}
---@alias love.Cursor love.mouse.Cursor

---Gets the type of the Cursor.
---
---[Open in Browser](https://love2d.org/wiki/Cursor:getType)
---
---@return love.mouse.CursorType ctype The type of the Cursor.
function Cursor:getType()
end

---Gets the current Cursor.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getCursor)
---
---@return love.mouse.Cursor|nil cursor The current cursor, or nil if no cursor is set.
function love.mouse.getCursor()
end

---Gets the global position of the mouse on the screen. This can be used when implementing custom drag areas in the window.
---
---The global mouse position is in the same coordinate space as love.window.getPosition and love.window.setPosition.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getGlobalPosition)
---
---@return number x The x-coordinate of the mouse's global position, within its current display.
---@return number y The y-coordinate of the mouse's global position, within its current display.
---@return number displayindex The index of the display that the mouse is in.
function love.mouse.getGlobalPosition()
end

---Returns the current position of the mouse.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getPosition)
---
---@return number x The position of the mouse along the x-axis.
---@return number y The position of the mouse along the y-axis.
function love.mouse.getPosition()
end

---Gets whether relative mode is enabled for the mouse.
---
---If relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen.
---
---The reported position of the mouse is not updated while relative mode is enabled, even when relative mouse motion events are generated.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getRelativeMode)
---
---@return boolean enabled True if relative mode is enabled, false if it's disabled.
function love.mouse.getRelativeMode()
end

---Gets a Cursor object representing a system-native hardware cursor.
---
---Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
---
---The 'image' CursorType is not a valid argument. Use love.mouse.newCursor to create a hardware cursor using a custom image.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getSystemCursor)
---
---@param ctype love.mouse.CursorType The type of system cursor to get. 
---@return love.mouse.Cursor cursor The Cursor object representing the system cursor type.
function love.mouse.getSystemCursor(ctype)
end

---Returns the current x-position of the mouse.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getX)
---
---@return number x The position of the mouse along the x-axis.
function love.mouse.getX()
end

---Returns the current y-position of the mouse.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.getY)
---
---@return number y The position of the mouse along the y-axis.
function love.mouse.getY()
end

---Gets whether cursor functionality is supported.
---
---If it isn't supported, calling love.mouse.newCursor and love.mouse.getSystemCursor will cause an error. Mobile devices do not support cursors.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.isCursorSupported)
---
---@return boolean supported Whether the system has cursor functionality.
function love.mouse.isCursorSupported()
end

---Checks whether a certain mouse button is down.
---
---This function does not detect mouse wheel scrolling; you must use the love.wheelmoved (or love.mousepressed in version 0.9.2 and older) callback for that. 
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.isDown)
---
---@param button number The index of a button to check. 1 is the primary mouse button, 2 is the secondary mouse button and 3 is the middle button. Further buttons are mouse dependant.
---@param ... number Additional button numbers to check.
---@return boolean down True if any specified button is down.
function love.mouse.isDown(button, ...)
end

---Checks whether a certain mouse button is down.
---
---This function does not detect mouse wheel scrolling; you must use the love.wheelmoved (or love.mousepressed in version 0.9.2 and older) callback for that. 
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.isDown)
---
---@param buttons (number)[] A list of button indices to check.
---@return boolean down True if any button in the list is down.
function love.mouse.isDown(buttons)
end

---Checks if the mouse is grabbed.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.isGrabbed)
---
---@return boolean grabbed True if the cursor is grabbed, false if it is not.
function love.mouse.isGrabbed()
end

---Checks if the cursor is visible.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.isVisible)
---
---@return boolean visible True if the cursor to visible, false if the cursor is hidden.
function love.mouse.isVisible()
end

---Creates a new hardware Cursor object from an image file or ImageData. The image must use the rgba8 pixel format.
---
---Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
---
---The hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.newCursor)
---
---@param imageData love.image.ImageData The ImageData to use for the new Cursor.
---@param hotx (number)? The x-coordinate in the ImageData of the cursor's hot spot.
---@param hoty (number)? The y-coordinate in the ImageData of the cursor's hot spot.
---@return love.mouse.Cursor cursor The new Cursor object.
function love.mouse.newCursor(imageData, hotx, hoty)
end

---Creates a new hardware Cursor object from an image file or ImageData. The image must use the rgba8 pixel format.
---
---Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
---
---The hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.newCursor)
---
---@param filename string|love.filesystem.File Path to the image, or a File of the image, to use for the new Cursor.
---@param hotx (number)? The x-coordinate in the image of the cursor's hot spot.
---@param hoty (number)? The y-coordinate in the image of the cursor's hot spot.
---@return love.mouse.Cursor cursor The new Cursor object.
function love.mouse.newCursor(filename, hotx, hoty)
end

---Creates a new hardware Cursor object from an image file or ImageData. The image must use the rgba8 pixel format.
---
---Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
---
---The hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.newCursor)
---
---@param fileData love.filesystem.FileData Data representing the image to use for the new Cursor.
---@param hotx (number)? The x-coordinate in the image of the cursor's hot spot.
---@param hoty (number)? The y-coordinate in the image of the cursor's hot spot.
---@return love.mouse.Cursor cursor The new Cursor object.
function love.mouse.newCursor(fileData, hotx, hoty)
end

---Creates a new hardware Cursor object from an image file or ImageData. The image must use the rgba8 pixel format.
---
---Hardware cursors are framerate-independent and work the same way as normal operating system cursors. Unlike drawing an image at the mouse's current coordinates, hardware cursors never have visible lag between when the mouse is moved and when the cursor position updates, even at low framerates.
---
---The hot spot is the point the operating system uses to determine what was clicked and at what position the mouse cursor is. For example, the normal arrow pointer normally has its hot spot at the top left of the image, but a crosshair cursor might have it in the middle.
---
---The first image is the cursor at its normal size; the others are alternate versions the operating system can use at other DPI scales.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.newCursor)
---
---@param images (love.image.ImageData|string|love.filesystem.File|love.filesystem.FileData)[] A list of images for the new Cursor. Each entry is an ImageData, a filename, a File or a FileData.
---@param hotx (number)? The x-coordinate in the first image of the cursor's hot spot.
---@param hoty (number)? The y-coordinate in the first image of the cursor's hot spot.
---@return love.mouse.Cursor cursor The new Cursor object.
function love.mouse.newCursor(images, hotx, hoty)
end

---Sets the current mouse cursor.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setCursor)
---
---@param cursor love.mouse.Cursor The Cursor object to use as the current mouse cursor.
function love.mouse.setCursor(cursor)
end

---Sets the current mouse cursor.
---
---Resets the current mouse cursor to the default.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setCursor)
---
function love.mouse.setCursor()
end

---Grabs the mouse and confines it to the window.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setGrabbed)
---
---@param grab boolean True to confine the mouse, false to let it leave the window.
function love.mouse.setGrabbed(grab)
end

---Sets the current position of the mouse. Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setPosition)
---
---@param x number The new position of the mouse along the x-axis.
---@param y number The new position of the mouse along the y-axis.
function love.mouse.setPosition(x, y)
end

---Sets whether relative mode is enabled for the mouse.
---
---When relative mode is enabled, the cursor is hidden and doesn't move when the mouse does, but relative mouse motion events are still generated via love.mousemoved. This lets the mouse move in any direction indefinitely without the cursor getting stuck at the edges of the screen.
---
---The reported position of the mouse may not be updated while relative mode is enabled, even when relative mouse motion events are generated.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setRelativeMode)
---
---@param enable boolean True to enable relative mode, false to disable it.
function love.mouse.setRelativeMode(enable)
end

---Sets the current visibility of the cursor.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setVisible)
---
---@param visible boolean True to set the cursor to visible, false to hide the cursor.
function love.mouse.setVisible(visible)
end

---Sets the current X position of the mouse.
---
---Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setX)
---
---@param x number The new position of the mouse along the x-axis.
function love.mouse.setX(x)
end

---Sets the current Y position of the mouse.
---
---Non-integer values are floored.
---
---[Open in Browser](https://love2d.org/wiki/love.mouse.setY)
---
---@param y number The new position of the mouse along the y-axis.
function love.mouse.setY(y)
end

---Can simulate 2D rigid body physics in a realistic manner. This module is based on Box2D, and this API corresponds to the Box2D API as closely as possible.
---
---[Open in Browser](https://love2d.org/wiki/love.physics)
---
---@class love.physics
love.physics = {}

---The types of a Body. 
---
---[Open in Browser](https://love2d.org/wiki/BodyType)
---
---@alias love.physics.BodyType
---Static bodies do not move.
---| "static"
---Dynamic bodies collide with all bodies.
---| "dynamic"
---Kinematic bodies only collide with dynamic bodies.
---| "kinematic"
---@alias love.BodyType love.physics.BodyType

---Different types of joints.
---
---[Open in Browser](https://love2d.org/wiki/JointType)
---
---@alias love.physics.JointType
---A DistanceJoint.
---| "distance"
---A FrictionJoint.
---| "friction"
---A GearJoint.
---| "gear"
---A MotorJoint.
---| "motor"
---A MouseJoint.
---| "mouse"
---A PrismaticJoint.
---| "prismatic"
---A PulleyJoint.
---| "pulley"
---A RevoluteJoint.
---| "revolute"
---A RopeJoint.
---| "rope"
---A WeldJoint.
---| "weld"
---A WheelJoint.
---| "wheel"
---@alias love.JointType love.physics.JointType

---The different types of Shapes, as returned by Shape:getType.
---
---[Open in Browser](https://love2d.org/wiki/ShapeType)
---
---@alias love.physics.ShapeType
---The Shape is a CircleShape.
---| "circle"
---The Shape is a PolygonShape.
---| "polygon"
---The Shape is a EdgeShape.
---| "edge"
---The Shape is a ChainShape.
---| "chain"
---@alias love.ShapeType love.physics.ShapeType

---Bodies are objects with velocity and position.
---
---[Open in Browser](https://love2d.org/wiki/Body)
---
---@class love.physics.Body: love.Object
local Body = {}
---@alias love.Body love.physics.Body

---Applies an angular impulse to a body. This makes a single, instantaneous addition to the body momentum.
---
---A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyAngularImpulse)
---
---@param impulse number The impulse in kilogram-square meter per second.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyAngularImpulse(impulse, awake)
end

---Apply force to a Body.
---
---A force pushes a body in a direction. A body with with a larger mass will react less. The reaction also depends on how long a force is applied: since the force acts continuously over the entire timestep, a short timestep will only push the body for a short time. Thus forces are best used for many timesteps to give a continuous push to a body (like gravity). For a single push that is independent of timestep, it is better to use Body:applyLinearImpulse.
---
---If the position to apply the force is not given, it will act on the center of mass of the body. The part of the force not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).
---
---Note that the force components and position must be given in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyForce)
---
---@param fx number The x component of force to apply to the center of mass.
---@param fy number The y component of force to apply to the center of mass.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyForce(fx, fy, awake)
end

---Apply force to a Body.
---
---A force pushes a body in a direction. A body with with a larger mass will react less. The reaction also depends on how long a force is applied: since the force acts continuously over the entire timestep, a short timestep will only push the body for a short time. Thus forces are best used for many timesteps to give a continuous push to a body (like gravity). For a single push that is independent of timestep, it is better to use Body:applyLinearImpulse.
---
---If the position to apply the force is not given, it will act on the center of mass of the body. The part of the force not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia).
---
---Note that the force components and position must be given in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyForce)
---
---@param fx number The x component of force to apply.
---@param fy number The y component of force to apply.
---@param x number The x position to apply the force.
---@param y number The y position to apply the force.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyForce(fx, fy, x, y, awake)
end

---Applies an impulse to a body.
---
---This makes a single, instantaneous addition to the body momentum.
---
---An impulse pushes a body in a direction. A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce.
---
---If the position to apply the impulse is not given, it will act on the center of mass of the body. The part of the impulse not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia). 
---
---Note that the impulse components and position must be given in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyLinearImpulse)
---
---@param ix number The x component of the impulse applied to the center of mass.
---@param iy number The y component of the impulse applied to the center of mass.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyLinearImpulse(ix, iy, awake)
end

---Applies an impulse to a body.
---
---This makes a single, instantaneous addition to the body momentum.
---
---An impulse pushes a body in a direction. A body with with a larger mass will react less. The reaction does '''not''' depend on the timestep, and is equivalent to applying a force continuously for 1 second. Impulses are best used to give a single push to a body. For a continuous push to a body it is better to use Body:applyForce.
---
---If the position to apply the impulse is not given, it will act on the center of mass of the body. The part of the impulse not directed towards the center of mass will cause the body to spin (and depends on the rotational inertia). 
---
---Note that the impulse components and position must be given in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyLinearImpulse)
---
---@param ix number The x component of the impulse.
---@param iy number The y component of the impulse.
---@param x number The x position to apply the impulse.
---@param y number The y position to apply the impulse.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyLinearImpulse(ix, iy, x, y, awake)
end

---Apply torque to a body.
---
---Torque is like a force that will change the angular velocity (spin) of a body. The effect will depend on the rotational inertia a body has.
---
---[Open in Browser](https://love2d.org/wiki/Body:applyTorque)
---
---@param torque number The torque to apply.
---@param awake (boolean)? Whether to wake the Body up if it is sleeping.
function Body:applyTorque(torque, awake)
end

---Explicitly destroys the Body and all Shapes and Joints attached to it.
---
---An error will occur if you attempt to use the object after calling this function.
---
---[Open in Browser](https://love2d.org/wiki/Body:destroy)
---
function Body:destroy()
end

---Get the angle of the body.
---
---The angle is measured in radians. If you need to transform it to degrees, use math.deg.
---
---A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view.
---
---[Open in Browser](https://love2d.org/wiki/Body:getAngle)
---
---@return number angle The angle in radians.
function Body:getAngle()
end

---Gets the Angular damping of the Body
---
---The angular damping is the ''rate of decrease of the angular velocity over time'': A spinning body with no damping and no external forces will continue spinning indefinitely. A spinning body with damping will gradually stop spinning.
---
---Damping is not the same as friction - they can be modelled together. However, only damping is provided by Box2D (and LOVE).
---
---Damping parameters should be between 0 and infinity, with 0 meaning no damping, and infinity meaning full damping. Normally you will use a damping value between 0 and 0.1.
---
---[Open in Browser](https://love2d.org/wiki/Body:getAngularDamping)
---
---@return number damping The value of the angular damping.
function Body:getAngularDamping()
end

---Get the angular velocity of the Body.
---
---The angular velocity is the ''rate of change of angle over time''.
---
---It is changed in World:update by applying torques, off centre forces/impulses, and angular damping. It can be set directly with Body:setAngularVelocity.
---
---If you need the ''rate of change of position over time'', use Body:getLinearVelocity.
---
---[Open in Browser](https://love2d.org/wiki/Body:getAngularVelocity)
---
---@return number w The angular velocity in radians/second.
function Body:getAngularVelocity()
end

---Gets a list of all Contacts attached to the Body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getContacts)
---
---@return (love.physics.Contact)[] contacts A list with all contacts associated with the Body.
function Body:getContacts()
end

---Returns the gravity scale factor.
---
---[Open in Browser](https://love2d.org/wiki/Body:getGravityScale)
---
---@return number scale The gravity scale factor.
function Body:getGravityScale()
end

---Gets the rotational inertia of the body.
---
---The rotational inertia is how hard is it to make the body spin.
---
---[Open in Browser](https://love2d.org/wiki/Body:getInertia)
---
---@return number inertia The rotational inertial of the body.
function Body:getInertia()
end

---Returns a table containing the Joints attached to this Body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getJoints)
---
---@return (love.physics.Joint)[] joints A sequence with the Joints attached to the Body.
function Body:getJoints()
end

---Gets the position, angle, linear velocity and angular velocity of the Body in one call.
---
---[Open in Browser](https://love2d.org/wiki/Body:getKinematicState)
---
---@return number x The x position of the Body.
---@return number y The y position of the Body.
---@return number angle The angle of the Body in radians.
---@return number vx The x component of the linear velocity.
---@return number vy The y component of the linear velocity.
---@return number angularVelocity The angular velocity in radians per second.
function Body:getKinematicState()
end

---Gets the linear damping of the Body.
---
---The linear damping is the ''rate of decrease of the linear velocity over time''. A moving body with no damping and no external forces will continue moving indefinitely, as is the case in space. A moving body with damping will gradually stop moving.
---
---Damping is not the same as friction - they can be modelled together.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLinearDamping)
---
---@return number damping The value of the linear damping.
function Body:getLinearDamping()
end

---Gets the linear velocity of the Body from its center of mass.
---
---The linear velocity is the ''rate of change of position over time''.
---
---If you need the ''rate of change of angle over time'', use Body:getAngularVelocity.
---
---If you need to get the linear velocity of a point different from the center of mass:
---
---*  Body:getLinearVelocityFromLocalPoint allows you to specify the point in local coordinates.
---
---*  Body:getLinearVelocityFromWorldPoint allows you to specify the point in world coordinates.
---
---See page 136 of 'Essential Mathematics for Games and Interactive Applications' for definitions of local and world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLinearVelocity)
---
---@return number x The x-component of the velocity vector
---@return number y The y-component of the velocity vector
function Body:getLinearVelocity()
end

---Get the linear velocity of a point on the body.
---
---The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.
---
---The point on the body must given in local coordinates. Use Body:getLinearVelocityFromWorldPoint to specify this with world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLinearVelocityFromLocalPoint)
---
---@param x number The x position to measure velocity.
---@param y number The y position to measure velocity.
---@return number vx The x component of velocity at point (x,y).
---@return number vy The y component of velocity at point (x,y).
function Body:getLinearVelocityFromLocalPoint(x, y)
end

---Get the linear velocity of a point on the body.
---
---The linear velocity for a point on the body is the velocity of the body center of mass plus the velocity at that point from the body spinning.
---
---The point on the body must given in world coordinates. Use Body:getLinearVelocityFromLocalPoint to specify this with local coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLinearVelocityFromWorldPoint)
---
---@param x number The x position to measure velocity.
---@param y number The y position to measure velocity.
---@return number vx The x component of velocity at point (x,y).
---@return number vy The y component of velocity at point (x,y).
function Body:getLinearVelocityFromWorldPoint(x, y)
end

---Get the center of mass position in local coordinates.
---
---Use Body:getWorldCenter to get the center of mass in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLocalCenter)
---
---@return number x The x coordinate of the center of mass.
---@return number y The y coordinate of the center of mass.
function Body:getLocalCenter()
end

---Transform a point from world coordinates to local coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLocalPoint)
---
---@param worldX number The x position in world coordinates.
---@param worldY number The y position in world coordinates.
---@return number localX The x position in local coordinates.
---@return number localY The y position in local coordinates.
function Body:getLocalPoint(worldX, worldY)
end

---Transforms multiple points from world coordinates to local coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLocalPoints)
---
---@param x1 number (Argument) The x position of the first point.
---@param y1 number (Argument) The y position of the first point.
---@param x2 number (Argument) The x position of the second point.
---@param y2 number (Argument) The y position of the second point.
---@param ... number (Argument) You can continue passing x and y position of the points.
---@return number x1 (Result) The transformed x position of the first point.
---@return number y1 (Result) The transformed y position of the first point.
---@return number x2 (Result) The transformed x position of the second point.
---@return number y2 (Result) The transformed y position of the second point.
---@return number ... (Result) Additional transformed x and y position of the points.
function Body:getLocalPoints(x1, y1, x2, y2, ...)
end

---Transform a vector from world coordinates to local coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getLocalVector)
---
---@param worldX number The vector x component in world coordinates.
---@param worldY number The vector y component in world coordinates.
---@return number localX The vector x component in local coordinates.
---@return number localY The vector y component in local coordinates.
function Body:getLocalVector(worldX, worldY)
end

---Get the mass of the body.
---
---Static bodies always have a mass of 0.
---
---[Open in Browser](https://love2d.org/wiki/Body:getMass)
---
---@return number mass The mass of the body (in kilograms).
function Body:getMass()
end

---Returns the mass, its center, and the rotational inertia.
---
---[Open in Browser](https://love2d.org/wiki/Body:getMassData)
---
---@return number x The x position of the center of mass.
---@return number y The y position of the center of mass.
---@return number mass The mass of the body.
---@return number inertia The rotational inertia.
function Body:getMassData()
end

---Get the position of the body.
---
---Note that this may not be the center of mass of the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getPosition)
---
---@return number x The x position.
---@return number y The y position.
function Body:getPosition()
end

---Returns the first Shape attached to the Body. Useful for Bodies that have a single Shape, such as those made by love.physics.newCircleBody.
---
---[Open in Browser](https://love2d.org/wiki/Body:getShape)
---
---@return love.physics.Shape shape The first Shape attached to the Body, or nil if it has none.
function Body:getShape()
end

---Returns a table with all Shapes attached to the Body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getShapes)
---
---@return (love.physics.Shape)[] shapes A sequence with all Shapes attached to the Body.
function Body:getShapes()
end

---Get the position and angle of the body.
---
---Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view.
---
---[Open in Browser](https://love2d.org/wiki/Body:getTransform)
---
---@return number x The x component of the position.
---@return number y The y component of the position.
---@return number angle The angle in radians.
function Body:getTransform()
end

---Returns the type of the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getType)
---
---@return love.physics.BodyType type The body type.
function Body:getType()
end

---Returns the Lua value associated with this Body.
---
---[Open in Browser](https://love2d.org/wiki/Body:getUserData)
---
---@return any value The Lua value associated with the Body.
function Body:getUserData()
end

---Gets the World the body lives in.
---
---[Open in Browser](https://love2d.org/wiki/Body:getWorld)
---
---@return love.physics.World world The world the body lives in.
function Body:getWorld()
end

---Get the center of mass position in world coordinates.
---
---Use Body:getLocalCenter to get the center of mass in local coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getWorldCenter)
---
---@return number x The x coordinate of the center of mass.
---@return number y The y coordinate of the center of mass.
function Body:getWorldCenter()
end

---Transform a point from local coordinates to world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getWorldPoint)
---
---@param localX number The x position in local coordinates.
---@param localY number The y position in local coordinates.
---@return number worldX The x position in world coordinates.
---@return number worldY The y position in world coordinates.
function Body:getWorldPoint(localX, localY)
end

---Transforms multiple points from local coordinates to world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getWorldPoints)
---
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param ... number Additional x and y coordinates of more points.
---@return number x1 The transformed x position of the first point.
---@return number y1 The transformed y position of the first point.
---@return number x2 The transformed x position of the second point.
---@return number y2 The transformed y position of the second point.
---@return number ... Additional transformed x and y coordinates.
function Body:getWorldPoints(x1, y1, x2, y2, ...)
end

---Transform a vector from local coordinates to world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getWorldVector)
---
---@param localX number The vector x component in local coordinates.
---@param localY number The vector y component in local coordinates.
---@return number worldX The vector x component in world coordinates.
---@return number worldY The vector y component in world coordinates.
function Body:getWorldVector(localX, localY)
end

---Get the x position of the body in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getX)
---
---@return number x The x position in world coordinates.
function Body:getX()
end

---Get the y position of the body in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Body:getY)
---
---@return number y The y position in world coordinates.
function Body:getY()
end

---Gets whether the Body's mass data was set explicitly with Body:setMass, Body:setMassData or Body:setInertia rather than computed from its Shapes. Body:resetMassData clears it.
---
---[Open in Browser](https://love2d.org/wiki/Body:hasCustomMassData)
---
---@return boolean custom Whether the Body has custom mass data.
function Body:hasCustomMassData()
end

---Returns whether the body is actively used in the simulation.
---
---[Open in Browser](https://love2d.org/wiki/Body:isActive)
---
---@return boolean status True if the body is active or false if not.
function Body:isActive()
end

---Returns the sleep status of the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:isAwake)
---
---@return boolean status True if the body is awake or false if not.
function Body:isAwake()
end

---Get the bullet status of a body.
---
---There are two methods to check for body collisions:
---
---*  at their location when the world is updated (default)
---
---*  using continuous collision detection (CCD)
---
---The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.
---
---Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
---
---[Open in Browser](https://love2d.org/wiki/Body:isBullet)
---
---@return boolean status The bullet status of the body.
function Body:isBullet()
end

---Gets whether the Body is destroyed. Destroyed bodies cannot be used.
---
---[Open in Browser](https://love2d.org/wiki/Body:isDestroyed)
---
---@return boolean destroyed Whether the Body is destroyed.
function Body:isDestroyed()
end

---Returns whether the body rotation is locked.
---
---[Open in Browser](https://love2d.org/wiki/Body:isFixedRotation)
---
---@return boolean fixed True if the body's rotation is locked or false if not.
function Body:isFixedRotation()
end

---Returns the sleeping behaviour of the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:isSleepingAllowed)
---
---@return boolean allowed True if the body is allowed to sleep or false if not.
function Body:isSleepingAllowed()
end

---Gets whether the Body is touching the given other Body.
---
---[Open in Browser](https://love2d.org/wiki/Body:isTouching)
---
---@param otherbody love.physics.Body The other body to check.
---@return boolean touching True if this body is touching the other body, false otherwise.
function Body:isTouching(otherbody)
end

---Resets the mass of the body by recalculating it from the mass properties of its Shapes. Afterwards the Body no longer has custom mass data.
---
---[Open in Browser](https://love2d.org/wiki/Body:resetMassData)
---
function Body:resetMassData()
end

---Sets whether the body is active in the world.
---
---An inactive body does not take part in the simulation. It will not move or cause any collisions.
---
---[Open in Browser](https://love2d.org/wiki/Body:setActive)
---
---@param active boolean If the body is active or not.
function Body:setActive(active)
end

---Set the angle of the body.
---
---The angle is measured in radians. If you need to transform it from degrees, use math.rad.
---
---A value of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes ''clockwise'' from our point of view.
---
---It is possible to cause a collision with another body by changing its angle. 
---
---[Open in Browser](https://love2d.org/wiki/Body:setAngle)
---
---@param angle number The angle in radians.
function Body:setAngle(angle)
end

---Sets the angular damping of a Body
---
---See Body:getAngularDamping for a definition of angular damping.
---
---Angular damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will look unrealistic.
---
---[Open in Browser](https://love2d.org/wiki/Body:setAngularDamping)
---
---@param damping number The new angular damping.
function Body:setAngularDamping(damping)
end

---Sets the angular velocity of a Body.
---
---The angular velocity is the ''rate of change of angle over time''.
---
---This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost. 
---
---[Open in Browser](https://love2d.org/wiki/Body:setAngularVelocity)
---
---@param w number The new angular velocity, in radians per second
function Body:setAngularVelocity(w)
end

---Wakes the body up or puts it to sleep.
---
---[Open in Browser](https://love2d.org/wiki/Body:setAwake)
---
---@param awake boolean The body sleep status.
function Body:setAwake(awake)
end

---Set the bullet status of a body.
---
---There are two methods to check for body collisions:
---
---*  at their location when the world is updated (default)
---
---*  using continuous collision detection (CCD)
---
---The default method is efficient, but a body moving very quickly may sometimes jump over another body without producing a collision. A body that is set as a bullet will use CCD. This is less efficient, but is guaranteed not to jump when moving quickly.
---
---Note that static bodies (with zero mass) always use CCD, so your walls will not let a fast moving body pass through even if it is not a bullet.
---
---[Open in Browser](https://love2d.org/wiki/Body:setBullet)
---
---@param status boolean The bullet status of the body.
function Body:setBullet(status)
end

---Set whether a body has fixed rotation.
---
---Bodies with fixed rotation don't vary the speed at which they rotate. Calling this function causes the mass to be reset. 
---
---[Open in Browser](https://love2d.org/wiki/Body:setFixedRotation)
---
---@param isFixed boolean Whether the body should have fixed rotation.
function Body:setFixedRotation(isFixed)
end

---Sets a new gravity scale factor for the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:setGravityScale)
---
---@param scale number The new gravity scale factor.
function Body:setGravityScale(scale)
end

---Set the inertia of a body. Afterwards the Body has custom mass data, so changing the density of its Shapes no longer changes its mass.
---
---[Open in Browser](https://love2d.org/wiki/Body:setInertia)
---
---@param inertia number The new moment of inertia, in kilograms * pixel squared.
function Body:setInertia(inertia)
end

---Sets the position, angle, linear velocity and angular velocity of the Body in one call.
---
---[Open in Browser](https://love2d.org/wiki/Body:setKinematicState)
---
---@param x number The x position of the Body.
---@param y number The y position of the Body.
---@param angle number The angle of the Body in radians.
---@param vx number The x component of the linear velocity.
---@param vy number The y component of the linear velocity.
---@param angularVelocity number The angular velocity in radians per second.
function Body:setKinematicState(x, y, angle, vx, vy, angularVelocity)
end

---Sets the linear damping of a Body
---
---See Body:getLinearDamping for a definition of linear damping.
---
---Linear damping can take any value from 0 to infinity. It is recommended to stay between 0 and 0.1, though. Other values will make the objects look 'floaty'(if gravity is enabled).
---
---[Open in Browser](https://love2d.org/wiki/Body:setLinearDamping)
---
---@param ld number The new linear damping
function Body:setLinearDamping(ld)
end

---Sets a new linear velocity for the Body.
---
---This function will not accumulate anything; any impulses previously applied since the last call to World:update will be lost.
---
---[Open in Browser](https://love2d.org/wiki/Body:setLinearVelocity)
---
---@param x number The x-component of the velocity vector.
---@param y number The y-component of the velocity vector.
function Body:setLinearVelocity(x, y)
end

---Sets a new body mass. Afterwards the Body has custom mass data, so changing the density of its Shapes no longer changes its mass.
---
---[Open in Browser](https://love2d.org/wiki/Body:setMass)
---
---@param mass number The mass, in kilograms.
function Body:setMass(mass)
end

---Overrides the calculated mass data. Afterwards the Body has custom mass data, so changing the density of its Shapes no longer changes its mass.
---
---[Open in Browser](https://love2d.org/wiki/Body:setMassData)
---
---@param x number The x position of the center of mass.
---@param y number The y position of the center of mass.
---@param mass number The mass of the body.
---@param inertia number The rotational inertia.
function Body:setMassData(x, y, mass, inertia)
end

---Set the position of the body.
---
---Note that this may not be the center of mass of the body.
---
---This function cannot wake up the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:setPosition)
---
---@param x number The x position.
---@param y number The y position.
function Body:setPosition(x, y)
end

---Sets the sleeping behaviour of the body. Should sleeping be allowed, a body at rest will automatically sleep. A sleeping body is not simulated unless it collided with an awake body. Be wary that one can end up with a situation like a floating sleeping body if the floor was removed.
---
---[Open in Browser](https://love2d.org/wiki/Body:setSleepingAllowed)
---
---@param allowed boolean True if the body is allowed to sleep or false if not.
function Body:setSleepingAllowed(allowed)
end

---Set the position and angle of the body.
---
---Note that the position may not be the center of mass of the body. An angle of 0 radians will mean 'looking to the right'. Although radians increase counter-clockwise, the y axis points down so it becomes clockwise from our point of view.
---
---This function cannot wake up the body.
---
---[Open in Browser](https://love2d.org/wiki/Body:setTransform)
---
---@param x number The x component of the position.
---@param y number The y component of the position.
---@param angle number The angle in radians.
function Body:setTransform(x, y, angle)
end

---Sets a new body type.
---
---[Open in Browser](https://love2d.org/wiki/Body:setType)
---
---@param type love.physics.BodyType The new type.
function Body:setType(type)
end

---Associates a Lua value with the Body.
---
---To delete the reference, explicitly pass nil.
---
---[Open in Browser](https://love2d.org/wiki/Body:setUserData)
---
---@param value any The Lua value to associate with the Body.
function Body:setUserData(value)
end

---Set the x position of the body.
---
---This function cannot wake up the body. 
---
---[Open in Browser](https://love2d.org/wiki/Body:setX)
---
---@param x number The x position.
function Body:setX(x)
end

---Set the y position of the body.
---
---This function cannot wake up the body. 
---
---[Open in Browser](https://love2d.org/wiki/Body:setY)
---
---@param y number The y position.
function Body:setY(y)
end

---A ChainShape consists of multiple line segments. It can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape.
---
---Unlike the PolygonShape, the ChainShape does not have a vertices limit or has to form a convex shape, but self intersections are not supported.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape)
---
---@class love.physics.ChainShape: love.physics.Shape, love.Object
local ChainShape = {}
---@alias love.ChainShape love.physics.ChainShape

---Deprecated, with no replacement. Returns a child of the shape as a new EdgeShape that is not attached to any Body.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getChildEdge)
---
---@param index number The index of the child.
---@return love.physics.EdgeShape shape The child as an EdgeShape.
function ChainShape:getChildEdge(index)
end

---Gets the vertex that establishes a connection to the next shape.
---
---Setting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getNextVertex)
---
---@return number x The x-component of the vertex, or nil if ChainShape:setNextVertex hasn't been called.
---@return number y The y-component of the vertex, or nil if ChainShape:setNextVertex hasn't been called.
function ChainShape:getNextVertex()
end

---Returns a point of the shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getPoint)
---
---@param index number The index of the point to return.
---@return number x The x-coordinate of the point.
---@return number y The y-coordinate of the point.
function ChainShape:getPoint(index)
end

---Returns all points of the shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getPoints)
---
---@return number x1 The x-coordinate of the first point.
---@return number y1 The y-coordinate of the first point.
---@return number x2 The x-coordinate of the second point.
---@return number y2 The y-coordinate of the second point.
---@return number ... Additional x and y coordinates of the remaining points.
function ChainShape:getPoints()
end

---Gets the vertex that establishes a connection to the previous shape.
---
---Setting next and previous ChainShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getPreviousVertex)
---
---@return number x The x-component of the vertex, or nil if ChainShape:setPreviousVertex hasn't been called.
---@return number y The y-component of the vertex, or nil if ChainShape:setPreviousVertex hasn't been called.
function ChainShape:getPreviousVertex()
end

---Returns the number of vertices the shape has.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:getVertexCount)
---
---@return number count The number of vertices.
function ChainShape:getVertexCount()
end

---Sets a vertex that establishes a connection to the next shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:setNextVertex)
---
---@param x number The x-component of the vertex.
---@param y number The y-component of the vertex.
function ChainShape:setNextVertex(x, y)
end

---Sets a vertex that establishes a connection to the previous shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/ChainShape:setPreviousVertex)
---
---@param x number The x-component of the vertex.
---@param y number The y-component of the vertex.
function ChainShape:setPreviousVertex(x, y)
end

---Circle extends Shape and adds a radius and a local position.
---
---[Open in Browser](https://love2d.org/wiki/CircleShape)
---
---@class love.physics.CircleShape: love.physics.Shape, love.Object
local CircleShape = {}
---@alias love.CircleShape love.physics.CircleShape

---Gets the center point of the circle shape.
---
---[Open in Browser](https://love2d.org/wiki/CircleShape:getPoint)
---
---@return number x The x-component of the center point of the circle.
---@return number y The y-component of the center point of the circle.
function CircleShape:getPoint()
end

---Gets the radius of the circle shape.
---
---[Open in Browser](https://love2d.org/wiki/CircleShape:getRadius)
---
---@return number radius The radius of the circle
function CircleShape:getRadius()
end

---Sets the location of the center of the circle shape.
---
---[Open in Browser](https://love2d.org/wiki/CircleShape:setPoint)
---
---@param x number The x-component of the new center point of the circle.
---@param y number The y-component of the new center point of the circle.
function CircleShape:setPoint(x, y)
end

---Sets the radius of the circle.
---
---[Open in Browser](https://love2d.org/wiki/CircleShape:setRadius)
---
---@param radius number The radius of the circle
function CircleShape:setRadius(radius)
end

---Contacts are objects created to manage collisions in worlds.
---
---[Open in Browser](https://love2d.org/wiki/Contact)
---
---@class love.physics.Contact: love.Object
local Contact = {}
---@alias love.Contact love.physics.Contact

---Gets the child indices of the two colliding Shapes. For ChainShapes, an index of 1 is the first edge in the chain.
---Used together with Shape:rayCast or Shape:getBoundingBox.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getChildren)
---
---@return number indexA The child index of the first Shape.
---@return number indexB The child index of the second Shape.
function Contact:getChildren()
end

---Get the friction between two shapes that are in contact.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getFriction)
---
---@return number friction The friction of the contact.
function Contact:getFriction()
end

---Get the normal vector between two shapes that are in contact.
---
---This function returns the coordinates of a unit vector that points from the first shape to the second.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getNormal)
---
---@return number nx The x component of the normal vector.
---@return number ny The y component of the normal vector.
function Contact:getNormal()
end

---Returns the contact points of the two colliding Shapes. There can be zero, one or two points, so this returns zero, two or four numbers.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getPositions)
---
---@return number x1 The x coordinate of the first contact point.
---@return number y1 The y coordinate of the first contact point.
---@return number x2 The x coordinate of the second contact point.
---@return number y2 The y coordinate of the second contact point.
function Contact:getPositions()
end

---Get the restitution between two shapes that are in contact.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getRestitution)
---
---@return number restitution The restitution between the two shapes.
function Contact:getRestitution()
end

---Gets the two Shapes that are in contact.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getShapes)
---
---@return love.physics.Shape shapeA The first Shape.
---@return love.physics.Shape shapeB The second Shape.
function Contact:getShapes()
end

---Gets the desired tangent speed of the contact, used for conveyor belt behaviour.
---
---[Open in Browser](https://love2d.org/wiki/Contact:getTangentSpeed)
---
---@return number speed The tangent speed of the contact, in meters per second.
function Contact:getTangentSpeed()
end

---Gets whether the Contact is destroyed. A Contact is destroyed when its two Shapes stop overlapping (after the endContact World callback); destroyed contacts cannot be used.
---
---[Open in Browser](https://love2d.org/wiki/Contact:isDestroyed)
---
---@return boolean destroyed Whether the Contact is destroyed.
function Contact:isDestroyed()
end

---Returns whether the contact is enabled. The collision will be ignored if a contact gets disabled in the preSolve callback.
---
---[Open in Browser](https://love2d.org/wiki/Contact:isEnabled)
---
---@return boolean enabled True if enabled, false otherwise.
function Contact:isEnabled()
end

---Returns whether the two colliding Shapes are touching each other.
---
---[Open in Browser](https://love2d.org/wiki/Contact:isTouching)
---
---@return boolean touching True if they touch or false if not.
function Contact:isTouching()
end

---Resets the contact friction to the mixture value of both Shapes.
---
---[Open in Browser](https://love2d.org/wiki/Contact:resetFriction)
---
function Contact:resetFriction()
end

---Resets the contact restitution to the mixture value of both Shapes.
---
---[Open in Browser](https://love2d.org/wiki/Contact:resetRestitution)
---
function Contact:resetRestitution()
end

---Enables or disables the contact.
---
---[Open in Browser](https://love2d.org/wiki/Contact:setEnabled)
---
---@param enabled boolean True to enable or false to disable.
function Contact:setEnabled(enabled)
end

---Sets the contact friction.
---
---[Open in Browser](https://love2d.org/wiki/Contact:setFriction)
---
---@param friction number The contact friction.
function Contact:setFriction(friction)
end

---Sets the contact restitution.
---
---[Open in Browser](https://love2d.org/wiki/Contact:setRestitution)
---
---@param restitution number The contact restitution.
function Contact:setRestitution(restitution)
end

---Sets the desired tangent speed of the contact, used for conveyor belt behaviour.
---
---[Open in Browser](https://love2d.org/wiki/Contact:setTangentSpeed)
---
---@param speed number The tangent speed of the contact, in meters per second.
function Contact:setTangentSpeed(speed)
end

---Keeps two bodies at the same distance.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint)
---
---@class love.physics.DistanceJoint: love.physics.Joint, love.Object
local DistanceJoint = {}
---@alias love.DistanceJoint love.physics.DistanceJoint

---Gets the damping of the joint's spring.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:getDamping)
---
---@return number damping The damping of the joint's spring, in newton-seconds per meter.
function DistanceJoint:getDamping()
end

---Gets the equilibrium distance between the two Bodies.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:getLength)
---
---@return number l The length between the two Bodies.
function DistanceJoint:getLength()
end

---Gets the stiffness of the joint's spring.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:getStiffness)
---
---@return number stiffness The stiffness of the joint's spring, in newtons per meter.
function DistanceJoint:getStiffness()
end

---Sets the damping of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:setDamping)
---
---@param damping number The damping of the joint's spring, in newton-seconds per meter.
function DistanceJoint:setDamping(damping)
end

---Sets the equilibrium distance between the two Bodies.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:setLength)
---
---@param l number The length between the two Bodies.
function DistanceJoint:setLength(l)
end

---Sets the stiffness of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/DistanceJoint:setStiffness)
---
---@param stiffness number The stiffness of the joint's spring, in newtons per meter.
function DistanceJoint:setStiffness(stiffness)
end

---A EdgeShape is a line segment. They can be used to create the boundaries of your terrain. The shape does not have volume and can only collide with PolygonShape and CircleShape.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape)
---
---@class love.physics.EdgeShape: love.physics.Shape, love.Object
local EdgeShape = {}
---@alias love.EdgeShape love.physics.EdgeShape

---Gets the vertex that establishes a connection to the next shape.
---
---Setting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape:getNextVertex)
---
---@return number x The x-component of the vertex, or nil if EdgeShape:setNextVertex hasn't been called.
---@return number y The y-component of the vertex, or nil if EdgeShape:setNextVertex hasn't been called.
function EdgeShape:getNextVertex()
end

---Returns the local coordinates of the edge points.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape:getPoints)
---
---@return number x1 The x-component of the first vertex.
---@return number y1 The y-component of the first vertex.
---@return number x2 The x-component of the second vertex.
---@return number y2 The y-component of the second vertex.
function EdgeShape:getPoints()
end

---Gets the vertex that establishes a connection to the previous shape.
---
---Setting next and previous EdgeShape vertices can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape:getPreviousVertex)
---
---@return number x The x-component of the vertex, or nil if EdgeShape:setPreviousVertex hasn't been called.
---@return number y The y-component of the vertex, or nil if EdgeShape:setPreviousVertex hasn't been called.
function EdgeShape:getPreviousVertex()
end

---Sets a vertex that establishes a connection to the next shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape:setNextVertex)
---
---@param x number The x-component of the vertex.
---@param y number The y-component of the vertex.
function EdgeShape:setNextVertex(x, y)
end

---Sets a vertex that establishes a connection to the previous shape.
---
---This can help prevent unwanted collisions when a flat shape slides along the edge and moves over to the new shape.
---
---[Open in Browser](https://love2d.org/wiki/EdgeShape:setPreviousVertex)
---
---@param x number The x-component of the vertex.
---@param y number The y-component of the vertex.
function EdgeShape:setPreviousVertex(x, y)
end

---A FrictionJoint applies friction to a body.
---
---[Open in Browser](https://love2d.org/wiki/FrictionJoint)
---
---@class love.physics.FrictionJoint: love.physics.Joint, love.Object
local FrictionJoint = {}
---@alias love.FrictionJoint love.physics.FrictionJoint

---Gets the maximum friction force in Newtons.
---
---[Open in Browser](https://love2d.org/wiki/FrictionJoint:getMaxForce)
---
---@return number force Maximum force in Newtons.
function FrictionJoint:getMaxForce()
end

---Gets the maximum friction torque in Newton-meters.
---
---[Open in Browser](https://love2d.org/wiki/FrictionJoint:getMaxTorque)
---
---@return number torque Maximum torque in Newton-meters.
function FrictionJoint:getMaxTorque()
end

---Sets the maximum friction force in Newtons.
---
---[Open in Browser](https://love2d.org/wiki/FrictionJoint:setMaxForce)
---
---@param maxForce number Max force in Newtons.
function FrictionJoint:setMaxForce(maxForce)
end

---Sets the maximum friction torque in Newton-meters.
---
---[Open in Browser](https://love2d.org/wiki/FrictionJoint:setMaxTorque)
---
---@param torque number Maximum torque in Newton-meters.
function FrictionJoint:setMaxTorque(torque)
end

---Keeps bodies together in such a way that they act like gears.
---
---[Open in Browser](https://love2d.org/wiki/GearJoint)
---
---@class love.physics.GearJoint: love.physics.Joint, love.Object
local GearJoint = {}
---@alias love.GearJoint love.physics.GearJoint

---Get the Joints connected by this GearJoint.
---
---[Open in Browser](https://love2d.org/wiki/GearJoint:getJoints)
---
---@return love.physics.Joint joint1 The first connected Joint.
---@return love.physics.Joint joint2 The second connected Joint.
function GearJoint:getJoints()
end

---Get the ratio of a gear joint.
---
---[Open in Browser](https://love2d.org/wiki/GearJoint:getRatio)
---
---@return number ratio The ratio of the joint.
function GearJoint:getRatio()
end

---Set the ratio of a gear joint.
---
---[Open in Browser](https://love2d.org/wiki/GearJoint:setRatio)
---
---@param ratio number The new ratio of the joint.
function GearJoint:setRatio(ratio)
end

---Attach multiple bodies together to interact in unique ways.
---
---[Open in Browser](https://love2d.org/wiki/Joint)
---
---@class love.physics.Joint: love.Object
local Joint = {}
---@alias love.Joint love.physics.Joint

---Explicitly destroys the Joint. An error will occur if you attempt to use the object after calling this function. If the World is in the middle of an update, the Joint is destroyed after the update finishes.
---
---[Open in Browser](https://love2d.org/wiki/Joint:destroy)
---
function Joint:destroy()
end

---Get the anchor points of the joint.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getAnchors)
---
---@return number x1 The x-component of the anchor on Body 1.
---@return number y1 The y-component of the anchor on Body 1.
---@return number x2 The x-component of the anchor on Body 2.
---@return number y2 The y-component of the anchor on Body 2.
function Joint:getAnchors()
end

---Gets the bodies that the Joint is attached to.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getBodies)
---
---@return love.physics.Body bodyA The first Body.
---@return love.physics.Body bodyB The second Body.
function Joint:getBodies()
end

---Gets whether the connected Bodies collide.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getCollideConnected)
---
---@return boolean c True if they collide, false otherwise.
function Joint:getCollideConnected()
end

---Returns the reaction force on the second body.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getReactionForce)
---
---@param invdt number The inverse of the time step (1/dt) the force applies over.
---@return number x The x-component of the force.
---@return number y The y-component of the force.
function Joint:getReactionForce(invdt)
end

---Returns the reaction torque on the second body.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getReactionTorque)
---
---@param invdt number The inverse of the time step (1/dt) the torque applies over.
---@return number torque The reaction torque on the second body.
function Joint:getReactionTorque(invdt)
end

---Gets a string representing the type.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getType)
---
---@return love.physics.JointType type A string with the name of the Joint type.
function Joint:getType()
end

---Returns the Lua value associated with this Joint.
---
---[Open in Browser](https://love2d.org/wiki/Joint:getUserData)
---
---@return any value The Lua value associated with the Joint.
function Joint:getUserData()
end

---Gets whether the Joint is destroyed. Destroyed joints cannot be used.
---
---[Open in Browser](https://love2d.org/wiki/Joint:isDestroyed)
---
---@return boolean destroyed Whether the Joint is destroyed.
function Joint:isDestroyed()
end

---Associates a Lua value with the Joint.
---
---To delete the reference, explicitly pass nil.
---
---[Open in Browser](https://love2d.org/wiki/Joint:setUserData)
---
---@param value any The Lua value to associate with the Joint.
function Joint:setUserData(value)
end

---Controls the relative motion between two Bodies. Position and rotation offsets can be specified, as well as the maximum motor force and torque that will be applied to reach the target offsets.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint)
---
---@class love.physics.MotorJoint: love.physics.Joint, love.Object
local MotorJoint = {}
---@alias love.MotorJoint love.physics.MotorJoint

---Gets the target angular offset between the two Bodies the Joint is attached to.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:getAngularOffset)
---
---@return number angleoffset The target angular offset in radians: the second body's angle minus the first body's angle.
function MotorJoint:getAngularOffset()
end

---Gets the position correction factor of the joint.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:getCorrectionFactor)
---
---@return number factor The position correction factor, in the range of [0, 1].
function MotorJoint:getCorrectionFactor()
end

---Gets the target linear offset between the two Bodies the Joint is attached to.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:getLinearOffset)
---
---@return number x The x component of the target linear offset, relative to the first Body.
---@return number y The y component of the target linear offset, relative to the first Body.
function MotorJoint:getLinearOffset()
end

---Gets the maximum force the joint applies to reach the target linear offset.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:getMaxForce)
---
---@return number force The maximum force.
function MotorJoint:getMaxForce()
end

---Gets the maximum torque the joint applies to reach the target angular offset.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:getMaxTorque)
---
---@return number torque The maximum torque.
function MotorJoint:getMaxTorque()
end

---Sets the target angluar offset between the two Bodies the Joint is attached to.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:setAngularOffset)
---
---@param angleoffset number The target angular offset in radians: the second body's angle minus the first body's angle.
function MotorJoint:setAngularOffset(angleoffset)
end

---Sets the position correction factor of the joint.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:setCorrectionFactor)
---
---@param factor number The position correction factor, in the range of [0, 1].
function MotorJoint:setCorrectionFactor(factor)
end

---Sets the target linear offset between the two Bodies the Joint is attached to.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:setLinearOffset)
---
---@param x number The x component of the target linear offset, relative to the first Body.
---@param y number The y component of the target linear offset, relative to the first Body.
function MotorJoint:setLinearOffset(x, y)
end

---Sets the maximum force the joint applies to reach the target linear offset.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:setMaxForce)
---
---@param force number The maximum force.
function MotorJoint:setMaxForce(force)
end

---Sets the maximum torque the joint applies to reach the target angular offset.
---
---[Open in Browser](https://love2d.org/wiki/MotorJoint:setMaxTorque)
---
---@param torque number The maximum torque.
function MotorJoint:setMaxTorque(torque)
end

---For controlling objects with the mouse.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint)
---
---@class love.physics.MouseJoint: love.physics.Joint, love.Object
local MouseJoint = {}
---@alias love.MouseJoint love.physics.MouseJoint

---Gets the damping of the joint.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:getDamping)
---
---@return number damping The damping of the joint, in newton-seconds per meter.
function MouseJoint:getDamping()
end

---Gets the highest allowed force.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:getMaxForce)
---
---@return number f The max allowed force.
function MouseJoint:getMaxForce()
end

---Gets the stiffness of the joint.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:getStiffness)
---
---@return number stiffness The stiffness of the joint, in newtons per meter.
function MouseJoint:getStiffness()
end

---Gets the target point.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:getTarget)
---
---@return number x The x-component of the target.
---@return number y The x-component of the target.
function MouseJoint:getTarget()
end

---Sets the damping of the joint. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:setDamping)
---
---@param damping number The damping of the joint, in newton-seconds per meter.
function MouseJoint:setDamping(damping)
end

---Sets the highest allowed force.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:setMaxForce)
---
---@param f number The max allowed force.
function MouseJoint:setMaxForce(f)
end

---Sets the stiffness of the joint. It must be a positive number. A new MouseJoint starts with the stiffness and damping of a 5 hertz spring with a damping ratio of 0.7. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:setStiffness)
---
---@param stiffness number The stiffness of the joint, in newtons per meter.
function MouseJoint:setStiffness(stiffness)
end

---Sets the target point.
---
---[Open in Browser](https://love2d.org/wiki/MouseJoint:setTarget)
---
---@param x number The x-component of the target.
---@param y number The y-component of the target.
function MouseJoint:setTarget(x, y)
end

---A PolygonShape is a convex polygon with up to 8 vertices.
---
---[Open in Browser](https://love2d.org/wiki/PolygonShape)
---
---@class love.physics.PolygonShape: love.physics.Shape, love.Object
local PolygonShape = {}
---@alias love.PolygonShape love.physics.PolygonShape

---Get the local coordinates of the polygon's vertices.
---
---This function has a variable number of return values. It can be used in a nested fashion with love.graphics.polygon.
---
---[Open in Browser](https://love2d.org/wiki/PolygonShape:getPoints)
---
---@return number x1 The x-component of the first vertex.
---@return number y1 The y-component of the first vertex.
---@return number x2 The x-component of the second vertex.
---@return number y2 The y-component of the second vertex.
---@return number ... Additional x and y components of the remaining vertices.
function PolygonShape:getPoints()
end

---Checks whether the polygon is convex. This is a slow operation.
---
---[Open in Browser](https://love2d.org/wiki/PolygonShape:validate)
---
---@return boolean valid Whether the polygon is convex.
function PolygonShape:validate()
end

---Restricts relative motion between Bodies to one shared axis.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint)
---
---@class love.physics.PrismaticJoint: love.physics.Joint, love.Object
local PrismaticJoint = {}
---@alias love.PrismaticJoint love.physics.PrismaticJoint

---Checks whether the limits are enabled.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:areLimitsEnabled)
---
---@return boolean enabled True if enabled, false otherwise.
function PrismaticJoint:areLimitsEnabled()
end

---Gets the world-space axis vector of the Prismatic Joint.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getAxis)
---
---@return number x The x-axis coordinate of the world-space axis vector.
---@return number y The y-axis coordinate of the world-space axis vector.
function PrismaticJoint:getAxis()
end

---Get the current joint angle speed.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getJointSpeed)
---
---@return number s Joint angle speed in meters/second.
function PrismaticJoint:getJointSpeed()
end

---Get the current joint translation.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getJointTranslation)
---
---@return number t Joint translation, usually in meters..
function PrismaticJoint:getJointTranslation()
end

---Gets the joint limits.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getLimits)
---
---@return number lower The lower limit, usually in meters.
---@return number upper The upper limit, usually in meters.
function PrismaticJoint:getLimits()
end

---Gets the lower limit.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getLowerLimit)
---
---@return number lower The lower limit, usually in meters.
function PrismaticJoint:getLowerLimit()
end

---Gets the maximum motor force.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getMaxMotorForce)
---
---@return number f The maximum motor force, usually in N.
function PrismaticJoint:getMaxMotorForce()
end

---Returns the current motor force.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getMotorForce)
---
---@param invdt number How long the force applies. Usually the inverse time step or 1/dt.
---@return number force The force on the motor in newtons.
function PrismaticJoint:getMotorForce(invdt)
end

---Gets the motor speed.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getMotorSpeed)
---
---@return number s The motor speed, usually in meters per second.
function PrismaticJoint:getMotorSpeed()
end

---Gets the reference angle.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getReferenceAngle)
---
---@return number angle The reference angle in radians.
function PrismaticJoint:getReferenceAngle()
end

---Gets the upper limit.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:getUpperLimit)
---
---@return number upper The upper limit, usually in meters.
function PrismaticJoint:getUpperLimit()
end

---Checks whether the motor is enabled.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:isMotorEnabled)
---
---@return boolean enabled True if enabled, false if disabled.
function PrismaticJoint:isMotorEnabled()
end

---Sets the limits.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setLimits)
---
---@param lower number The lower limit, usually in meters.
---@param upper number The upper limit, usually in meters.
function PrismaticJoint:setLimits(lower, upper)
end

---Enables/disables the joint limit.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setLimitsEnabled)
---
---@param enable boolean True to enable, false to disable.
function PrismaticJoint:setLimitsEnabled(enable)
end

---Sets the lower limit.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setLowerLimit)
---
---@param lower number The lower limit, usually in meters.
function PrismaticJoint:setLowerLimit(lower)
end

---Set the maximum motor force.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setMaxMotorForce)
---
---@param f number The maximum motor force, usually in N.
function PrismaticJoint:setMaxMotorForce(f)
end

---Enables/disables the joint motor.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setMotorEnabled)
---
---@param enable boolean True to enable, false to disable.
function PrismaticJoint:setMotorEnabled(enable)
end

---Sets the motor speed.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setMotorSpeed)
---
---@param s number The motor speed, usually in meters per second.
function PrismaticJoint:setMotorSpeed(s)
end

---Sets the upper limit.
---
---[Open in Browser](https://love2d.org/wiki/PrismaticJoint:setUpperLimit)
---
---@param upper number The upper limit, usually in meters.
function PrismaticJoint:setUpperLimit(upper)
end

---Allows you to simulate bodies connected through pulleys.
---
---[Open in Browser](https://love2d.org/wiki/PulleyJoint)
---
---@class love.physics.PulleyJoint: love.physics.Joint, love.Object
local PulleyJoint = {}
---@alias love.PulleyJoint love.physics.PulleyJoint

---Get the ground anchor positions in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/PulleyJoint:getGroundAnchors)
---
---@return number a1x The x coordinate of the first anchor.
---@return number a1y The y coordinate of the first anchor.
---@return number a2x The x coordinate of the second anchor.
---@return number a2y The y coordinate of the second anchor.
function PulleyJoint:getGroundAnchors()
end

---Get the current length of the rope segment attached to the first body.
---
---[Open in Browser](https://love2d.org/wiki/PulleyJoint:getLengthA)
---
---@return number length The length of the rope segment.
function PulleyJoint:getLengthA()
end

---Get the current length of the rope segment attached to the second body.
---
---[Open in Browser](https://love2d.org/wiki/PulleyJoint:getLengthB)
---
---@return number length The length of the rope segment.
function PulleyJoint:getLengthB()
end

---Get the pulley ratio.
---
---[Open in Browser](https://love2d.org/wiki/PulleyJoint:getRatio)
---
---@return number ratio The pulley ratio of the joint.
function PulleyJoint:getRatio()
end

---Allow two Bodies to revolve around a shared point.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint)
---
---@class love.physics.RevoluteJoint: love.physics.Joint, love.Object
local RevoluteJoint = {}
---@alias love.RevoluteJoint love.physics.RevoluteJoint

---Checks whether limits are enabled.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:areLimitsEnabled)
---
---@return boolean enabled True if enabled, false otherwise.
function RevoluteJoint:areLimitsEnabled()
end

---Get the current joint angle.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getJointAngle)
---
---@return number angle The joint angle in radians.
function RevoluteJoint:getJointAngle()
end

---Get the current joint angle speed.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getJointSpeed)
---
---@return number s Joint angle speed in radians/second.
function RevoluteJoint:getJointSpeed()
end

---Gets the joint limits.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getLimits)
---
---@return number lower The lower limit, in radians.
---@return number upper The upper limit, in radians.
function RevoluteJoint:getLimits()
end

---Gets the lower limit.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getLowerLimit)
---
---@return number lower The lower limit, in radians.
function RevoluteJoint:getLowerLimit()
end

---Gets the maximum motor torque.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getMaxMotorTorque)
---
---@return number f The maximum motor force, in Nm.
function RevoluteJoint:getMaxMotorTorque()
end

---Gets the motor speed.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getMotorSpeed)
---
---@return number s The motor speed, radians per second.
function RevoluteJoint:getMotorSpeed()
end

---Get the current motor torque.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getMotorTorque)
---
---@param dt number The time step the torque applies over, usually the dt passed to love.update.
---@return number torque The current motor torque.
function RevoluteJoint:getMotorTorque(dt)
end

---Gets the reference angle.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getReferenceAngle)
---
---@return number angle The reference angle in radians.
function RevoluteJoint:getReferenceAngle()
end

---Gets the upper limit.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:getUpperLimit)
---
---@return number upper The upper limit, in radians.
function RevoluteJoint:getUpperLimit()
end

---Checks whether the motor is enabled.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:isMotorEnabled)
---
---@return boolean enabled True if enabled, false if disabled.
function RevoluteJoint:isMotorEnabled()
end

---Sets the limits.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setLimits)
---
---@param lower number The lower limit, in radians.
---@param upper number The upper limit, in radians.
function RevoluteJoint:setLimits(lower, upper)
end

---Enables/disables the joint limit.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setLimitsEnabled)
---
---@param enable boolean True to enable, false to disable.
function RevoluteJoint:setLimitsEnabled(enable)
end

---Sets the lower limit.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setLowerLimit)
---
---@param lower number The lower limit, in radians.
function RevoluteJoint:setLowerLimit(lower)
end

---Set the maximum motor torque.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setMaxMotorTorque)
---
---@param f number The maximum motor force, in Nm.
function RevoluteJoint:setMaxMotorTorque(f)
end

---Enables/disables the joint motor.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setMotorEnabled)
---
---@param enable boolean True to enable, false to disable.
function RevoluteJoint:setMotorEnabled(enable)
end

---Sets the motor speed.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setMotorSpeed)
---
---@param s number The motor speed, radians per second.
function RevoluteJoint:setMotorSpeed(s)
end

---Sets the upper limit.
---
---[Open in Browser](https://love2d.org/wiki/RevoluteJoint:setUpperLimit)
---
---@param upper number The upper limit, in radians.
function RevoluteJoint:setUpperLimit(upper)
end

---The RopeJoint enforces a maximum distance between two points on two bodies. It has no other effect.
---
---[Open in Browser](https://love2d.org/wiki/RopeJoint)
---
---@class love.physics.RopeJoint: love.physics.Joint, love.Object
local RopeJoint = {}
---@alias love.RopeJoint love.physics.RopeJoint

---Gets the maximum length of a RopeJoint.
---
---[Open in Browser](https://love2d.org/wiki/RopeJoint:getMaxLength)
---
---@return number maxLength The maximum length of the RopeJoint.
function RopeJoint:getMaxLength()
end

---Sets the maximum length of a RopeJoint.
---
---[Open in Browser](https://love2d.org/wiki/RopeJoint:setMaxLength)
---
---@param maxLength number The new maximum length of the RopeJoint.
function RopeJoint:setMaxLength(maxLength)
end

---Shapes are solid 2d geometrical objects which handle the mass and collision of a Body in love.physics.
---
---A Shape created with a Body is attached to that Body and takes part in the simulation. Its density, friction, restitution, sensor state and collision filter data are set on the Shape itself.
---
---The Shape's position is relative to the position of the Body it has been attached to.
---
---[Open in Browser](https://love2d.org/wiki/Shape)
---
---@class love.physics.Shape: love.Object
local Shape = {}
---@alias love.Shape love.physics.Shape

---Returns the points of the bounding box for the transformed shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:computeAABB)
---
---@param tx number The translation of the shape on the x-axis.
---@param ty number The translation of the shape on the y-axis.
---@param tr number The shape rotation.
---@param childIndex (number)? The index of the child to compute the bounding box of.
---@return number topLeftX The x position of the top-left point.
---@return number topLeftY The y position of the top-left point.
---@return number bottomRightX The x position of the bottom-right point.
---@return number bottomRightY The y position of the bottom-right point.
function Shape:computeAABB(tx, ty, tr, childIndex)
end

---Computes the mass properties for the shape with the specified density.
---
---[Open in Browser](https://love2d.org/wiki/Shape:computeMass)
---
---@param density number The shape density.
---@return number x The x postition of the center of mass.
---@return number y The y postition of the center of mass.
---@return number mass The mass of the shape.
---@return number inertia The rotational inertia.
function Shape:computeMass(density)
end

---Destroys the Shape and removes it from its Body. If the World is in the middle of an update, the Shape is destroyed after the update finishes.
---
---[Open in Browser](https://love2d.org/wiki/Shape:destroy)
---
function Shape:destroy()
end

---Returns the Body the Shape is attached to.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getBody)
---
---@return love.physics.Body body The Body the Shape is attached to, or nothing if it is not attached to one.
function Shape:getBody()
end

---Returns the points of the Shape's bounding box in world coordinates, as computed by the physics World. A ChainShape has one child per edge; a 1-based child index selects which one.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getBoundingBox)
---
---@param index (number)? The index of the child to get the bounding box of.
---@return number topLeftX The x position of the top-left point.
---@return number topLeftY The y position of the top-left point.
---@return number bottomRightX The x position of the bottom-right point.
---@return number bottomRightY The y position of the bottom-right point.
function Shape:getBoundingBox(index)
end

---Returns the categories the Shape belongs to.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getCategory)
---
---@return number ... The categories.
function Shape:getCategory()
end

---Returns the number of children the shape has.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getChildCount)
---
---@return number count The number of children.
function Shape:getChildCount()
end

---Returns the density of the shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getDensity)
---
---@return number density The Shape density in kilograms per square meter.
function Shape:getDensity()
end

---Returns the filter data of the shape.
---
---Categories and masks are encoded as the bits of a 16-bit integer.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getFilterData)
---
---@return number categories The categories as an integer from 0 to 65535.
---@return number mask The mask as an integer from 0 to 65535.
---@return number group The group as an integer from -32768 to 32767.
function Shape:getFilterData()
end

---Returns the friction of the shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getFriction)
---
---@return number friction The shape friction.
function Shape:getFriction()
end

---Returns the group the shape belongs to. Shapes with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.
---
---The groups range from -32768 to 32767.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getGroupIndex)
---
---@return number group The group of the shape.
function Shape:getGroupIndex()
end

---Returns which categories this shape should '''NOT''' collide with.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getMask)
---
---@return number ... The masks.
function Shape:getMask()
end

---Returns the mass, its center and the rotational inertia of the Shape, computed from its density.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getMassData)
---
---@return number x The x position of the center of mass.
---@return number y The y position of the center of mass.
---@return number mass The mass of the shape.
---@return number inertia The rotational inertia.
function Shape:getMassData()
end

---Gets the radius of the shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getRadius)
---
---@return number radius The radius of the shape.
function Shape:getRadius()
end

---Returns the restitution of the shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getRestitution)
---
---@return number restitution The shape restitution.
function Shape:getRestitution()
end

---Gets a string representing the Shape.
---
---This function can be useful for conditional debug drawing.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getType)
---
---@return love.physics.ShapeType type The type of the Shape.
function Shape:getType()
end

---Returns the Lua value associated with this shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:getUserData)
---
---@return any value The Lua value associated with the shape.
function Shape:getUserData()
end

---Gets whether the Shape is destroyed or not attached to a Body. Such Shapes cannot use the methods that need a Body.
---
---[Open in Browser](https://love2d.org/wiki/Shape:isDestroyed)
---
---@return boolean destroyed Whether the Shape is destroyed or not attached to a Body.
function Shape:isDestroyed()
end

---Returns whether the shape is a sensor.
---
---[Open in Browser](https://love2d.org/wiki/Shape:isSensor)
---
---@return boolean sensor If the shape is a sensor.
function Shape:isSensor()
end

---Casts a ray against the Shape and returns the surface normal vector and the line position where the ray hit. If the ray missed the Shape, nothing is returned. The Shape is placed using the transform of the Body it is attached to, or using the given transform.
---
---The ray starts on the first point of the input line and goes towards the second point of the line. The fifth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.
---
---The childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.
---
---The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.
---
---hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
---
---Uses the transform of the Body the Shape is attached to.
---
---[Open in Browser](https://love2d.org/wiki/Shape:rayCast)
---
---@param x1 number The x position of the input line starting point.
---@param y1 number The y position of the input line starting point.
---@param x2 number The x position of the input line end point.
---@param y2 number The y position of the input line end point.
---@param maxFraction number Ray length parameter.
---@param childIndex (number)? The index of the child the ray gets cast against.
---@return number xn The x component of the normal vector of the edge where the ray hit the shape.
---@return number yn The y component of the normal vector of the edge where the ray hit the shape.
---@return number fraction The position on the input line where the intersection happened as a factor of the line length.
function Shape:rayCast(x1, y1, x2, y2, maxFraction, childIndex)
end

---Casts a ray against the Shape and returns the surface normal vector and the line position where the ray hit. If the ray missed the Shape, nothing is returned. The Shape is placed using the transform of the Body it is attached to, or using the given transform.
---
---The ray starts on the first point of the input line and goes towards the second point of the line. The fifth argument is the maximum distance the ray is going to travel as a scale factor of the input line length.
---
---The childIndex parameter is used to specify which child of a parent shape, such as a ChainShape, will be ray casted. For ChainShapes, the index of 1 is the first edge on the chain. Ray casting a parent shape will only test the child specified so if you want to test every shape of the parent, you must loop through all of its children.
---
---The world position of the impact can be calculated by multiplying the line vector with the third return value and adding it to the line starting point.
---
---hitx, hity = x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
---
---Uses the given transform instead of a Body's.
---
---[Open in Browser](https://love2d.org/wiki/Shape:rayCast)
---
---@param x1 number The x position of the input line starting point.
---@param y1 number The y position of the input line starting point.
---@param x2 number The x position of the input line end point.
---@param y2 number The y position of the input line end point.
---@param maxFraction number Ray length parameter.
---@param tx number The translation of the shape on the x-axis.
---@param ty number The translation of the shape on the y-axis.
---@param tr number The shape rotation.
---@param childIndex (number)? The index of the child the ray gets cast against.
---@return number xn The x component of the normal vector of the edge where the ray hit the shape.
---@return number yn The y component of the normal vector of the edge where the ray hit the shape.
---@return number fraction The position on the input line where the intersection happened as a factor of the line length.
function Shape:rayCast(x1, y1, x2, y2, maxFraction, tx, ty, tr, childIndex)
end

---Sets the categories the Shape belongs to. There can be up to 16 categories represented as a number from 1 to 16.
---
---A Shape's default category is 1.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setCategory)
---
---@param ... number The categories, each a number from 1 to 16.
function Shape:setCategory(...)
end

---Sets the categories the Shape belongs to. There can be up to 16 categories represented as a number from 1 to 16.
---
---A Shape's default category is 1.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setCategory)
---
---@param categories (number)[] A sequence of categories, each a number from 1 to 16.
function Shape:setCategory(categories)
end

---Sets the density of the Shape. The mass of the Body is recalculated afterwards, unless the Body has custom mass data (see Body:hasCustomMassData).
---
---[Open in Browser](https://love2d.org/wiki/Shape:setDensity)
---
---@param density number The Shape density in kilograms per square meter.
function Shape:setDensity(density)
end

---Sets the filter data of the shape.
---
---Groups, categories, and mask can be used to define the collision behaviour of the shape.
---
---If two shapes are in the same group they either always collide if the group is positive, or never collide if it's negative. If the group is zero or they do not match, then the contact filter checks if the shapes select a category of the other shape with their masks. The shapes do not collide if that's not the case. If they do have each other's categories selected, the return value of the custom contact filter will be used. They always collide if none was set.
---
---There can be up to 16 categories. Categories and masks are encoded as the bits of a 16-bit integer.
---
---When created, prior to calling this function, all shapes have category set to 1, mask set to 65535 (all categories) and group set to 0.
---
---This function allows setting all filter data for a shape at once. To set only the categories, the mask or the group, you can use Shape:setCategory, Shape:setMask or Shape:setGroupIndex respectively.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setFilterData)
---
---@param categories number The categories as an integer from 0 to 65535.
---@param mask number The mask as an integer from 0 to 65535.
---@param group number The group as an integer from -32768 to 32767.
function Shape:setFilterData(categories, mask, group)
end

---Sets the friction of the shape.
---
---Friction determines how shapes react when they 'slide' along other shapes. Low friction indicates a slippery surface, like ice, while high friction indicates a rough surface, like concrete. Range: 0.0 - 1.0.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setFriction)
---
---@param friction number The shape friction.
function Shape:setFriction(friction)
end

---Sets the group the shape belongs to. Shapes with the same group will always collide if the group is positive or never collide if it's negative. The group zero means no group.
---
---The groups range from -32768 to 32767.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setGroupIndex)
---
---@param group number The group as an integer from -32768 to 32767.
function Shape:setGroupIndex(group)
end

---Sets the category mask of the Shape. There can be up to 16 categories represented as a number from 1 to 16.
---
---This Shape will '''NOT''' collide with the Shapes that are in the selected categories if the other Shape also has a category of this Shape selected.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setMask)
---
---@param ... number The masks, each a number from 1 to 16.
function Shape:setMask(...)
end

---Sets the category mask of the Shape. There can be up to 16 categories represented as a number from 1 to 16.
---
---This Shape will '''NOT''' collide with the Shapes that are in the selected categories if the other Shape also has a category of this Shape selected.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setMask)
---
---@param masks (number)[] A sequence of masks, each a number from 1 to 16.
function Shape:setMask(masks)
end

---Sets the restitution of the shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setRestitution)
---
---@param restitution number The shape restitution.
function Shape:setRestitution(restitution)
end

---Sets whether the Shape should act as a sensor.
---
---Sensors do not cause collision responses, but the begin-contact and end-contact World callbacks will still be called for this Shape.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setSensor)
---
---@param sensor boolean The sensor status.
function Shape:setSensor(sensor)
end

---Associates a Lua value with the shape.
---
---To delete the reference, explicitly pass nil.
---
---[Open in Browser](https://love2d.org/wiki/Shape:setUserData)
---
---@param value any The Lua value to associate with the shape.
function Shape:setUserData(value)
end

---Checks whether a point is inside the Shape. This is particularly useful for mouse interaction with the shapes. By looping through all shapes and testing the mouse position with this function, we can find which shapes the mouse touches.
---
---Uses the transform of the Body the Shape is attached to. The point is in world coordinates.
---
---[Open in Browser](https://love2d.org/wiki/Shape:testPoint)
---
---@param x number The x position of the point.
---@param y number The y position of the point.
---@return boolean isInside True if the point is inside or false if it is outside.
function Shape:testPoint(x, y)
end

---Checks whether a point is inside the Shape. This is particularly useful for mouse interaction with the shapes. By looping through all shapes and testing the mouse position with this function, we can find which shapes the mouse touches.
---
---Uses the given transform instead of a Body's.
---
---[Open in Browser](https://love2d.org/wiki/Shape:testPoint)
---
---@param tx number Translates the shape along the x-axis.
---@param ty number Translates the shape along the y-axis.
---@param tr number Rotates the shape.
---@param x number The x-component of the point.
---@param y number The y-component of the point.
---@return boolean hit True if inside, false if outside
function Shape:testPoint(tx, ty, tr, x, y)
end

---A WeldJoint essentially glues two bodies together.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint)
---
---@class love.physics.WeldJoint: love.physics.Joint, love.Object
local WeldJoint = {}
---@alias love.WeldJoint love.physics.WeldJoint

---Gets the damping of the joint.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint:getDamping)
---
---@return number damping The rotational damping of the joint, in newton-meter-seconds.
function WeldJoint:getDamping()
end

---Gets the reference angle.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint:getReferenceAngle)
---
---@return number angle The reference angle in radians.
function WeldJoint:getReferenceAngle()
end

---Gets the stiffness of the joint.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint:getStiffness)
---
---@return number stiffness The rotational stiffness of the joint, in newton-meters. 0 makes the joint rigid.
function WeldJoint:getStiffness()
end

---Sets the damping of the joint. love.physics.computeAngularStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint:setDamping)
---
---@param damping number The rotational damping of the joint, in newton-meter-seconds.
function WeldJoint:setDamping(damping)
end

---Sets the stiffness of the joint. love.physics.computeAngularStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/WeldJoint:setStiffness)
---
---@param stiffness number The rotational stiffness of the joint, in newton-meters. 0 makes the joint rigid.
function WeldJoint:setStiffness(stiffness)
end

---Restricts a point on the second body to a line on the first body.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint)
---
---@class love.physics.WheelJoint: love.physics.Joint, love.Object
local WheelJoint = {}
---@alias love.WheelJoint love.physics.WheelJoint

---Gets the world-space axis vector of the Wheel Joint.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getAxis)
---
---@return number x The x-axis coordinate of the world-space axis vector.
---@return number y The y-axis coordinate of the world-space axis vector.
function WheelJoint:getAxis()
end

---Gets the damping of the joint's spring. Same as WheelJoint:getSpringDamping.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getDamping)
---
---@return number damping The damping of the joint's spring, in newton-seconds per meter.
function WheelJoint:getDamping()
end

---Returns the current joint translation speed.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getJointSpeed)
---
---@return number speed The translation speed of the joint in meters per second.
function WheelJoint:getJointSpeed()
end

---Returns the current joint translation.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getJointTranslation)
---
---@return number position The translation of the joint in meters.
function WheelJoint:getJointTranslation()
end

---Returns the maximum motor torque.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getMaxMotorTorque)
---
---@return number maxTorque The maximum torque of the joint motor in newton meters.
function WheelJoint:getMaxMotorTorque()
end

---Returns the speed of the motor.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getMotorSpeed)
---
---@return number speed The speed of the joint motor in radians per second.
function WheelJoint:getMotorSpeed()
end

---Returns the current torque on the motor.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getMotorTorque)
---
---@param dt number The time step the torque applies over, usually the dt passed to love.update.
---@return number torque The torque on the motor in newton meters.
function WheelJoint:getMotorTorque(dt)
end

---Gets the damping of the joint's spring.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getSpringDamping)
---
---@return number damping The damping of the joint's spring, in newton-seconds per meter.
function WheelJoint:getSpringDamping()
end

---Gets the stiffness of the joint's spring.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getSpringStiffness)
---
---@return number stiffness The stiffness of the joint's spring, in newtons per meter.
function WheelJoint:getSpringStiffness()
end

---Gets the stiffness of the joint's spring. Same as WheelJoint:getSpringStiffness.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:getStiffness)
---
---@return number stiffness The stiffness of the joint's spring, in newtons per meter.
function WheelJoint:getStiffness()
end

---Checks if the joint motor is running.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:isMotorEnabled)
---
---@return boolean on The status of the joint motor.
function WheelJoint:isMotorEnabled()
end

---Sets the damping of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping. Same as WheelJoint:setSpringDamping.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setDamping)
---
---@param damping number The damping of the joint's spring, in newton-seconds per meter.
function WheelJoint:setDamping(damping)
end

---Sets a new maximum motor torque.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setMaxMotorTorque)
---
---@param maxTorque number The new maximum torque for the joint motor in newton meters.
function WheelJoint:setMaxMotorTorque(maxTorque)
end

---Starts and stops the joint motor.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setMotorEnabled)
---
---@param enable boolean True turns the motor on and false turns it off.
function WheelJoint:setMotorEnabled(enable)
end

---Sets a new speed for the motor.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setMotorSpeed)
---
---@param speed number The new speed for the joint motor in radians per second.
function WheelJoint:setMotorSpeed(speed)
end

---Sets the damping of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setSpringDamping)
---
---@param damping number The damping of the joint's spring, in newton-seconds per meter.
function WheelJoint:setSpringDamping(damping)
end

---Sets the stiffness of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setSpringStiffness)
---
---@param stiffness number The stiffness of the joint's spring, in newtons per meter.
function WheelJoint:setSpringStiffness(stiffness)
end

---Sets the stiffness of the joint's spring. love.physics.computeLinearStiffness converts a frequency and damping ratio to a stiffness and damping. Same as WheelJoint:setSpringStiffness.
---
---[Open in Browser](https://love2d.org/wiki/WheelJoint:setStiffness)
---
---@param stiffness number The stiffness of the joint's spring, in newtons per meter.
function WheelJoint:setStiffness(stiffness)
end

---A world is an object that contains all bodies and joints.
---
---[Open in Browser](https://love2d.org/wiki/World)
---
---@class love.physics.World: love.Object
local World = {}
---@alias love.World love.physics.World

---Destroys the world, taking all bodies, joints and shapes with it. 
---
---An error will occur if you attempt to use any of the destroyed objects after calling this function.
---
---[Open in Browser](https://love2d.org/wiki/World:destroy)
---
function World:destroy()
end

---Returns a table with all bodies.
---
---[Open in Browser](https://love2d.org/wiki/World:getBodies)
---
---@return (love.physics.Body)[] bodies A sequence with all bodies.
function World:getBodies()
end

---Returns the number of bodies in the world.
---
---[Open in Browser](https://love2d.org/wiki/World:getBodyCount)
---
---@return number n The number of bodies in the world.
function World:getBodyCount()
end

---Returns functions for the callbacks during the world update.
---
---[Open in Browser](https://love2d.org/wiki/World:getCallbacks)
---
---@return fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact) beginContact Gets called when two Shapes begin to overlap. Nil if it is not set.
---@return fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact) endContact Gets called when two Shapes cease to overlap. This will also be called outside of a world update, when colliding objects are destroyed. Nil if it is not set.
---@return fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact) preSolve Gets called before a collision gets resolved. Nil if it is not set.
---@return fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact, normalImpulse: number, tangentImpulse: number, ...: number) postSolve Gets called after the collision has been resolved. It also gets the normal and tangent impulse of each contact point. Nil if it is not set.
function World:getCallbacks()
end

---Returns the number of contacts in the world.
---
---[Open in Browser](https://love2d.org/wiki/World:getContactCount)
---
---@return number n The number of contacts in the world.
function World:getContactCount()
end

---Returns the function for collision filtering.
---
---[Open in Browser](https://love2d.org/wiki/World:getContactFilter)
---
---@return fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape):(boolean) contactFilter The function that handles the contact filtering, or nil if none is set.
function World:getContactFilter()
end

---Returns a table with all Contacts.
---
---[Open in Browser](https://love2d.org/wiki/World:getContacts)
---
---@return (love.physics.Contact)[] contacts A sequence with all Contacts.
function World:getContacts()
end

---Get the gravity of the world.
---
---[Open in Browser](https://love2d.org/wiki/World:getGravity)
---
---@return number x The x component of gravity.
---@return number y The y component of gravity.
function World:getGravity()
end

---Returns the number of joints in the world.
---
---[Open in Browser](https://love2d.org/wiki/World:getJointCount)
---
---@return number n The number of joints in the world.
function World:getJointCount()
end

---Returns a table with all joints.
---
---[Open in Browser](https://love2d.org/wiki/World:getJoints)
---
---@return (love.physics.Joint)[] joints A sequence with all joints.
function World:getJoints()
end

---Returns all Shapes inside the specified area, found by searching for any overlapping bounding box (Shape:getBoundingBox).
---
---[Open in Browser](https://love2d.org/wiki/World:getShapesInArea)
---
---@param topLeftX number The x position of the top-left point.
---@param topLeftY number The y position of the top-left point.
---@param bottomRightX number The x position of the bottom-right point.
---@param bottomRightY number The y position of the bottom-right point.
---@param categoryMask (number)? Only Shapes whose category bits (see Shape:getFilterData) share a bit with this 16-bit mask are included. The default includes every Shape.
---@return (love.physics.Shape)[] shapes A sequence of the Shapes whose bounding boxes overlap the area.
function World:getShapesInArea(topLeftX, topLeftY, bottomRightX, bottomRightY, categoryMask)
end

---Gets whether the World is destroyed. Destroyed worlds cannot be used.
---
---[Open in Browser](https://love2d.org/wiki/World:isDestroyed)
---
---@return boolean destroyed Whether the World is destroyed.
function World:isDestroyed()
end

---Returns if the world is updating its state.
---
---This will return true inside the callbacks from World:setCallbacks.
---
---[Open in Browser](https://love2d.org/wiki/World:isLocked)
---
---@return boolean locked Will be true if the world is in the process of updating its state.
function World:isLocked()
end

---Gets the sleep behaviour of the world.
---
---[Open in Browser](https://love2d.org/wiki/World:isSleepingAllowed)
---
---@return boolean allow True if bodies in the world are allowed to sleep, or false if not.
function World:isSleepingAllowed()
end

---Deprecated: use World:queryShapesInArea, which this calls. Calls a function for each Shape inside the specified area by searching for any overlapping bounding box (Shape:getBoundingBox).
---
---[Open in Browser](https://love2d.org/wiki/World:queryBoundingBox)
---
---@param topLeftX number The x position of the top-left point.
---@param topLeftY number The y position of the top-left point.
---@param bottomRightX number The x position of the bottom-right point.
---@param bottomRightY number The y position of the bottom-right point.
---@param callback fun(shape: love.physics.Shape, ...: any):(boolean) This function gets passed the Shape and any extra values, and should return a boolean. The search will continue if it is true or stop if it is false.
---@param ... any Extra values passed to the callback after the Shape.
function World:queryBoundingBox(topLeftX, topLeftY, bottomRightX, bottomRightY, callback, ...)
end

---Calls a function for each Shape inside the specified area by searching for any overlapping bounding box (Shape:getBoundingBox).
---
---[Open in Browser](https://love2d.org/wiki/World:queryShapesInArea)
---
---@param topLeftX number The x position of the top-left point.
---@param topLeftY number The y position of the top-left point.
---@param bottomRightX number The x position of the bottom-right point.
---@param bottomRightY number The y position of the bottom-right point.
---@param callback fun(shape: love.physics.Shape, ...: any):(boolean) This function gets passed the Shape and any extra values, and should return a boolean. The search will continue if it is true or stop if it is false.
---@param ... any Extra values passed to the callback after the Shape.
function World:queryShapesInArea(topLeftX, topLeftY, bottomRightX, bottomRightY, callback, ...)
end

---Casts a ray and calls a function for each Shape it intersects.
---
---[Open in Browser](https://love2d.org/wiki/World:rayCast)
---
---@param x1 number The x position of the starting point of the ray.
---@param y1 number The y position of the starting point of the ray.
---@param x2 number The x position of the end point of the ray.
---@param y2 number The y position of the end point of the ray.
---@param callback fun(shape: love.physics.Shape, x: number, y: number, xn: number, yn: number, fraction: number, ...: any):(number) A function called for each Shape intersected by the ray, with the Shape, the hit point, the surface normal, the fraction along the ray and any extra values. It should return a number as a control value: -1 ignores this Shape and continues, 0 stops the ray cast, a fraction clips the ray to that point, and 1 continues without clipping. The intersection points fed into the function will be in an arbitrary order. If you wish to find the closest point of intersection, you'll need to do that yourself within the function. The easiest way to do that is by using the fraction value.
---@param ... any Extra values passed to the callback after its own arguments.
function World:rayCast(x1, y1, x2, y2, callback, ...)
end

---Casts a ray and returns the first Shape it finds to intersect, which is not necessarily the closest one.
---
---[Open in Browser](https://love2d.org/wiki/World:rayCastAny)
---
---@param x1 number The x position of the starting point of the ray.
---@param y1 number The y position of the starting point of the ray.
---@param x2 number The x position of the end point of the ray.
---@param y2 number The y position of the end point of the ray.
---@param categoryMask (number)? Only Shapes whose category bits (see Shape:getFilterData) share a bit with this 16-bit mask are included. The default includes every Shape.
---@return love.physics.Shape shape The Shape the ray hit, or nothing if it hit none.
---@return number x The x position of the hit point.
---@return number y The y position of the hit point.
---@return number xn The x component of the surface normal at the hit point.
---@return number yn The y component of the surface normal at the hit point.
---@return number fraction The position of the hit point on the ray, as a fraction of the distance from the start point to the end point.
function World:rayCastAny(x1, y1, x2, y2, categoryMask)
end

---Casts a ray and returns the Shape closest to the start point that it intersects.
---
---[Open in Browser](https://love2d.org/wiki/World:rayCastClosest)
---
---@param x1 number The x position of the starting point of the ray.
---@param y1 number The y position of the starting point of the ray.
---@param x2 number The x position of the end point of the ray.
---@param y2 number The y position of the end point of the ray.
---@param categoryMask (number)? Only Shapes whose category bits (see Shape:getFilterData) share a bit with this 16-bit mask are included. The default includes every Shape.
---@return love.physics.Shape shape The Shape the ray hit, or nothing if it hit none.
---@return number x The x position of the hit point.
---@return number y The y position of the hit point.
---@return number xn The x component of the surface normal at the hit point.
---@return number yn The y component of the surface normal at the hit point.
---@return number fraction The position of the hit point on the ray, as a fraction of the distance from the start point to the end point.
function World:rayCastClosest(x1, y1, x2, y2, categoryMask)
end

---Sets functions for the collision callbacks during the world update.
---
---Four Lua functions can be given as arguments. The value nil removes a function; every callback that is not given is removed.
---
---When called, each function will be passed three arguments. The first two arguments are the colliding Shapes and the third argument is the Contact between them. The postSolve callback additionally gets the normal and tangent impulse for each contact point.
---
---If you are interested to know when exactly each callback is called, consult a Box2d manual
---
---[Open in Browser](https://love2d.org/wiki/World:setCallbacks)
---
---@param beginContact (fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact))? Gets called when two Shapes begin to overlap.
---@param endContact (fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact))? Gets called when two Shapes cease to overlap. This will also be called outside of a world update, when colliding objects are destroyed.
---@param preSolve (fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact))? Gets called before a collision gets resolved.
---@param postSolve (fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape, contact: love.physics.Contact, normalImpulse: number, tangentImpulse: number, ...: number))? Gets called after the collision has been resolved. It also gets the normal and tangent impulse of each contact point.
function World:setCallbacks(beginContact, endContact, preSolve, postSolve)
end

---Sets a function for collision filtering.
---
---If the group and category filtering doesn't generate a collision decision, this function gets called with the two Shapes as arguments. The function should return a boolean value where true means the Shapes will collide and false means they will pass through each other.
---
---[Open in Browser](https://love2d.org/wiki/World:setContactFilter)
---
---@param filter (fun(shapeA: love.physics.Shape, shapeB: love.physics.Shape):(boolean))? The function handling the contact filtering, or nil to remove it.
function World:setContactFilter(filter)
end

---Set the gravity of the world.
---
---[Open in Browser](https://love2d.org/wiki/World:setGravity)
---
---@param x number The x component of gravity.
---@param y number The y component of gravity.
function World:setGravity(x, y)
end

---Sets the sleep behaviour of the world.
---
---[Open in Browser](https://love2d.org/wiki/World:setSleepingAllowed)
---
---@param allow boolean True if bodies in the world are allowed to sleep, or false if not.
function World:setSleepingAllowed(allow)
end

---Translates the World's origin. Useful in large worlds where floating point precision issues become noticeable at far distances from the origin.
---
---[Open in Browser](https://love2d.org/wiki/World:translateOrigin)
---
---@param x number The x component of the new origin with respect to the old origin.
---@param y number The y component of the new origin with respect to the old origin.
function World:translateOrigin(x, y)
end

---Update the state of the world. Shapes, Bodies and Joints destroyed during the update (for example from a callback) are destroyed once it finishes.
---
---[Open in Browser](https://love2d.org/wiki/World:update)
---
---@param dt number The time (in seconds) to advance the physics simulation.
---@param velocityiterations (number)? The maximum number of steps used to determine the new velocities when resolving a collision.
---@param positioniterations (number)? The maximum number of steps used to determine the new positions when resolving a collision.
function World:update(dt, velocityiterations, positioniterations)
end

---Computes the frequency and damping ratio of a joint spring from its angular stiffness and damping and the rotational inertia of the two bodies. The inverse of love.physics.computeAngularStiffness.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.computeAngularFrequency)
---
---@param stiffness number The angular stiffness, in newton-meters per radian.
---@param damping number The angular damping, in newton-meter-seconds per radian.
---@param body1 love.physics.Body The first Body the joint connects.
---@param body2 (love.physics.Body)? The second Body the joint connects. If omitted, the World's static ground body is used.
---@return number frequency The spring frequency in hertz.
---@return number dampingRatio The damping ratio, where 0 is no damping and 1 is critical damping.
function love.physics.computeAngularFrequency(stiffness, damping, body1, body2)
end

---Computes the angular stiffness and damping for a joint spring, such as WeldJoint:setStiffness, from a frequency and damping ratio and the rotational inertia of the two bodies.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.computeAngularStiffness)
---
---@param frequency number The spring frequency in hertz.
---@param dampingRatio number The damping ratio, where 0 is no damping and 1 is critical damping.
---@param body1 love.physics.Body The first Body the joint connects.
---@param body2 (love.physics.Body)? The second Body the joint connects. If omitted, the World's static ground body is used.
---@return number stiffness The angular stiffness, in newton-meters per radian.
---@return number damping The angular damping, in newton-meter-seconds per radian.
function love.physics.computeAngularStiffness(frequency, dampingRatio, body1, body2)
end

---Computes the frequency and damping ratio of a joint spring from its linear stiffness and damping and the masses of the two bodies. The inverse of love.physics.computeLinearStiffness.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.computeLinearFrequency)
---
---@param stiffness number The linear stiffness, in newtons per meter.
---@param damping number The linear damping, in newton-seconds per meter.
---@param body1 love.physics.Body The first Body the joint connects.
---@param body2 (love.physics.Body)? The second Body the joint connects. If omitted, the World's static ground body is used.
---@return number frequency The spring frequency in hertz.
---@return number dampingRatio The damping ratio, where 0 is no damping and 1 is critical damping.
function love.physics.computeLinearFrequency(stiffness, damping, body1, body2)
end

---Computes the linear stiffness and damping for a joint spring, such as DistanceJoint:setStiffness, from a frequency and damping ratio and the masses of the two bodies.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.computeLinearStiffness)
---
---@param frequency number The spring frequency in hertz.
---@param dampingRatio number The damping ratio, where 0 is no damping and 1 is critical damping.
---@param body1 love.physics.Body The first Body the joint connects.
---@param body2 (love.physics.Body)? The second Body the joint connects. If omitted, the World's static ground body is used.
---@return number stiffness The linear stiffness, in newtons per meter.
---@return number damping The linear damping, in newton-seconds per meter.
function love.physics.computeLinearStiffness(frequency, dampingRatio, body1, body2)
end

---Returns the two closest points between two Shapes and their distance. Both Shapes must be attached to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.getDistance)
---
---@param shape1 love.physics.Shape The first Shape.
---@param shape2 love.physics.Shape The second Shape.
---@return number distance The distance of the two points.
---@return number x1 The x-coordinate of the first point.
---@return number y1 The y-coordinate of the first point.
---@return number x2 The x-coordinate of the second point.
---@return number y2 The y-coordinate of the second point.
function love.physics.getDistance(shape1, shape2)
end

---Returns the meter scale factor.
---
---All coordinates in the physics module are divided by this number, creating a convenient way to draw the objects directly to the screen without the need for graphics transformations.
---
---It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.getMeter)
---
---@return number scale The scale factor as an integer.
function love.physics.getMeter()
end

---Creates a new body.
---
---There are three types of bodies. 
---
---* Static bodies do not move, have a infinite mass, and can be used for level boundaries. 
---
---* Dynamic bodies are the main actors in the simulation, they collide with everything. 
---
---* Kinematic bodies do not react to forces and only collide with dynamic bodies.
---
---The mass of the body gets calculated when a Shape is attached or removed, but can be changed at any time with Body:setMass or Body:resetMassData.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newBody)
---
---@param world love.physics.World The world to create the body in.
---@param x (number)? The x position of the body.
---@param y (number)? The y position of the body.
---@param type (love.physics.BodyType)? The type of the body.
---@return love.physics.Body body A new body.
function love.physics.newBody(world, x, y, type)
end

---Creates a new Body with a ChainShape. The Body is placed at the average of the points, and the points are made relative to it.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param loop boolean If the chain should loop back to the first point.
---@param x1 number The x position of the first point, in world coordinates.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param ... number Additional point positions.
---@return love.physics.Body body The new Body.
---@return love.physics.ChainShape shape The new ChainShape, attached to the Body.
function love.physics.newChainBody(world, type, loop, x1, y1, x2, y2, ...)
end

---Creates a new Body with a ChainShape. The Body is placed at the average of the points, and the points are made relative to it.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param loop boolean If the chain should loop back to the first point.
---@param points (number)[] A list of points in world coordinates, in the form of {x1, y1, x2, y2, ...}.
---@return love.physics.Body body The new Body.
---@return love.physics.ChainShape shape The new ChainShape, attached to the Body.
function love.physics.newChainBody(world, type, loop, points)
end

---Creates a new ChainShape and attaches it to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param loop boolean If the chain should loop back to the first point.
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param ... number Additional point positions.
---@return love.physics.ChainShape shape The new shape.
function love.physics.newChainShape(body, loop, x1, y1, x2, y2, ...)
end

---Creates a new ChainShape and attaches it to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param loop boolean If the chain should loop back to the first point.
---@param points (number)[] A list of points to construct the ChainShape, in the form of {x1, y1, x2, y2, ...}.
---@return love.physics.ChainShape shape The new shape.
function love.physics.newChainShape(body, loop, points)
end

---Creates a new ChainShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainShape)
---
---@param loop boolean If the chain should loop back to the first point.
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param ... number Additional point positions.
---@return love.physics.ChainShape shape The new shape.
function love.physics.newChainShape(loop, x1, y1, x2, y2, ...)
end

---Creates a new ChainShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newChainShape)
---
---@param loop boolean If the chain should loop back to the first point.
---@param points (number)[] A list of points to construct the ChainShape, in the form of {x1, y1, x2, y2, ...}.
---@return love.physics.ChainShape shape The new shape.
function love.physics.newChainShape(loop, points)
end

---Creates a new Body with a CircleShape centered on it.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newCircleBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param x number The x position of the Body and the center of the circle.
---@param y number The y position of the Body and the center of the circle.
---@param radius number The radius of the circle.
---@return love.physics.Body body The new Body.
---@return love.physics.CircleShape shape The new CircleShape, attached to the Body.
function love.physics.newCircleBody(world, type, x, y, radius)
end

---Creates a new CircleShape and attaches it to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newCircleShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param radius number The radius of the circle.
---@return love.physics.CircleShape shape The new shape.
function love.physics.newCircleShape(body, radius)
end

---Creates a new CircleShape and attaches it to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newCircleShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param x number The x position of the circle.
---@param y number The y position of the circle.
---@param radius number The radius of the circle.
---@return love.physics.CircleShape shape The new shape.
function love.physics.newCircleShape(body, x, y, radius)
end

---Creates a new CircleShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newCircleShape)
---
---@param radius number The radius of the circle.
---@return love.physics.CircleShape shape The new shape.
function love.physics.newCircleShape(radius)
end

---Creates a new CircleShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newCircleShape)
---
---@param x number The x position of the circle.
---@param y number The y position of the circle.
---@param radius number The radius of the circle.
---@return love.physics.CircleShape shape The new shape.
function love.physics.newCircleShape(x, y, radius)
end

---Creates a DistanceJoint between two bodies.
---
---This joint constrains the distance between two points on two bodies to be constant. These two points are specified in world coordinates and the two bodies are assumed to be in place when this joint is created. The first anchor point is connected to the first body and the second to the second body, and the points define the length of the distance joint.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newDistanceJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x1 number The x position of the first anchor point (world space).
---@param y1 number The y position of the first anchor point (world space).
---@param x2 number The x position of the second anchor point (world space).
---@param y2 number The y position of the second anchor point (world space).
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.DistanceJoint joint The new distance joint.
function love.physics.newDistanceJoint(body1, body2, x1, y1, x2, y2, collideConnected)
end

---Creates a new Body with an EdgeShape. The Body's position is derived from the two points, and the points are made relative to it.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param x1 number The x position of the first point, in world coordinates.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@return love.physics.Body body The new Body.
---@return love.physics.EdgeShape shape The new EdgeShape, attached to the Body.
function love.physics.newEdgeBody(world, type, x1, y1, x2, y2)
end

---Creates a new Body with an EdgeShape. The Body's position is derived from the two points, and the points are made relative to it.
---
---Sets the previous and next vertices too, which keeps shapes sliding along a chain of edges from catching on the joins (see EdgeShape:setPreviousVertex).
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param x1 number The x position of the first point, in world coordinates.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param prevx number The x position of the previous vertex, which connects the edge to the shape before it.
---@param prevy number The y position of the previous vertex.
---@param nextx number The x position of the next vertex, which connects the edge to the shape after it.
---@param nexty number The y position of the next vertex.
---@return love.physics.Body body The new Body.
---@return love.physics.EdgeShape shape The new EdgeShape, attached to the Body.
function love.physics.newEdgeBody(world, type, x1, y1, x2, y2, prevx, prevy, nextx, nexty)
end

---Creates a new EdgeShape and attaches it to a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@return love.physics.EdgeShape shape The new shape.
function love.physics.newEdgeShape(body, x1, y1, x2, y2)
end

---Creates a new EdgeShape and attaches it to a Body.
---
---Sets the previous and next vertices too, which keeps shapes sliding along a chain of edges from catching on the joins (see EdgeShape:setPreviousVertex).
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param prevx number The x position of the previous vertex, which connects the edge to the shape before it.
---@param prevy number The y position of the previous vertex.
---@param nextx number The x position of the next vertex, which connects the edge to the shape after it.
---@param nexty number The y position of the next vertex.
---@return love.physics.EdgeShape shape The new shape.
function love.physics.newEdgeShape(body, x1, y1, x2, y2, prevx, prevy, nextx, nexty)
end

---Creates a new EdgeShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeShape)
---
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@return love.physics.EdgeShape shape The new shape.
function love.physics.newEdgeShape(x1, y1, x2, y2)
end

---Creates a new EdgeShape and attaches it to a Body.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newEdgeShape)
---
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param prevx number The x position of the previous vertex, which connects the edge to the shape before it.
---@param prevy number The y position of the previous vertex.
---@param nextx number The x position of the next vertex, which connects the edge to the shape after it.
---@param nexty number The y position of the next vertex.
---@return love.physics.EdgeShape shape The new shape.
function love.physics.newEdgeShape(x1, y1, x2, y2, prevx, prevy, nextx, nexty)
end

---Create a friction joint between two bodies. A FrictionJoint applies friction to a body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newFrictionJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x number The x position of the anchor point.
---@param y number The y position of the anchor point.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.FrictionJoint joint The new FrictionJoint.
function love.physics.newFrictionJoint(body1, body2, x, y, collideConnected)
end

---Create a friction joint between two bodies. A FrictionJoint applies friction to a body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newFrictionJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x1 number The x position of the first anchor point.
---@param y1 number The y position of the first anchor point.
---@param x2 number The x position of the second anchor point.
---@param y2 number The y position of the second anchor point.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.FrictionJoint joint The new FrictionJoint.
function love.physics.newFrictionJoint(body1, body2, x1, y1, x2, y2, collideConnected)
end

---Create a GearJoint connecting two Joints.
---
---The gear joint connects two joints that must be either  prismatic or  revolute joints. Using this joint requires that the joints it uses connect their respective bodies to the ground and have the ground as the first body. When destroying the bodies and joints you must make sure you destroy the gear joint before the other joints.
---
---The gear joint has a ratio the determines how the angular or distance values of the connected joints relate to each other. The formula coordinate1 + ratio * coordinate2 always has a constant value that is set when the gear joint is created.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newGearJoint)
---
---@param joint1 love.physics.Joint The first joint to connect with a gear joint.
---@param joint2 love.physics.Joint The second joint to connect with a gear joint.
---@param ratio (number)? The gear ratio.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.GearJoint joint The new gear joint.
function love.physics.newGearJoint(joint1, joint2, ratio, collideConnected)
end

---Creates a joint between two bodies which controls the relative motion between them.
---
---Position and rotation offsets can be specified once the MotorJoint has been created, as well as the maximum motor force and torque that will be be applied to reach the target offsets.
---
---Uses a position correction factor of 0.3.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newMotorJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@return love.physics.MotorJoint joint The new MotorJoint.
function love.physics.newMotorJoint(body1, body2)
end

---Creates a joint between two bodies which controls the relative motion between them.
---
---Position and rotation offsets can be specified once the MotorJoint has been created, as well as the maximum motor force and torque that will be be applied to reach the target offsets.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newMotorJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param correctionFactor number The joint's initial position correction factor, in the range of [0, 1].
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.MotorJoint joint The new MotorJoint.
function love.physics.newMotorJoint(body1, body2, correctionFactor, collideConnected)
end

---Create a joint between a body and the mouse.
---
---This joint actually connects the body to a fixed point in the world. To make it follow the mouse, the fixed point must be updated every timestep (example below).
---
---The advantage of using a MouseJoint instead of just changing a body position directly is that collisions and reactions to other joints are handled by the physics engine. 
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newMouseJoint)
---
---@param body love.physics.Body The body to attach to the mouse.
---@param x number The x position of the connecting point.
---@param y number The y position of the connecting point.
---@return love.physics.MouseJoint joint The new mouse joint.
function love.physics.newMouseJoint(body, x, y)
end

---Creates a new Body with a PolygonShape. The Body is placed at the average of the vertices, and the vertices are made relative to it.
---
---The polygon can have 8 vertices at most, and must form a convex shape.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param x1 number The x position of the first point, in world coordinates.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param x3 number The x position of the third point.
---@param y3 number The y position of the third point.
---@param ... number You can continue passing more point positions to create the PolygonShape.
---@return love.physics.Body body The new Body.
---@return love.physics.PolygonShape shape The new PolygonShape, attached to the Body.
function love.physics.newPolygonBody(world, type, x1, y1, x2, y2, x3, y3, ...)
end

---Creates a new Body with a PolygonShape. The Body is placed at the average of the vertices, and the vertices are made relative to it.
---
---The polygon can have 8 vertices at most, and must form a convex shape.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param vertices (number)[] A list of vertices in world coordinates, in the form of {x1, y1, x2, y2, x3, y3, ...}.
---@return love.physics.Body body The new Body.
---@return love.physics.PolygonShape shape The new PolygonShape, attached to the Body.
function love.physics.newPolygonBody(world, type, vertices)
end

---Creates a new PolygonShape and attaches it to a Body.
---
---This shape can have 8 vertices at most, and must form a convex shape.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param x3 number The x position of the third point.
---@param y3 number The y position of the third point.
---@param ... number You can continue passing more point positions to create the PolygonShape.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newPolygonShape(body, x1, y1, x2, y2, x3, y3, ...)
end

---Creates a new PolygonShape and attaches it to a Body.
---
---This shape can have 8 vertices at most, and must form a convex shape.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param vertices (number)[] A list of vertices to construct the polygon, in the form of {x1, y1, x2, y2, x3, y3, ...}.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newPolygonShape(body, vertices)
end

---Creates a new PolygonShape and attaches it to a Body.
---
---This shape can have 8 vertices at most, and must form a convex shape.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonShape)
---
---@param x1 number The x position of the first point.
---@param y1 number The y position of the first point.
---@param x2 number The x position of the second point.
---@param y2 number The y position of the second point.
---@param x3 number The x position of the third point.
---@param y3 number The y position of the third point.
---@param ... number You can continue passing more point positions to create the PolygonShape.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newPolygonShape(x1, y1, x2, y2, x3, y3, ...)
end

---Creates a new PolygonShape and attaches it to a Body.
---
---This shape can have 8 vertices at most, and must form a convex shape.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPolygonShape)
---
---@param vertices (number)[] A list of vertices to construct the polygon, in the form of {x1, y1, x2, y2, x3, y3, ...}.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newPolygonShape(vertices)
end

---Creates a PrismaticJoint between two bodies.
---
---A prismatic joint constrains two bodies to move relatively to each other on a specified axis. It does not allow for relative rotation. Its definition and operation are similar to a  revolute joint, but with translation and force substituted for angle and torque.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPrismaticJoint)
---
---@param body1 love.physics.Body The first body to connect with a prismatic joint.
---@param body2 love.physics.Body The second body to connect with a prismatic joint.
---@param x number The x coordinate of the anchor point.
---@param y number The y coordinate of the anchor point.
---@param ax number The x coordinate of the axis vector.
---@param ay number The y coordinate of the axis vector.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.PrismaticJoint joint The new prismatic joint.
function love.physics.newPrismaticJoint(body1, body2, x, y, ax, ay, collideConnected)
end

---Creates a PrismaticJoint between two bodies.
---
---A prismatic joint constrains two bodies to move relatively to each other on a specified axis. It does not allow for relative rotation. Its definition and operation are similar to a  revolute joint, but with translation and force substituted for angle and torque.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPrismaticJoint)
---
---@param body1 love.physics.Body The first body to connect with a prismatic joint.
---@param body2 love.physics.Body The second body to connect with a prismatic joint.
---@param x1 number The x coordinate of the first anchor point.
---@param y1 number The y coordinate of the first anchor point.
---@param x2 number The x coordinate of the second anchor point.
---@param y2 number The y coordinate of the second anchor point.
---@param ax number The x coordinate of the axis unit vector.
---@param ay number The y coordinate of the axis unit vector.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@param referenceAngle (number)? The reference angle between body1 and body2, in radians. If omitted, the current angle of body2 minus the angle of body1 is used.
---@return love.physics.PrismaticJoint joint The new prismatic joint.
function love.physics.newPrismaticJoint(body1, body2, x1, y1, x2, y2, ax, ay, collideConnected, referenceAngle)
end

---Creates a PulleyJoint to join two bodies to each other and the ground.
---
---The pulley joint simulates a pulley with an optional block and tackle. If the ratio parameter has a value different from one, then the simulated rope extends faster on one side than the other. In a pulley joint the total length of the simulated rope is the constant length1 + ratio * length2, which is set when the pulley joint is created.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newPulleyJoint)
---
---@param body1 love.physics.Body The first body to connect with a pulley joint.
---@param body2 love.physics.Body The second body to connect with a pulley joint.
---@param gx1 number The x coordinate of the first body's ground anchor.
---@param gy1 number The y coordinate of the first body's ground anchor.
---@param gx2 number The x coordinate of the second body's ground anchor.
---@param gy2 number The y coordinate of the second body's ground anchor.
---@param x1 number The x coordinate of the pulley joint anchor in the first body.
---@param y1 number The y coordinate of the pulley joint anchor in the first body.
---@param x2 number The x coordinate of the pulley joint anchor in the second body.
---@param y2 number The y coordinate of the pulley joint anchor in the second body.
---@param ratio (number)? The joint ratio.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.PulleyJoint joint The new pulley joint.
function love.physics.newPulleyJoint(body1, body2, gx1, gy1, gx2, gy2, x1, y1, x2, y2, ratio, collideConnected)
end

---Creates a new Body with a rectangular PolygonShape centered on it.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRectangleBody)
---
---@param world love.physics.World The World to create the Body in.
---@param type love.physics.BodyType The type of the Body.
---@param x number The x position of the Body and the center of the rectangle.
---@param y number The y position of the Body and the center of the rectangle.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@param angle (number)? The angle of the rectangle relative to the Body, in radians.
---@return love.physics.Body body The new Body.
---@return love.physics.PolygonShape shape The new PolygonShape, attached to the Body.
function love.physics.newRectangleBody(world, type, x, y, width, height, angle)
end

---Shorthand for creating rectangular PolygonShapes, attached to a Body. 
---
---By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRectangleShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newRectangleShape(body, width, height)
end

---Shorthand for creating rectangular PolygonShapes, attached to a Body. 
---
---By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRectangleShape)
---
---@param body love.physics.Body The Body the Shape is attached to.
---@param x number The offset along the x-axis.
---@param y number The offset along the y-axis.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@param angle (number)? The initial angle of the rectangle.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newRectangleShape(body, x, y, width, height, angle)
end

---Shorthand for creating rectangular PolygonShapes, attached to a Body. 
---
---By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRectangleShape)
---
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newRectangleShape(width, height)
end

---Shorthand for creating rectangular PolygonShapes, attached to a Body. 
---
---By default, the local origin is located at the '''center''' of the rectangle as opposed to the top left for graphics.
---
---Deprecated: creates a Shape that is not attached to any Body. Use the variant with a Body.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRectangleShape)
---
---@param x number The offset along the x-axis.
---@param y number The offset along the y-axis.
---@param width number The width of the rectangle.
---@param height number The height of the rectangle.
---@param angle (number)? The initial angle of the rectangle.
---@return love.physics.PolygonShape shape A new PolygonShape.
function love.physics.newRectangleShape(x, y, width, height, angle)
end

---Creates a pivot joint between two bodies.
---
---This joint connects two bodies to a point around which they can pivot.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRevoluteJoint)
---
---@param body1 love.physics.Body The first body.
---@param body2 love.physics.Body The second body.
---@param x number The x position of the connecting point.
---@param y number The y position of the connecting point.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.RevoluteJoint joint The new revolute joint.
function love.physics.newRevoluteJoint(body1, body2, x, y, collideConnected)
end

---Creates a pivot joint between two bodies.
---
---This joint connects two bodies to a point around which they can pivot.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRevoluteJoint)
---
---@param body1 love.physics.Body The first body.
---@param body2 love.physics.Body The second body.
---@param x1 number The x position of the first connecting point.
---@param y1 number The y position of the first connecting point.
---@param x2 number The x position of the second connecting point.
---@param y2 number The y position of the second connecting point.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@param referenceAngle (number)? The reference angle between body1 and body2, in radians. If omitted, the current angle of body2 minus the angle of body1 is used.
---@return love.physics.RevoluteJoint joint The new revolute joint.
function love.physics.newRevoluteJoint(body1, body2, x1, y1, x2, y2, collideConnected, referenceAngle)
end

---Creates a joint between two bodies. Its only function is enforcing a max distance between these bodies.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newRopeJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x1 number The x position of the first anchor point.
---@param y1 number The y position of the first anchor point.
---@param x2 number The x position of the second anchor point.
---@param y2 number The y position of the second anchor point.
---@param maxLength number The maximum distance for the bodies.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.RopeJoint joint The new RopeJoint.
function love.physics.newRopeJoint(body1, body2, x1, y1, x2, y2, maxLength, collideConnected)
end

---Creates a constraint joint between two bodies. A WeldJoint essentially glues two bodies together. The constraint is a bit soft, however, due to Box2D's iterative solver.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newWeldJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x number The x position of the anchor point (world space).
---@param y number The y position of the anchor point (world space).
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.WeldJoint joint The new WeldJoint.
function love.physics.newWeldJoint(body1, body2, x, y, collideConnected)
end

---Creates a constraint joint between two bodies. A WeldJoint essentially glues two bodies together. The constraint is a bit soft, however, due to Box2D's iterative solver.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newWeldJoint)
---
---@param body1 love.physics.Body The first body to attach to the joint.
---@param body2 love.physics.Body The second body to attach to the joint.
---@param x1 number The x position of the first anchor point (world space).
---@param y1 number The y position of the first anchor point  (world space).
---@param x2 number The x position of the second anchor point (world space).
---@param y2 number The y position of the second anchor point (world space).
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@param referenceAngle (number)? The reference angle between body1 and body2, in radians. If omitted, the current angle of body2 minus the angle of body1 is used.
---@return love.physics.WeldJoint joint The new WeldJoint.
function love.physics.newWeldJoint(body1, body2, x1, y1, x2, y2, collideConnected, referenceAngle)
end

---Creates a wheel joint.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newWheelJoint)
---
---@param body1 love.physics.Body The first body.
---@param body2 love.physics.Body The second body.
---@param x number The x position of the anchor point.
---@param y number The y position of the anchor point.
---@param ax number The x position of the axis unit vector.
---@param ay number The y position of the axis unit vector.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.WheelJoint joint The new WheelJoint.
function love.physics.newWheelJoint(body1, body2, x, y, ax, ay, collideConnected)
end

---Creates a wheel joint.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newWheelJoint)
---
---@param body1 love.physics.Body The first body.
---@param body2 love.physics.Body The second body.
---@param x1 number The x position of the first anchor point.
---@param y1 number The y position of the first anchor point.
---@param x2 number The x position of the second anchor point.
---@param y2 number The y position of the second anchor point.
---@param ax number The x position of the axis unit vector.
---@param ay number The y position of the axis unit vector.
---@param collideConnected (boolean)? Specifies whether the two bodies should collide with each other.
---@return love.physics.WheelJoint joint The new WheelJoint.
function love.physics.newWheelJoint(body1, body2, x1, y1, x2, y2, ax, ay, collideConnected)
end

---Creates a new World.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.newWorld)
---
---@param xg (number)? The x component of gravity.
---@param yg (number)? The y component of gravity.
---@param sleep (boolean)? Whether the bodies in this world are allowed to sleep.
---@return love.physics.World world A brave new World.
function love.physics.newWorld(xg, yg, sleep)
end

---Sets the pixels to meter scale factor.
---
---All coordinates in the physics module are divided by this number and converted to meters, and it creates a convenient way to draw the objects directly to the screen without the need for graphics transformations.
---
---It is recommended to create shapes no larger than 10 times the scale. This is important because Box2D is tuned to work well with shape sizes from 0.1 to 10 meters. The default meter scale is 30.
---
---[Open in Browser](https://love2d.org/wiki/love.physics.setMeter)
---
---@param scale number The scale factor as an integer.
function love.physics.setMeter(scale)
end

---Provides functionality to access device sensors such as an accelerometer or gyroscope.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor)
---
---@class love.sensor
love.sensor = {}

---Kinds of sensors.
---
---[Open in Browser](https://love2d.org/wiki/SensorType)
---
---@alias love.sensor.SensorType
---Accelerometer sensor.
---| "accelerometer"
---Gyroscope sensor.
---| "gyroscope"
---@alias love.SensorType love.sensor.SensorType

---Gets the latest values of a device sensor. The meaning of the values depends on the sensor type, for example an accelerometer gives the acceleration along each axis.
---
---Raises an error if the sensor isn't enabled with love.sensor.setEnabled.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor.getData)
---
---@param sensorType love.sensor.SensorType The type of sensor to read.
---@return number x The sensor's current 1st value.
---@return number y The sensor's current 2nd value.
---@return number z The sensor's current 3rd value.
function love.sensor.getData(sensorType)
end

---Gets the device-specific name of a sensor.
---
---Raises an error if the sensor isn't enabled with love.sensor.setEnabled.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor.getName)
---
---@param sensorType love.sensor.SensorType The type of sensor.
---@return string name The name of the sensor.
function love.sensor.getName(sensorType)
end

---Check if the specified sensor exists in the device.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor.hasSensor)
---
---@param sensorType love.sensor.SensorType Type of sensor to check.
---@return boolean available Sensor availability status.
function love.sensor.hasSensor(sensorType)
end

---Gets whether a sensor is enabled.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor.isEnabled)
---
---@param sensorType love.sensor.SensorType The type of sensor to check.
---@return boolean enabled Whether the sensor is enabled.
function love.sensor.isEnabled(sensorType)
end

---Enables or disables a sensor. Only enabled sensors can be read with love.sensor.getData and trigger love.sensorupdated.
---
---[Open in Browser](https://love2d.org/wiki/love.sensor.setEnabled)
---
---@param sensorType love.sensor.SensorType The type of sensor to enable or disable.
---@param enable boolean True to enable the sensor, false to disable it.
function love.sensor.setEnabled(sensorType, enable)
end

---This module is responsible for decoding sound files. It can't play the sounds, see love.audio for that.
---
---[Open in Browser](https://love2d.org/wiki/love.sound)
---
---@class love.sound
love.sound = {}

---An object which can gradually decode a sound file.
---
---[Open in Browser](https://love2d.org/wiki/Decoder)
---
---@class love.sound.Decoder: love.Object
local Decoder = {}
---@alias love.Decoder love.sound.Decoder

---Creates a new copy of current decoder.
---
---The new decoder will start decoding from the beginning of the audio stream.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:clone)
---
---@return love.sound.Decoder decoder New copy of the decoder.
function Decoder:clone()
end

---Decodes the next chunk of audio, at most the Decoder's buffer size in bytes, and returns a SoundData object containing it.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:decode)
---
---@return love.sound.SoundData soundData Decoded audio data, or nil if the end of the stream was reached.
function Decoder:decode()
end

---Returns the number of bits per sample.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:getBitDepth)
---
---@return number bitDepth Either 8, or 16.
function Decoder:getBitDepth()
end

---Returns the number of channels in the stream.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:getChannelCount)
---
---@return number channels 1 for mono, 2 for stereo.
function Decoder:getChannelCount()
end

---Gets the duration of the sound file. It may not always be sample-accurate, and it may return -1 if the duration cannot be determined at all.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:getDuration)
---
---@return number duration The duration of the sound file in seconds, or -1 if it cannot be determined.
function Decoder:getDuration()
end

---Returns the sample rate of the Decoder.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:getSampleRate)
---
---@return number rate Number of samples per second.
function Decoder:getSampleRate()
end

---Sets the currently playing position of the Decoder.
---
---[Open in Browser](https://love2d.org/wiki/Decoder:seek)
---
---@param offset number The position to seek to, in seconds. 0 rewinds to the beginning.
function Decoder:seek(offset)
end

---Contains raw audio samples.
---
---You can not play SoundData back directly. You must wrap a Source object around it.
---
---[Open in Browser](https://love2d.org/wiki/SoundData)
---
---@class love.sound.SoundData: love.Data, love.Object
local SoundData = {}
---@alias love.SoundData love.sound.SoundData

---Creates a new copy of the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:clone)
---
---@return love.sound.SoundData clone The new copy.
function SoundData:clone()
end

---Copies the specified section of the given SoundData into this one.
---
---Samples start from zero. If a SoundData has multiple channels, each sample contains data for all channels.
---
---Both SoundDatas must have the same channel count. Different bit depths are converted. This function does not perform sample rate conversion. If the SoundDatas have different sample rate, the resulting audio may played slower or faster depending on the differences.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:copyFrom)
---
---@param sourcedata love.sound.SoundData The SoundData to copy from.
---@param sourcestart number The first sample in the source SoundData to copy from.
---@param samplecount number The total number of samples to copy.
---@param deststart (number)? The first sample in the destination SoundData to copy to.
function SoundData:copyFrom(sourcedata, sourcestart, samplecount, deststart)
end

---Returns the number of bits per sample.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getBitDepth)
---
---@return number bitdepth Either 8, or 16.
function SoundData:getBitDepth()
end

---Returns the number of channels in the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getChannelCount)
---
---@return number channels 1 for mono, 2 for stereo.
function SoundData:getChannelCount()
end

---Gets the duration of the sound data.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getDuration)
---
---@return number duration The duration of the sound data in seconds.
function SoundData:getDuration()
end

---Gets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getSample)
---
---@param i number An integer value specifying the position of the sample (starting at 0).
---@return number sample The normalized samplepoint (range -1.0 to 1.0).
function SoundData:getSample(i)
end

---Gets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.
---
---Gets the value of a sample using an explicit sample index instead of interleaving them in the sample position parameter.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getSample)
---
---@param i number An integer value specifying the position of the sample (starting at 0).
---@param channel number The index of the channel to get within the given sample, starting at 1.
---@return number sample The normalized samplepoint (range -1.0 to 1.0).
function SoundData:getSample(i, channel)
end

---Returns the number of samples per channel of the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getSampleCount)
---
---@return number count Total number of samples.
function SoundData:getSampleCount()
end

---Returns the sample rate of the SoundData.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:getSampleRate)
---
---@return number rate Number of samples per second.
function SoundData:getSampleRate()
end

---Destroys the SoundData's Lua reference, like Object:release. When LuaJIT's FFI is available it also drops the sample access data the SoundData's Lua methods cache.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:release)
---
---@return boolean success True if the object was released by this call, false if it had been previously released.
function SoundData:release()
end

---Sets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:setSample)
---
---@param i number An integer value specifying the position of the sample (starting at 0).
---@param sample number The normalized samplepoint (range -1.0 to 1.0).
function SoundData:setSample(i, sample)
end

---Sets the value of the sample-point at the specified position. For stereo SoundData objects, the data from the left and right channels are interleaved in that order.
---
---Sets the value of a sample using an explicit sample index instead of interleaving them in the sample position parameter.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:setSample)
---
---@param i number An integer value specifying the position of the sample (starting at 0).
---@param channel number The index of the channel to set within the given sample, starting at 1.
---@param sample number The normalized samplepoint (range -1.0 to 1.0).
function SoundData:setSample(i, channel, sample)
end

---Creates a new copy of a section of this SoundData.
---
---Samples start from zero. If a SoundData has multiple channels, each sample contains data for all channels.
---
---[Open in Browser](https://love2d.org/wiki/SoundData:slice)
---
---@param start number The first sample of this SoundData to copy from.
---@param samplecount (number)? The total number of samples to copy to the new SoundData. A negative value copies all samples from start to the end.
---@return love.sound.SoundData data The new SoundData containing a copy of the specified section of the original SoundData.
function SoundData:slice(start, samplecount)
end

---Attempts to find a decoder for the encoded sound data in the specified file, Data or Stream. The decoder is chosen from the contents of the data, not the file extension.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newDecoder)
---
---@param filename string The filename of the file with encoded sound data.
---@param buffer (number)? The size of each decoded chunk, in bytes.
---@param streamtype (love.audio.StreamType)? Whether to stream the encoded data from the file, or to read the whole file into memory first and decode from there.
---@return love.sound.Decoder decoder A new Decoder object.
function love.sound.newDecoder(filename, buffer, streamtype)
end

---Attempts to find a decoder for the encoded sound data in the specified file, Data or Stream. The decoder is chosen from the contents of the data, not the file extension.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newDecoder)
---
---@param file love.filesystem.File The file with encoded sound data.
---@param buffer (number)? The size of each decoded chunk, in bytes.
---@param streamtype (love.audio.StreamType)? Whether to stream the encoded data from the file, or to read the whole file into memory first and decode from there.
---@return love.sound.Decoder decoder A new Decoder object.
function love.sound.newDecoder(file, buffer, streamtype)
end

---Attempts to find a decoder for the encoded sound data in the specified file, Data or Stream. The decoder is chosen from the contents of the data, not the file extension.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newDecoder)
---
---@param data love.Data The Data (such as FileData) containing encoded sound data.
---@param buffer (number)? The size of each decoded chunk, in bytes.
---@return love.sound.Decoder decoder A new Decoder object.
function love.sound.newDecoder(data, buffer)
end

---Attempts to find a decoder for the encoded sound data in the specified file, Data or Stream. The decoder is chosen from the contents of the data, not the file extension.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newDecoder)
---
---@param stream love.Stream A readable Stream of encoded sound data.
---@param buffer (number)? The size of each decoded chunk, in bytes.
---@return love.sound.Decoder decoder A new Decoder object.
function love.sound.newDecoder(stream, buffer)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param filename string The file name of the file to load.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(filename)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param file love.filesystem.File A File pointing to an audio file.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(file)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param data love.Data The Data (such as FileData) containing an encoded audio file.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(data)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param stream love.Stream A readable Stream of encoded audio.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(stream)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param decoder love.sound.Decoder Decode data from this Decoder until EOF.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(decoder)
end

---Creates new SoundData from a filepath, File, Data, Stream or Decoder. It's also possible to create SoundData with a custom sample rate, channel and bit depth.
---
---The sound data will be decoded to the memory in a raw format. It is recommended to create only short sounds like effects, as a 3 minute song uses 30 MB of memory this way.
---
---[Open in Browser](https://love2d.org/wiki/love.sound.newSoundData)
---
---@param samples number Total number of samples.
---@param rate (number)? Number of samples per second
---@param bits (number)? Bits per sample (8 or 16).
---@param channels (number)? Either 1 for mono or 2 for stereo.
---@return love.sound.SoundData soundData A new SoundData object.
function love.sound.newSoundData(samples, rate, bits, channels)
end

---Provides access to information about the user's system.
---
---[Open in Browser](https://love2d.org/wiki/love.system)
---
---@class love.system
love.system = {}

---The basic state of the system's power supply.
---
---[Open in Browser](https://love2d.org/wiki/PowerState)
---
---@alias love.system.PowerState
---Cannot determine power status.
---| "unknown"
---Not plugged in, running on a battery.
---| "battery"
---Plugged in, no battery available.
---| "nobattery"
---Plugged in, charging battery.
---| "charging"
---Plugged in, battery is fully charged.
---| "charged"
---@alias love.PowerState love.system.PowerState

---Gets text from the clipboard.
---
---[Open in Browser](https://love2d.org/wiki/love.system.getClipboardText)
---
---@return string text The text currently held in the system's clipboard.
function love.system.getClipboardText()
end

---Gets the amount of RAM in the system.
---
---[Open in Browser](https://love2d.org/wiki/love.system.getMemorySize)
---
---@return number size The amount of system RAM, in MiB.
function love.system.getMemorySize()
end

---Gets the current operating system. In general, LÖVE abstracts away the need to know the current operating system, but there are a few cases where it can be useful (especially in combination with os.execute.)
---
---[Open in Browser](https://love2d.org/wiki/love.system.getOS)
---
---@return string osString The current operating system: 'OS X', 'Windows', 'UWP', 'Linux', 'Android', 'iOS' or 'Unknown'.
function love.system.getOS()
end

---Gets information about the system's power supply.
---
---[Open in Browser](https://love2d.org/wiki/love.system.getPowerInfo)
---
---@return love.system.PowerState state The basic state of the power supply.
---@return number|nil percent Percentage of battery life left, between 0 and 100. nil if the value can't be determined or there's no battery.
---@return number|nil seconds Seconds of battery life left. nil if the value can't be determined or there's no battery.
function love.system.getPowerInfo()
end

---Gets preferred locales in order of user's preference.
---
---[Open in Browser](https://love2d.org/wiki/love.system.getPreferredLocales)
---
---@return (string)[] locales A sequence of strings in order of user's preference. Locales are in form xx_YY (or just xx when country is not available) where xx is an ISO-639 language specifier and YY (if available) is an ISO-3166 country code
function love.system.getPreferredLocales()
end

---Gets the amount of logical processor in the system.
---
---The number includes the threads reported if technologies such as Intel's Hyper-threading are enabled. For example, on a 4-core CPU with Hyper-threading, this function will return 8.
---
---[Open in Browser](https://love2d.org/wiki/love.system.getProcessorCount)
---
---@return number processorCount Amount of logical processors.
function love.system.getProcessorCount()
end

---Gets whether another application on the system is playing music in the background.
---
---Currently this is implemented on iOS and Android, and will always return false on other operating systems. The t.audio.mixwithsystem flag in love.conf can be used to configure whether background audio / music from other apps should play while LÖVE is open.
---
---[Open in Browser](https://love2d.org/wiki/love.system.hasBackgroundMusic)
---
---@return boolean backgroundmusic True if the user is playing music in the background via another app, false otherwise.
function love.system.hasBackgroundMusic()
end

---Opens a URL with the user's web or file browser.
---
---Passing file:// scheme in Android 7.0 (Nougat) and later always result in failure. Prior to 11.2, this will crash LÖVE instead of returning false.
---
---[Open in Browser](https://love2d.org/wiki/love.system.openURL)
---
---@param url string The URL to open. Must be formatted as a proper URL.
---@return boolean success Whether the URL was opened successfully.
function love.system.openURL(url)
end

---Puts text in the clipboard.
---
---[Open in Browser](https://love2d.org/wiki/love.system.setClipboardText)
---
---@param text string The new text to hold in the system's clipboard.
function love.system.setClipboardText(text)
end

---Causes the device to vibrate, if possible. Currently this will only work on Android and iOS devices that have a built-in vibration motor.
---
---[Open in Browser](https://love2d.org/wiki/love.system.vibrate)
---
---@param seconds (number)? The duration to vibrate for. If called on an iOS device, it will always vibrate for 0.5 seconds due to limitations in the iOS system APIs.
function love.system.vibrate(seconds)
end

---Allows you to work with threads.
---
---Threads are separate Lua environments, running in parallel to the main code. As their code runs separately, they can be used to compute complex operations without adversely affecting the frame rate of the main thread. However, as they are separate environments, they cannot access the variables and functions of the main thread, and communication between threads is limited.
---
---All LOVE objects (userdata) are shared among threads so you'll only have to send their references across threads. You may run into concurrency issues if you manipulate an object on multiple threads at the same time.
---
---When a Thread is started, it only loads the love.thread module. Every other module has to be loaded with require.
---
---[Open in Browser](https://love2d.org/wiki/love.thread)
---
---@class love.thread
love.thread = {}

---An object which can be used to send and receive data between different threads.
---
---[Open in Browser](https://love2d.org/wiki/Channel)
---
---@class love.thread.Channel: love.Object
local Channel = {}
---@alias love.Channel love.thread.Channel

---Clears all the messages in the Channel queue.
---
---[Open in Browser](https://love2d.org/wiki/Channel:clear)
---
function Channel:clear()
end

---Retrieves the value of a Channel message and removes it from the message queue.
---
---It waits until a message is in the queue then returns the message value.
---
---[Open in Browser](https://love2d.org/wiki/Channel:demand)
---
---@return string|number|boolean|table|love.Object value The contents of the message.
function Channel:demand()
end

---Retrieves the value of a Channel message and removes it from the message queue.
---
---It waits until a message is in the queue then returns the message value.
---
---[Open in Browser](https://love2d.org/wiki/Channel:demand)
---
---@param timeout number The maximum amount of time to wait.
---@return string|number|boolean|table|love.Object value The contents of the message or nil if the timeout expired.
function Channel:demand(timeout)
end

---Retrieves the number of messages in the thread Channel queue.
---
---[Open in Browser](https://love2d.org/wiki/Channel:getCount)
---
---@return number count The number of messages in the queue.
function Channel:getCount()
end

---Gets whether a pushed value has been popped or otherwise removed from the Channel.
---
---[Open in Browser](https://love2d.org/wiki/Channel:hasRead)
---
---@param id number An id value previously returned by Channel:push.
---@return boolean hasread Whether the value represented by the id has been removed from the Channel via Channel:pop, Channel:demand, or Channel:clear.
function Channel:hasRead(id)
end

---Retrieves the value of a Channel message, but leaves it in the queue.
---
---It returns nil if there's no message in the queue.
---
---[Open in Browser](https://love2d.org/wiki/Channel:peek)
---
---@return string|number|boolean|table|love.Object value The contents of the message.
function Channel:peek()
end

---Executes the specified function atomically with respect to this Channel.
---
---Calling multiple methods in a row on the same Channel is often useful. However if multiple Threads are calling this Channel's methods at the same time, the different calls on each Thread might end up interleaved (e.g. one or more of the second thread's calls may happen in between the first thread's calls.)
---
---This method avoids that issue by making sure the Thread calling the method has exclusive access to the Channel until the specified function has returned.
---
---[Open in Browser](https://love2d.org/wiki/Channel:performAtomic)
---
---@param func fun(channel: love.thread.Channel, ...: any):(any) The function to call, the form of function(channel, arg1, arg2, ...) end. The Channel is passed as the first argument to the function when it is called.
---@param ... any Additional arguments that the given function will receive when it is called.
---@return any ret1 The first return value of the given function (if any.)
---@return any ... Any other return values.
function Channel:performAtomic(func, ...)
end

---Retrieves the value of a Channel message and removes it from the message queue.
---
---It returns nil if there are no messages in the queue.
---
---[Open in Browser](https://love2d.org/wiki/Channel:pop)
---
---@return string|number|boolean|table|love.Object value The contents of the message.
function Channel:pop()
end

---Send a message to the thread Channel.
---
---See Variant for the list of supported types.
---
---[Open in Browser](https://love2d.org/wiki/Channel:push)
---
---@param value string|number|boolean|table|love.Object The contents of the message.
---@return number id Identifier which can be supplied to Channel:hasRead
function Channel:push(value)
end

---Send a message to the thread Channel and wait for a thread to accept it.
---
---See Variant for the list of supported types.
---
---[Open in Browser](https://love2d.org/wiki/Channel:supply)
---
---@param value string|number|boolean|table|love.Object The contents of the message.
---@return boolean success Whether the message was successfully supplied (always true).
function Channel:supply(value)
end

---Send a message to the thread Channel and wait for a thread to accept it.
---
---See Variant for the list of supported types.
---
---[Open in Browser](https://love2d.org/wiki/Channel:supply)
---
---@param value string|number|boolean|table|love.Object The contents of the message.
---@param timeout number The maximum amount of time to wait.
---@return boolean success Whether the message was successfully supplied before the timeout expired.
function Channel:supply(value, timeout)
end

---A Thread is a chunk of code that can run in parallel with other threads. Data can be sent between different threads with Channel objects.
---
---[Open in Browser](https://love2d.org/wiki/Thread)
---
---@class love.thread.Thread: love.thread.Threadable, love.Object
local Thread = {}
---@alias love.Thread love.thread.Thread

---Retrieves the error string from the thread if it produced an error.
---
---[Open in Browser](https://love2d.org/wiki/Thread:getError)
---
---@return string err The error message, or nil if the Thread has not caused an error.
function Thread:getError()
end

---Returns whether the thread is currently running.
---
---Threads which are not running can be (re)started with Thread:start.
---
---[Open in Browser](https://love2d.org/wiki/Thread:isRunning)
---
---@return boolean value True if the thread is running, false otherwise.
function Thread:isRunning()
end

---Starts the thread.
---
---Threads can be restarted after they have completed their execution.
---
---[Open in Browser](https://love2d.org/wiki/Thread:start)
---
---@return boolean started Whether the thread was started. False if it is already running.
function Thread:start()
end

---Starts the thread.
---
---Threads can be restarted after they have completed their execution.
---
---Arguments passed to Thread:start are accessible in the thread's main file via ... (the vararg expression).
---
---[Open in Browser](https://love2d.org/wiki/Thread:start)
---
---@param ... string|number|boolean|table|love.Object A string, number, boolean, LÖVE object, or flat table.
---@return boolean started Whether the thread was started. False if it is already running.
function Thread:start(...)
end

---Wait for a thread to finish.
---
---This call will block until the thread finishes.
---
---[Open in Browser](https://love2d.org/wiki/Thread:wait)
---
function Thread:wait()
end

---The base type of objects that run code on their own system thread, such as Thread.
---
---[Open in Browser](https://love2d.org/wiki/Threadable)
---
---@class love.thread.Threadable: love.Object
local Threadable = {}
---@alias love.Threadable love.thread.Threadable

---Creates or retrieves a named thread channel.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.getChannel)
---
---@param name string The name of the channel you want to create or retrieve.
---@return love.thread.Channel channel The Channel object associated with the name.
function love.thread.getChannel(name)
end

---Create a new unnamed thread channel.
---
---One use for them is to pass new unnamed channels to other threads via Channel:push on a named channel.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.newChannel)
---
---@return love.thread.Channel channel The new Channel object.
function love.thread.newChannel()
end

---Creates a new Thread from a filename, string, File or Data object containing Lua code.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.newThread)
---
---@param filename string The name of the Lua file to use as the source.
---@return love.thread.Thread thread A new Thread that has yet to be started.
function love.thread.newThread(filename)
end

---Creates a new Thread from a filename, string, File or Data object containing Lua code.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.newThread)
---
---@param file love.filesystem.File|love.filesystem.FileData The File or FileData containing the Lua code to use as the source.
---@return love.thread.Thread thread A new Thread that has yet to be started.
function love.thread.newThread(file)
end

---Creates a new Thread from a filename, string, File or Data object containing Lua code.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.newThread)
---
---@param codestring string A string containing the Lua code to use as the source. It needs to either be at least 1024 characters long, or contain at least one newline.
---@return love.thread.Thread thread A new Thread that has yet to be started.
function love.thread.newThread(codestring)
end

---Creates a new Thread from a filename, string, File or Data object containing Lua code.
---
---[Open in Browser](https://love2d.org/wiki/love.thread.newThread)
---
---@param data love.Data A Data object containing the Lua code to use as the source.
---@return love.thread.Thread thread A new Thread that has yet to be started.
function love.thread.newThread(data)
end

---Provides an interface to the user's clock.
---
---[Open in Browser](https://love2d.org/wiki/love.timer)
---
---@class love.timer
love.timer = {}

---Returns the average delta time (seconds per frame) over the last second.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.getAverageDelta)
---
---@return number delta The average delta time over the last second.
function love.timer.getAverageDelta()
end

---Returns the time between the last two frames.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.getDelta)
---
---@return number dt The time passed (in seconds).
function love.timer.getDelta()
end

---Returns the current frames per second.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.getFPS)
---
---@return number fps The current FPS.
function love.timer.getFPS()
end

---Returns the value of a timer with an unspecified starting time.
---
---This function should only be used to calculate differences between points in time, as the starting time of the timer is unknown.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.getTime)
---
---@return number time The time in seconds. Given as a decimal, accurate to the microsecond.
function love.timer.getTime()
end

---Pauses the current thread for the specified amount of time.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.sleep)
---
---@param s number Seconds to sleep for.
function love.timer.sleep(s)
end

---Measures the time between two frames.
---
---Calling this changes the return value of love.timer.getDelta.
---
---[Open in Browser](https://love2d.org/wiki/love.timer.step)
---
---@return number dt The time passed (in seconds).
function love.timer.step()
end

---Provides an interface to touch-screen and touchpad presses.
---
---[Open in Browser](https://love2d.org/wiki/love.touch)
---
---@class love.touch
love.touch = {}

---Kinds of device a touch-press can come from.
---
---[Open in Browser](https://love2d.org/wiki/TouchDeviceType)
---
---@alias love.touch.TouchDeviceType
---A touch screen. Touch positions are in pixels inside the window.
---| "touchscreen"
---A touchpad with absolute positions, such as a trackpad. Touch positions are normalized to the range [0, 1].
---| "touchpad"
---A touchpad with relative positions. Touch positions are normalized to the range [0, 1].
---| "touchpadrelative"
---@alias love.TouchDeviceType love.touch.TouchDeviceType

---Gets the kind of device the specified touch-press comes from.
---
---[Open in Browser](https://love2d.org/wiki/love.touch.getDeviceType)
---
---@param id lightuserdata The identifier of the touch-press. Use love.touch.getTouches, love.touchpressed, or love.touchmoved to obtain touch id values.
---@return love.touch.TouchDeviceType devicetype The kind of device the touch-press comes from.
function love.touch.getDeviceType(id)
end

---Gets the current position of the specified touch-press.
---
---Raises an error if the id isn't an active touch-press.
---
---[Open in Browser](https://love2d.org/wiki/love.touch.getPosition)
---
---@param id lightuserdata The identifier of the touch-press. Use love.touch.getTouches, love.touchpressed, or love.touchmoved to obtain touch id values.
---@return number x The position along the x-axis of the touch-press: in pixels inside the window for a touch screen, normalized to the range [0, 1] for a touchpad.
---@return number y The position along the y-axis of the touch-press: in pixels inside the window for a touch screen, normalized to the range [0, 1] for a touchpad.
function love.touch.getPosition(id)
end

---Gets the current pressure of the specified touch-press.
---
---Raises an error if the id isn't an active touch-press.
---
---[Open in Browser](https://love2d.org/wiki/love.touch.getPressure)
---
---@param id lightuserdata The identifier of the touch-press. Use love.touch.getTouches, love.touchpressed, or love.touchmoved to obtain touch id values.
---@return number pressure The pressure of the touch-press. Most touch screens aren't pressure sensitive, in which case the pressure will be 1.
function love.touch.getPressure(id)
end

---Gets a list of all active touch-presses.
---
---The id values are the same as those used as arguments to love.touchpressed, love.touchmoved, and love.touchreleased.
---
---The id value of a specific touch-press is only guaranteed to be unique for the duration of that touch-press. As soon as love.touchreleased is called using that id, it may be reused for a new touch-press via love.touchpressed.
---
---[Open in Browser](https://love2d.org/wiki/love.touch.getTouches)
---
---@param devicetype (love.touch.TouchDeviceType)? Only list touch-presses from this kind of device, or nil to list all of them.
---@return (lightuserdata)[] touches A list of active touch-press id values, which can be used with love.touch.getPosition.
function love.touch.getTouches(devicetype)
end

---Gets whether the specified touch-press was generated from a mouse rather than a touch device.
---
---[Open in Browser](https://love2d.org/wiki/love.touch.isMouse)
---
---@param id lightuserdata The identifier of the touch-press. Use love.touch.getTouches, love.touchpressed, or love.touchmoved to obtain touch id values.
---@return boolean mouse True if the touch-press was generated from a mouse, false otherwise.
function love.touch.isMouse(id)
end

---This module is responsible for decoding, controlling, and streaming video files.
---
---It can't draw the videos, see love.graphics.newVideo and Video objects for that.
---
---[Open in Browser](https://love2d.org/wiki/love.video)
---
---@class love.video
love.video = {}

---An object which decodes, streams, and controls Videos.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream)
---
---@class love.video.VideoStream: love.Object
local VideoStream = {}
---@alias love.VideoStream love.video.VideoStream

---Gets the filename of the VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:getFilename)
---
---@return string filename The filename of the VideoStream.
function VideoStream:getFilename()
end

---Gets whether the VideoStream is playing.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:isPlaying)
---
---@return boolean playing Whether the VideoStream is playing.
function VideoStream:isPlaying()
end

---Pauses the VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:pause)
---
function VideoStream:pause()
end

---Plays the VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:play)
---
function VideoStream:play()
end

---Rewinds the VideoStream. Synonym to VideoStream:seek(0).
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:rewind)
---
function VideoStream:rewind()
end

---Sets the current playback position of the VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:seek)
---
---@param offset number The time in seconds since the beginning of the VideoStream.
function VideoStream:seek(offset)
end

---Sets what the VideoStream's playback position is synchronized to.
---
---Synchronizes the VideoStream to the playback position of an audio Source.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:setSync)
---
---@param source love.audio.Source The Source to follow.
function VideoStream:setSync(source)
end

---Sets what the VideoStream's playback position is synchronized to.
---
---Shares the synchronization of another VideoStream, so both play in step.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:setSync)
---
---@param other love.video.VideoStream The VideoStream whose synchronization to share.
function VideoStream:setSync(other)
end

---Sets what the VideoStream's playback position is synchronized to.
---
---Makes the VideoStream keep its own time again, continuing from its current position.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:setSync)
---
function VideoStream:setSync()
end

---Gets the current playback position of the VideoStream.
---
---[Open in Browser](https://love2d.org/wiki/VideoStream:tell)
---
---@return number seconds The number of seconds since the beginning of the VideoStream.
function VideoStream:tell()
end

---Creates a new VideoStream. Currently only Ogg Theora video files are supported. VideoStreams can't draw videos, see love.graphics.newVideo for that.
---
---[Open in Browser](https://love2d.org/wiki/love.video.newVideoStream)
---
---@param filename string The file path to the Ogg Theora video file.
---@return love.video.VideoStream videostream A new VideoStream.
function love.video.newVideoStream(filename)
end

---Creates a new VideoStream. Currently only Ogg Theora video files are supported. VideoStreams can't draw videos, see love.graphics.newVideo for that.
---
---[Open in Browser](https://love2d.org/wiki/love.video.newVideoStream)
---
---@param file love.filesystem.File The File object containing the Ogg Theora video. It is opened for reading if it is not open yet.
---@return love.video.VideoStream videostream A new VideoStream.
function love.video.newVideoStream(file)
end

---Provides an interface for modifying and retrieving information about the program's window.
---
---[Open in Browser](https://love2d.org/wiki/love.window)
---
---@class love.window
love.window = {}

---Types of device display orientation.
---
---[Open in Browser](https://love2d.org/wiki/DisplayOrientation)
---
---@alias love.window.DisplayOrientation
---Orientation cannot be determined.
---| "unknown"
---Landscape orientation.
---| "landscape"
---Landscape orientation (flipped).
---| "landscapeflipped"
---Portrait orientation.
---| "portrait"
---Portrait orientation (flipped).
---| "portraitflipped"
---@alias love.DisplayOrientation love.window.DisplayOrientation

---Possible types of file dialogs. 
---
---[Open in Browser](https://love2d.org/wiki/FileDialogType)
---
---@alias love.window.FileDialogType
---Retrieve one or more files to be opened for reading.
---| "openfile"
---Retrieve a folder.
---| "openfolder"
---Retrieve a valid filename to be opened for writing.
---| "savefile"
---@alias love.FileDialogType love.window.FileDialogType

---Types of fullscreen modes.
---
---[Open in Browser](https://love2d.org/wiki/FullscreenType)
---
---@alias love.window.FullscreenType
---Sometimes known as borderless fullscreen windowed mode. A borderless screen-sized window is created which sits on top of all desktop UI elements. The window is automatically resized to match the dimensions of the desktop, and its size cannot be changed.
---| "desktop"
---Standard exclusive-fullscreen mode. Changes the display mode (actual resolution) of the monitor.
---| "exclusive"
---@alias love.FullscreenType love.window.FullscreenType

---Types of message box dialogs. Different types may have slightly different looks.
---
---[Open in Browser](https://love2d.org/wiki/MessageBoxType)
---
---@alias love.window.MessageBoxType
---Informational dialog.
---| "info"
---Warning dialog.
---| "warning"
---Error dialog.
---| "error"
---@alias love.MessageBoxType love.window.MessageBoxType

---The light or dark appearance the operating system is set to, as returned by love.window.getSystemTheme.
---
---[Open in Browser](https://love2d.org/wiki/SystemTheme)
---
---@alias love.window.SystemTheme
---The system theme can't be determined.
---| "unknown"
---The system uses a light theme.
---| "light"
---The system uses a dark theme.
---| "dark"
---@alias love.SystemTheme love.window.SystemTheme

---Closes the window. It can be reopened with love.window.setMode.
---
---Deprecated, with no replacement.
---
---[Open in Browser](https://love2d.org/wiki/love.window.close)
---
function love.window.close()
end

---Brings the window into the foreground above other windows and sets input focus.
---
---This may not be functional on all platforms.
---
---[Open in Browser](https://love2d.org/wiki/love.window.focus)
---
function love.window.focus()
end

---Converts a number from pixels to density-independent units.
---
---The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.fromPixels(1600) would return 800 in that case.
---
---This function converts coordinates from pixels to the size users are expecting them to display at onscreen. love.window.toPixels does the opposite. t.highdpi in love.conf must be enabled to use the full pixel density of a high-DPI screen. If the window's usedpiscale flag is false, no conversion is done.
---
---Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
---
---[Open in Browser](https://love2d.org/wiki/love.window.fromPixels)
---
---@param pixelvalue number A number in pixels to convert to density-independent units.
---@return number value The converted number, in density-independent units.
function love.window.fromPixels(pixelvalue)
end

---Converts a number from pixels to density-independent units.
---
---The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.fromPixels(1600) would return 800 in that case.
---
---This function converts coordinates from pixels to the size users are expecting them to display at onscreen. love.window.toPixels does the opposite. t.highdpi in love.conf must be enabled to use the full pixel density of a high-DPI screen. If the window's usedpiscale flag is false, no conversion is done.
---
---Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
---
---The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in terms of pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.window.fromPixels)
---
---@param px number The x-axis value of a coordinate in pixels.
---@param py number The y-axis value of a coordinate in pixels.
---@return number x The converted x-axis value of the coordinate, in density-independent units.
---@return number y The converted y-axis value of the coordinate, in density-independent units.
function love.window.fromPixels(px, py)
end

---Gets the DPI scale factor associated with the window.
---
---The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.getDPIScale() would return 2.0 in that case.
---
---The love.window.fromPixels and love.window.toPixels functions can also be used to convert between units.
---
---t.highdpi in love.conf must be enabled to use the full pixel density of a high-DPI screen. Returns 1 if the window's usedpiscale flag is false; love.window.getNativeDPIScale returns the display's scale regardless.
---
---The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in terms of pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getDPIScale)
---
---@return number scale The pixel scale factor associated with the window.
function love.window.getDPIScale()
end

---Gets the width and height of the desktop.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getDesktopDimensions)
---
---@param displayindex (number)? The index of the display, or nil for the display the window is currently in.
---@return number width The width of the desktop.
---@return number height The height of the desktop.
function love.window.getDesktopDimensions(displayindex)
end

---Gets the number of connected monitors.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getDisplayCount)
---
---@return number count The number of currently connected displays.
function love.window.getDisplayCount()
end

---Gets the name of a display.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getDisplayName)
---
---@param displayindex number The index of the display to get the name of.
---@return string name The name of the specified display.
function love.window.getDisplayName(displayindex)
end

---Gets current device display orientation.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getDisplayOrientation)
---
---@param displayindex (number)? The index of the display to get the orientation of, or nil for the display the window is currently in.
---@return love.window.DisplayOrientation orientation Current device display orientation.
function love.window.getDisplayOrientation(displayindex)
end

---Gets whether the window is fullscreen.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getFullscreen)
---
---@return boolean fullscreen True if the window is fullscreen, false otherwise.
---@return love.window.FullscreenType fstype The type of fullscreen mode used.
function love.window.getFullscreen()
end

---Gets a list of supported fullscreen modes.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getFullscreenModes)
---
---@param displayindex (number)? The index of the display, or nil for the display the window is currently in.
---@return {width: number, height: number, refreshrate: number}[] modes A list of display modes. (Note that this may not be in order.)
function love.window.getFullscreenModes(displayindex)
end

---Gets the window icon.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getIcon)
---
---@return love.image.ImageData|nil imagedata The window icon imagedata, or nil if no icon has been set with love.window.setIcon.
function love.window.getIcon()
end

---Gets the display mode and properties of the window.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getMode)
---
---@param flags (table)? A table to fill in and return as the flags result, instead of creating a new table.
---@return number width Window width.
---@return number height Window height.
---@return {fullscreen: boolean, fullscreentype: love.window.FullscreenType, vsync: number, msaa: number, stencil: boolean, depth: boolean, resizable: boolean, borderless: boolean, centered: boolean, displayindex: number, minwidth: number, minheight: number, usedpiscale: boolean, refreshrate: number, x: number, y: number} flags Table with the window properties:
function love.window.getMode(flags)
end

---Gets the DPI scale factor of the display the window is in, ignoring the window's usedpiscale flag.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getNativeDPIScale)
---
---@return number scale The display's pixel scale factor.
function love.window.getNativeDPIScale()
end

---Gets a pointer to the window's low level internal object. Currently this is a SDL_Window pointer.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getPointer)
---
---@return lightuserdata pointer A pointer to the window's SDL_Window object.
function love.window.getPointer()
end

---Gets the position of the window on the screen.
---
---The window position is in the coordinate space of the display it is currently in.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getPosition)
---
---@return number x The x-coordinate of the window's position.
---@return number y The y-coordinate of the window's position.
---@return number displayindex The index of the display that the window is in.
function love.window.getPosition()
end

---Gets area inside the window which is known to be unobstructed by a system title bar, the iPhone X notch, etc. Useful for making sure UI elements can be seen by the user.
---
---Values returned are in DPI-scaled units (the same coordinate system as most other window-related APIs), not in pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getSafeArea)
---
---@return number x Starting position of safe area (x-axis).
---@return number y Starting position of safe area (y-axis).
---@return number w Width of safe area.
---@return number h Height of safe area.
function love.window.getSafeArea()
end

---Gets whether the operating system is set to a light or dark theme. love.themechanged is called when it changes.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getSystemTheme)
---
---@return love.window.SystemTheme theme The current system theme.
function love.window.getSystemTheme()
end

---Gets the window title.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getTitle)
---
---@return string title The current window title.
function love.window.getTitle()
end

---Gets current vertical synchronization (vsync).
---
---This can be less expensive alternative to love.window.getMode if you want to get current vsync status.
---
---[Open in Browser](https://love2d.org/wiki/love.window.getVSync)
---
---@return number vsync Current vsync status. 1 if enabled, 0 if disabled, and -1 for adaptive vsync.
function love.window.getVSync()
end

---Checks if the game window has keyboard focus.
---
---[Open in Browser](https://love2d.org/wiki/love.window.hasFocus)
---
---@return boolean focus True if the window has the focus or false if not.
function love.window.hasFocus()
end

---Checks if the game window has mouse focus.
---
---[Open in Browser](https://love2d.org/wiki/love.window.hasMouseFocus)
---
---@return boolean focus True if the window has mouse focus or false if not.
function love.window.hasMouseFocus()
end

---Gets whether the display is allowed to sleep while the program is running.
---
---Display sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isDisplaySleepEnabled)
---
---@return boolean enabled True if system display sleep is enabled / allowed, false otherwise.
function love.window.isDisplaySleepEnabled()
end

---Gets whether high-DPI mode is allowed, as set by t.highdpi in love.conf.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isHighDPIAllowed)
---
---@return boolean allowed Whether high-DPI mode is allowed.
function love.window.isHighDPIAllowed()
end

---Gets whether the Window is currently maximized.
---
---The window can be maximized if it is not fullscreen and is resizable, and either the user has pressed the window's Maximize button or love.window.maximize has been called.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isMaximized)
---
---@return boolean maximized True if the window is currently maximized in windowed mode, false otherwise.
function love.window.isMaximized()
end

---Gets whether the Window is currently minimized.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isMinimized)
---
---@return boolean minimized True if the window is currently minimized, false otherwise.
function love.window.isMinimized()
end

---Checks if the game window is fully covered by other windows. love.occluded is called when the window becomes occluded.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isOccluded)
---
---@return boolean occluded True if the window is occluded, false if not.
function love.window.isOccluded()
end

---Checks if the window is open.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isOpen)
---
---@return boolean open True if the window is open, false otherwise.
function love.window.isOpen()
end

---Checks if the game window is visible.
---
---The window is considered visible if it's not minimized and the program isn't hidden.
---
---[Open in Browser](https://love2d.org/wiki/love.window.isVisible)
---
---@return boolean visible True if the window is visible or false if not.
function love.window.isVisible()
end

---Makes the window as large as possible.
---
---This function has no effect if the window isn't resizable, since it essentially programmatically presses the window's 'maximize' button.
---
---[Open in Browser](https://love2d.org/wiki/love.window.maximize)
---
function love.window.maximize()
end

---Minimizes the window to the system's task bar / dock.
---
---[Open in Browser](https://love2d.org/wiki/love.window.minimize)
---
function love.window.minimize()
end

---Causes the window to request the attention of the user if it is not in the foreground.
---
---In Windows the taskbar icon will flash, and in OS X the dock icon will bounce.
---
---[Open in Browser](https://love2d.org/wiki/love.window.requestAttention)
---
---@param continuous (boolean)? Whether to continuously request attention until the window becomes active, or to do it only once.
function love.window.requestAttention(continuous)
end

---Restores the size and position of the window if it was minimized or maximized.
---
---[Open in Browser](https://love2d.org/wiki/love.window.restore)
---
function love.window.restore()
end

---Sets whether the display is allowed to sleep while the program is running.
---
---Display sleep is disabled by default. Some types of input (e.g. joystick button presses) might not prevent the display from sleeping, if display sleep is allowed.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setDisplaySleepEnabled)
---
---@param enable boolean True to enable system display sleep, false to disable it.
function love.window.setDisplaySleepEnabled(enable)
end

---Enters or exits fullscreen. The display to use when entering fullscreen is chosen based on which display the window is currently in, if multiple monitors are connected.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setFullscreen)
---
---@param fullscreen boolean Whether to enter or exit fullscreen mode.
---@return boolean success True if an attempt to enter fullscreen was successful, false otherwise.
function love.window.setFullscreen(fullscreen)
end

---Enters or exits fullscreen. The display to use when entering fullscreen is chosen based on which display the window is currently in, if multiple monitors are connected.
---
---If fullscreen mode is entered and the window size doesn't match one of the monitor's display modes (in 'exclusive' fullscreen mode) or the window size doesn't match the desktop size (in 'desktop' fullscreen mode), the window will be resized appropriately. The window will revert back to its original size again when fullscreen mode is exited using this function.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setFullscreen)
---
---@param fullscreen boolean Whether to enter or exit fullscreen mode.
---@param fstype love.window.FullscreenType The type of fullscreen mode to use.
---@return boolean success True if an attempt to enter fullscreen was successful, false otherwise.
function love.window.setFullscreen(fullscreen, fstype)
end

---Sets the window icon until the game is quit. Not all operating systems support very large icon images.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setIcon)
---
---@param imagedata love.image.ImageData The window icon image.
---@return boolean success Whether the icon has been set successfully.
function love.window.setIcon(imagedata)
end

---Sets the display mode and properties of the window, creating the window if it isn't open yet.
---
---If width or height is 0, setMode will use the width and height of the desktop.
---
---Changing the display mode doesn't clear the contents of Canvases or recreate graphics resources.
---
---* If the fullscreen type is 'desktop', then the window will be automatically resized to the desktop resolution.
---
---* If t.window is false in love.conf and this function is used to create the window, no other love.graphics function may be called before it.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setMode)
---
---@param width number Display width.
---@param height number Display height.
---@param flags ({fullscreen: (boolean)?, fullscreentype: (love.window.FullscreenType)?, vsync: (number|boolean)?, msaa: (number)?, stencil: (boolean)?, depth: (boolean)?, resizable: (boolean)?, borderless: (boolean)?, centered: (boolean)?, displayindex: (number)?, minwidth: (number)?, minheight: (number)?, x: (number)?, y: (number)?, usedpiscale: (boolean)?})? The flags table with the options. Fields that aren't given use the defaults listed here, not the current window's values (see love.window.updateMode for that).
---@return boolean success True if successful, false otherwise.
function love.window.setMode(width, height, flags)
end

---Sets the position of the window on the screen.
---
---The window position is in the coordinate space of the specified display.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setPosition)
---
---@param x number The x-coordinate of the window's position.
---@param y number The y-coordinate of the window's position.
---@param displayindex (number)? The index of the display that the new window position is relative to, or nil for the display the window is currently in.
---@param waitForSync (boolean)? Whether to wait until the window has actually moved before returning.
function love.window.setPosition(x, y, displayindex, waitForSync)
end

---Sets the window title.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setTitle)
---
---@param title string The new window title.
function love.window.setTitle(title)
end

---Sets vertical synchronization mode.
---
---* Not all graphics drivers support adaptive vsync (-1 value). In that case, it will be automatically set to 1.
---
---* It is recommended to keep vsync activated if you don't know about the possible implications of turning it off.
---
---* This function doesn't recreate the window, unlike love.window.setMode and love.window.updateMode.
---
---[Open in Browser](https://love2d.org/wiki/love.window.setVSync)
---
---@param vsync number|boolean VSync number: 1 to enable, 0 to disable, and -1 for adaptive vsync. true and false are the same as 1 and 0.
function love.window.setVSync(vsync)
end

---Open system file dialog capable of picking files and folder.
---
---* Not all platform supports this function or all dialog types. However "openfile" type is supported in most cases.
---* This is an asynchronous function. You'll get your result in the callback specified when calling the function.
---* Not all platform supports all settings. Some may support one subset of the settings, some may support the other.
---* In Windows and Android, it's recommended to use love.filesystem.openNativeFile to open them instead of standard Lua io.open.
---
---[Open in Browser](https://love2d.org/wiki/love.window.showFileDialog)
---
---@param type love.window.FileDialogType File dialog type.
---@param callback fun(files: (string)[], filtername: string|nil, errorstring: string|nil) Called with the result once the dialog is closed.
---@param settings ({title: (string)?, acceptlabel: (string)?, cancellabel: (string)?, defaultname: (string)?, filters: (table<string, string>)?, multiselect: (boolean)?, attachtowindow: (boolean)?})? A table containing the given fields:
function love.window.showFileDialog(type, callback, settings)
end

---Displays a message box dialog above the love window. The message box contains a title, optional text, and buttons.
---
---Displays a simple message box with a single 'OK' button.
---
---[Open in Browser](https://love2d.org/wiki/love.window.showMessageBox)
---
---@param title string The title of the message box.
---@param message string The text inside the message box.
---@param type (love.window.MessageBoxType)? The type of the message box.
---@param attachtowindow (boolean)? Whether the message box should be attached to the love window or free-floating.
---@return boolean success Whether the message box was successfully displayed.
function love.window.showMessageBox(title, message, type, attachtowindow)
end

---Displays a message box dialog above the love window. The message box contains a title, optional text, and buttons.
---
---Displays a message box with a customized list of buttons.
---
---[Open in Browser](https://love2d.org/wiki/love.window.showMessageBox)
---
---@param title string The title of the message box.
---@param message string The text inside the message box.
---@param buttonlist table A table containing a list of button names to show (at least one). The table can also contain the fields enterbutton and escapebutton, which should be the index of the default button to use when the user presses 'enter' or 'escape', respectively. They default to the first and the last button.
---@param type (love.window.MessageBoxType)? The type of the message box.
---@param attachtowindow (boolean)? Whether the message box should be attached to the love window or free-floating.
---@return number pressedbutton The index of the button pressed by the user. May be 0 if the message box dialog was closed without pressing a button.
function love.window.showMessageBox(title, message, buttonlist, type, attachtowindow)
end

---Converts a number from density-independent units to pixels.
---
---The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.toPixels(800) would return 1600 in that case.
---
---This is used to convert coordinates from the size users are expecting them to display at onscreen to pixels. love.window.fromPixels does the opposite. t.highdpi in love.conf must be enabled to use the full pixel density of a high-DPI screen. If the window's usedpiscale flag is false, no conversion is done.
---
---Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
---
---[Open in Browser](https://love2d.org/wiki/love.window.toPixels)
---
---@param value number A number in density-independent units to convert to pixels.
---@return number pixelvalue The converted number, in pixels.
function love.window.toPixels(value)
end

---Converts a number from density-independent units to pixels.
---
---The pixel density inside the window might be greater (or smaller) than the 'size' of the window. For example on a retina screen in Mac OS X with the highdpi window flag enabled, the window may take up the same physical size as an 800x600 window, but the area inside the window uses 1600x1200 pixels. love.window.toPixels(800) would return 1600 in that case.
---
---This is used to convert coordinates from the size users are expecting them to display at onscreen to pixels. love.window.fromPixels does the opposite. t.highdpi in love.conf must be enabled to use the full pixel density of a high-DPI screen. If the window's usedpiscale flag is false, no conversion is done.
---
---Most LÖVE functions return values and expect arguments in terms of pixels rather than density-independent units.
---
---The units of love.graphics.getWidth, love.graphics.getHeight, love.mouse.getPosition, mouse events, love.touch.getPosition, and touch events are always in terms of pixels.
---
---[Open in Browser](https://love2d.org/wiki/love.window.toPixels)
---
---@param x number The x-axis value of a coordinate in density-independent units to convert to pixels.
---@param y number The y-axis value of a coordinate in density-independent units to convert to pixels.
---@return number px The converted x-axis value of the coordinate, in pixels.
---@return number py The converted y-axis value of the coordinate, in pixels.
function love.window.toPixels(x, y)
end

---Sets the display mode and properties of the window, without modifying unspecified properties.
---
---If width or height is 0, updateMode will use the width and height of the desktop.
---
---Changing the display mode doesn't clear the contents of Canvases or recreate graphics resources.
---
---If the fullscreen type is 'desktop', then the window will be automatically resized to the desktop resolution.
---
---[Open in Browser](https://love2d.org/wiki/love.window.updateMode)
---
---@param width number Window width.
---@param height number Window height.
---@param settings ({fullscreen: (boolean)?, fullscreentype: (love.window.FullscreenType)?, vsync: (number|boolean)?, msaa: (number)?, stencil: (boolean)?, depth: (boolean)?, resizable: (boolean)?, borderless: (boolean)?, centered: (boolean)?, displayindex: (number)?, minwidth: (number)?, minheight: (number)?, x: (number)?, y: (number)?, usedpiscale: (boolean)?})? The settings table with the following optional fields. Any field not filled in will use the current value that would be returned by love.window.getMode.
---@return boolean success True if successful, false otherwise.
function love.window.updateMode(width, height, settings)
end

---Sets the display mode and properties of the window, without modifying unspecified properties.
---
---If width or height is 0, updateMode will use the width and height of the desktop.
---
---Changing the display mode doesn't clear the contents of Canvases or recreate graphics resources.
---
---Keeps the current width and height.
---
---[Open in Browser](https://love2d.org/wiki/love.window.updateMode)
---
---@param settings {fullscreen: (boolean)?, fullscreentype: (love.window.FullscreenType)?, vsync: (number|boolean)?, msaa: (number)?, stencil: (boolean)?, depth: (boolean)?, resizable: (boolean)?, borderless: (boolean)?, centered: (boolean)?, displayindex: (number)?, minwidth: (number)?, minheight: (number)?, x: (number)?, y: (number)?, usedpiscale: (boolean)?} The settings table with the following optional fields. Any field not filled in will use the current value that would be returned by love.window.getMode.
---@return boolean success True if successful, false otherwise.
function love.window.updateMode(settings)
end

return love
