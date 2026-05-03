local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local inputManager = require("client.src.inputManager")
local joystickManager = require("common.lib.joystickManager")
local InputConfiguration = require("client.src.input.InputConfiguration")
local consts = require("common.engine.consts")

local MAX_LOG_ENTRIES = 20

local InputDebugMenu = class(function(self, sceneParams)
  self.music = "main"
  self.pressLog = {}
  self.prevDown = {}
end, Scene)

InputDebugMenu.name = "InputDebugMenu"

local function getDisplayName(rawKey)
  local guid, _, buttonId = InputConfiguration.parseBindingString(rawKey)
  if not guid then
    return rawKey  -- keyboard key, name is the key itself
  end

  for _, joystick in ipairs(love.joystick.getJoysticks()) do
    if joystick:getGUID() == guid then
      return InputConfiguration.getButtonNameFromMapping(joystick, buttonId)
    end
  end
  return buttonId
end

local function getControllerName(rawKey)
  local guid = InputConfiguration.parseBindingString(rawKey)
  if not guid then
    return nil
  end
  return joystickManager.guidToName[guid] or guid
end

local function getBoundActions(rawKey)
  local results = {}
  for i, config in ipairs(inputManager.inputConfigurations) do
    for _, keyName in ipairs(consts.KEY_NAMES) do
      if config[keyName] == rawKey then
        results[#results + 1] = "cfg" .. i .. "." .. keyName
      end
    end
  end
  return #results > 0 and table.concat(results, "  ") or "(unbound)"
end

function InputDebugMenu:update(dt)
  if inputManager.allKeys.isDown["escape"] then
    GAME.navigationStack:pop()
    return
  end

  local currentDown = {}
  for key, _ in pairs(inputManager.allKeys.isDown) do
    currentDown[key] = true
    if not self.prevDown[key] then
      local entry = {
        raw = key,
        display = getDisplayName(key),
        controller = getControllerName(key),
        actions = getBoundActions(key),
      }
      table.insert(self.pressLog, 1, entry)
      if #self.pressLog > MAX_LOG_ENTRIES then
        self.pressLog[MAX_LOG_ENTRIES + 1] = nil
      end
    end
  end
  self.prevDown = currentDown
end

function InputDebugMenu:draw()
  themes[config.theme].images.bg_main:draw()

  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 10, 10, consts.CANVAS_WIDTH - 20, consts.CANVAS_HEIGHT - 20)

  love.graphics.setColor(1, 1, 1, 1)
  local x = 20
  local y = 20
  local lineH = 18

  love.graphics.print("INPUT DEBUG  (keyboard Esc to return)", x, y)
  y = y + lineH + 4

  -- Connected devices section
  love.graphics.setColor(0.7, 0.9, 1, 1)
  love.graphics.print("CONNECTED DEVICES:", x, y)
  y = y + lineH
  local joysticks = love.joystick.getJoysticks()
  if #joysticks == 0 then
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("  (none)", x, y)
    y = y + lineH
  else
    for _, joystick in ipairs(joysticks) do
      local guid = joystick:getGUID()
      local slot = joystickManager.guidsToJoysticks[guid] and joystickManager.guidsToJoysticks[guid][joystick:getID()] or "?"
      local isGP = joystick:isGamepad() and "gamepad" or "joystick"
      love.graphics.setColor(1, 0.8, 0.4, 1)
      love.graphics.print(string.format("  [%s] slot=%s  guid=%s  %s", joystick:getName(), tostring(slot), guid, isGP), x, y)
      y = y + lineH
    end
  end

  love.graphics.setColor(0.5, 0.5, 0.5, 1)
  love.graphics.line(x, y, consts.CANVAS_WIDTH - 20, y)
  y = y + 6

  -- Column headers 
  love.graphics.setColor(0.7, 0.9, 1, 1)
  love.graphics.print("RAW KEY", x, y)
  love.graphics.print("DISPLAY", x + 340, y)
  love.graphics.print("CONTROLLER", x + 440, y)
  love.graphics.print("BOUND TO", x + 620, y)
  y = y + lineH

  if #self.pressLog == 0 then
    love.graphics.setColor(0.8, 0.8, 0.5, 1)
    love.graphics.print("(press any button...)", x, y)
  else
    for i, entry in ipairs(self.pressLog) do
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.print(entry.raw, x, y)
      love.graphics.setColor(0.4, 1, 0.4, 1)
      love.graphics.print(entry.display, x + 340, y)
      love.graphics.setColor(1, 0.8, 0.4, 1)
      love.graphics.print(entry.controller or "keyboard", x + 440, y)
      love.graphics.setColor(0.8, 0.8, 1, 1)
      love.graphics.print(entry.actions, x + 620, y)
      y = y + lineH
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return InputDebugMenu
