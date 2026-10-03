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
---@field onClick fun(button: Button?, input: table?, timeHeld: number?)
---@field currentlyPressed boolean
local Button = class(
  function(self, options)
    self.backgroundColor = options.backgroundColor or {.3, .3, .3, .7}
    self.outlineColor = options.outlineColor or {.5, .5, .5, .7}
    self.currentlyPressed = false

    -- callbacks
    self.onClick = options.onClick
  end,
  UIElement
)

Button.TYPE = "Button"
Button.WIDTH_PADDING = 3
Button.HEIGHT_PADDING = 3

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
    if self.currentlyPressed then 
      GraphicsUtil.setColor(self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], 1)
    else
      GraphicsUtil.setColor(self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], self.backgroundColor[4])
    end
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height)
    GraphicsUtil.setColor(1, 1, 1, 1)
  end
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