local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local Focusable = require(PATH .. ".Focusable")

--- A plain element with the main purpose of giving a container child an alignment without disrupting cursor focus
---@class PassThroughElement : UiElement, Focusable
local PassThroughElement = class(
function (self, options)
end,
UIElement)

Focusable(PassThroughElement)

function PassThroughElement:addChild(uiElement)
  if self.children[1] then
    error("A PassThroughElement can only have one child")
  end
  uiElement.yieldFocus = function()
    self.yieldFocus()
  end
  UIElement.addChild(self, uiElement)
end

function PassThroughElement:receiveInputs(inputs, dt)
  self.children[1]:receiveInputs(inputs, dt)
end


return PassThroughElement