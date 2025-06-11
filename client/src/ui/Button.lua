local import = require("common.lib.import")
local UIElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")
local addCursorInteractionInterface = import("./CursorInteractable")

---@class ButtonOptions : UiElementOptions
---@field backgroundColor number[]?
---@field outlineColor number[]?
---@field receiveInputs fun(button: Button, cursor: Cursor, dt: number?)?
---@field action fun(button: Button?, input: table?, timeHeld: number?)? Callback for the main (often UI agnostic) action that should happen, e.g. setting character for a player and playing its selection SFX
---@field onAction fun(button: Button?, input: table?, timeHeld: number?)? Callback for UI specific actions that are unrelated to the action, e.g. redirecting cursor focus or playing validation SFX

---@class Button : UiElement, CursorInteractable
---@operator call(ButtonOptions): Button
---@field backgroundColor number[]
---@field outlineColor number []
---@field action fun(button: Button?, input: table?, timeHeld: number?)? Callback for the main (often UI agnostic) action that should happen, e.g. setting character for a player and playing its selection SFX
---@field onAction fun(button: Button?, input: table?, timeHeld: number?) Callback for UI specific actions that are unrelated to the action, e.g. redirecting cursor focus or playing validation SFX
local Button = class(
  function(self, options)
    self.hoveredBackgroundColor = {.5, .5, .5, .7}
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}

    -- callbacks
    self.action = options.action or self.action
    if options.onAction then
      self.onAction = options.onAction
    end

    addCursorInteractionInterface(self, options.receiveInputs or self.receiveInputs)
  end,
  UIElement
)

Button.TYPE = "Button"

function Button:onRelease(x, y, timeHeld)
  if self.action and self:inBounds(x, y) then
    -- first argument non-self of action is the input source to accomodate inputs via controllers from different players
    self:action(input.mouse, timeHeld)
    self:onAction()
  end
end

function Button:onAction()
  GAME.theme:playValidationSfx()
end

---@param cursor Cursor
---@param dt number
function Button:receiveInputs(cursor, dt)
  local input = cursor.keyInput
  if input.isDown["MenuSelect"] then
    -- these are always called together but the separation is (an optional) semantic one for cases where the action can be fully independent of the UI
    self:action(input)
    self:onAction()
    -- this is a really stupid way to make sure you can activate back buttons with escape
  elseif input.isDown["MenuEsc"] then
    self:action(input)
  end
end

function Button:drawBackground()
  if self.action and self:isHovered() then
    GraphicsUtil.setColor(self.hoveredBackgroundColor)
  else
    GraphicsUtil.setColor(self.backgroundColor)
  end
  GraphicsUtil.drawRectangle("fill", 0, 0, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawOutline()
  GraphicsUtil.setColor(self.outlineColor)
  GraphicsUtil.drawRectangle("line", 0, 0, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button