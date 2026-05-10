local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")

---@class ButtonOptions : UiElementOptions
---@field backgroundColor number[]?
---@field outlineColor number[]?
---@field onClick fun(button: Button?, input: table?, timeHeld: number?)?

---@class Button : UiElement
---@field backgroundColor number[]
---@field outlineColor number []
---@field onClick fun(button: Button?, input: table?, timeHeld: number?)?
---@field currentlyPressed boolean
---@field selected boolean
local Button = class(
  function(self, options)
    self.backgroundColor = options.backgroundColor or {1.0, 0.08, 0.58, 0.8}
    self.outlineColor = options.outlineColor or {1.0, 0.08, 0.58, 1.0}
    self.currentlyPressed = false
    self.selected = false

    -- callbacks
    self.onClick = options.onClick
  end,
  UIElement
)

Button.TYPE = "Button"
Button.WIDTH_PADDING = 16
Button.HEIGHT_PADDING = 10
Button.CORNER_RADIUS = 32
Button.BORDER_WIDTH = 4

function Button:onClick()
  GAME.theme:playValidationSfx()
end

function Button:onTouch(x, y)
  self.currentlyPressed = true
end

function Button:onRelease(x, y, timeHeld)
  if self:inBounds(x, y) then
    -- first argument non-self of onClick is the input source to accomodate inputs via controllers from different players
    self:onClick(input.mouse, timeHeld)
  end
  self.currentlyPressed = false
end

function Button:setSelected(selected)
  self.selected = selected
end

function Button:receiveInputs(input)
  if input.isDown["MenuSelect"] then
    self:onClick(input)
    -- this is a really stupid way to make sure you can activate back buttons with escape
  elseif input.isDown["MenuEsc"] then
    self:onClick(input)
  end
end

function Button:drawBackground()
  if self.backgroundColor[4] > 0 then
    local alpha = self.backgroundColor[4]
    if self.currentlyPressed or self.selected then
      alpha = 1.0
    end
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height,
      self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], alpha,
      self.CORNER_RADIUS, self.CORNER_RADIUS)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
end

function Button:drawOutline()
  local outlineColor = self.outlineColor

  if self.selected then
    outlineColor = {1.0, 0.84, 0.0, 1.0}
  end

  for w = 1, self.BORDER_WIDTH do
    GraphicsUtil.drawRectangle("line", self.x - w, self.y - w, self.width + 2*w, self.height + 2*w,
      outlineColor[1], outlineColor[2], outlineColor[3], outlineColor[4],
      self.CORNER_RADIUS, self.CORNER_RADIUS)
  end

  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button