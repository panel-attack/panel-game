local import = require("common.lib.import")
local UIElement = import("./UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")
local addCursorInteractionInterface = import("./CursorInteractable")

---@class ButtonOptions : UiElementOptions
---@field backgroundColor number[]?
---@field outlineColor number[]?
---@field onClick fun(button: Button?, input: table?, timeHeld: number?)?
---@field receiveInputs fun(button: Button, cursor: Cursor, dt: number?)?

---@class Button : UiElement, CursorInteractable
---@operator call(ButtonOptions): Button
---@field backgroundColor number[]
---@field outlineColor number []
---@field onClick fun(button: Button?, input: table?, timeHeld: number?)
local Button = class(
  function(self, options)
    self.hoveredBackgroundColor = {.5, .5, .5, .7}
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}

    -- callbacks
    self.onClick = options.onClick or function()
      GAME.theme:playValidationSfx()
    end

    addCursorInteractionInterface(self, options.receiveInputs or self.receiveInputs)
  end,
  UIElement
)

Button.TYPE = "Button"

function Button:onTouch(x, y)
end

function Button:onRelease(x, y, timeHeld)
  if self:inBounds(x, y) then
    -- first argument non-self of onClick is the input source to accomodate inputs via controllers from different players
    self:onClick(input.mouse, timeHeld)
  end
end

---@param cursor Cursor
---@param dt number
function Button:receiveInputs(cursor, dt)
  local input = cursor.keyInput
  if input.isDown["MenuSelect"] then
    self:onClick(input)
    -- this is a really stupid way to make sure you can activate back buttons with escape
  elseif input.isDown["MenuEsc"] then
    self:onClick(input)
  end
end

function Button:drawBackground()
  if self:isHovered() then
    GraphicsUtil.setColor(self.hoveredBackgroundColor)
  else
    GraphicsUtil.setColor(self.backgroundColor)
  end
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawOutline()
  GraphicsUtil.setColor(self.outlineColor)
  GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button