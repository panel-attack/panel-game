local class = require("common.lib.class")
local ui = require("client.src.ui")
local DebugSettings = require("client.src.debug.DebugSettings")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local function createDebugBoolSelector(debugKey, onChangeFn)
  return ui.BoolSelector({
    startValue = DebugSettings.get(debugKey) --[[@as boolean]],
    onValueChange = function(selfElement, value)
      GAME.theme:playMoveSfx()
      DebugSettings.set(debugKey, value)
      if onChangeFn then
        onChangeFn()
      end
    end
  })
end

local function createDebugSlider(debugKey, min, max, onValueChangeFn)
  return ui.Slider({
    min = min,
    max = max,
    value = DebugSettings.get(debugKey) --[[@as number]],
    tickLength = math.ceil(100 / max),
    onValueChange = function(slider)
      DebugSettings.set(debugKey, slider.value)
      if onValueChangeFn then
        onValueChangeFn(slider)
      end
    end
  })
end

local function buildDebugMenuItems(options)
  local debugMenuOptions = {}

  for _, def in ipairs(DebugSettings.getDefinitions()) do
    if def.type == "boolean" then
      debugMenuOptions[#debugMenuOptions + 1] = ui.MenuItem.createBoolSelectorMenuItem(
        def.label,
        nil,
        false,
        createDebugBoolSelector(def.key)
      )
    elseif def.type == "number" then
      debugMenuOptions[#debugMenuOptions + 1] = ui.MenuItem.createSliderMenuItem(
        def.label,
        nil,
        false,
        createDebugSlider(def.key, def.min or 0, def.max or 100)
      )
    end
  end

  if DEBUG_ENABLED then
    debugMenuOptions[#debugMenuOptions + 1] = ui.MenuItem.createButtonMenuItem("Window Size Tester", nil, false, function()
      GAME.navigationStack:push(require("client.src.scenes.WindowSizeTester")())
    end)
  end

  if options.showBackButton then
    debugMenuOptions[#debugMenuOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
      GAME.theme:playCancelSfx()
      if options.onBack then
        options.onBack()
      end
    end)
  end

  return debugMenuOptions
end

-- Menu for configuring debug settings
---@class DebugMenu : Menu
local DebugMenu = class(function(self, options)
  
end, ui.Menu)

-- We need a factory because menu items must be passed into the base class init
function DebugMenu.makeDebugMenu(options)
  options = options or {}
  options.x = 0
  options.y = 0
  options.hAlign = "center"
  options.vAlign = "center"
  options.menuItems = buildDebugMenuItems(options)
  return DebugMenu(options)
end

return DebugMenu
