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
  local bgColor = (self.selected or self.currentlyPressed)
    and GAME.theme.colors.menuSelectedBackgroundColor
    or  GAME.theme.colors.menuDefaultBackgroundColor
  GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height,
    bgColor[1], bgColor[2], bgColor[3], bgColor[4],
    self.CORNER_RADIUS, self.CORNER_RADIUS)
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawOutline()
  local borderColor = self.selected
    and GAME.theme.colors.menuSelectedBorderColor
    or  GAME.theme.colors.menuDefaultBorderColor
  for w = 0, self.BORDER_WIDTH - 1 do
    GraphicsUtil.drawRectangle("line", self.x + w, self.y + w, self.width - 2*w, self.height - 2*w,
      borderColor[1], borderColor[2], borderColor[3], borderColor[4],
      self.CORNER_RADIUS, self.CORNER_RADIUS)
  end
  GraphicsUtil.setColor(1, 1, 1, 1)
end

function Button:drawSelf()
  self:drawBackground()
  self:drawOutline()
end

return Button