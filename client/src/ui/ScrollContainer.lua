local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local VERTICAL_CLIP = {vertical = true}
local HORIZONTAL_CLIP = {horizontal = true}

---@class ScrollContainerOptions : UiElementOptions
---@field scrollOrientation ("vertical" | "horizontal" | nil)

-- A container that lays its children out along its orientation and scrolls them along it when they don't fit, as every
-- element that clips does (see UIElement:setScroll), with an arrow on each side the content continues past
---@class ScrollContainer : UiElement
---@field scrollOrientation string "vertical" or "horizontal"

---@class ScrollContainer
---@overload fun(options: ScrollContainerOptions): ScrollContainer
local ScrollContainer = class(
---@param self ScrollContainer
function(self, options)
  self.scrollOrientation = options.scrollOrientation or "vertical"
  local vertical = self.scrollOrientation == "vertical"
  self:setLayoutRule("layoutDirection", vertical and "topToBottom" or "leftToRight")
  self:setLayoutRule("clip", vertical and VERTICAL_CLIP or HORIZONTAL_CLIP)
end,
UiElement)
ScrollContainer.TYPE = "ScrollContainer"
-- Draws an arrow on each side the content continues past; the children are drawn clipped to the container
function ScrollContainer:drawSelf()
  local maxX, maxY = self:getMaxScroll()
  local fontSize = GraphicsUtil.fontSize
  local width = self.layoutRect.width
  local height = self.layoutRect.height
  if self.scrollY < 0 then
    GraphicsUtil.print("^", width / 2 - fontSize / 2, -20)
  end
  if -self.scrollY < maxY then
    GraphicsUtil.print("v", width / 2 - fontSize / 2, height + 8)
  end
  if self.scrollX < 0 then
    GraphicsUtil.print("<", -20, height / 2 - fontSize / 2)
  end
  if -self.scrollX < maxX then
    GraphicsUtil.print(">", width + 8, height / 2 - fontSize / 2)
  end
end

-- Replaces the children with the element; the next layout keeps the scroll within the new content
---@param uiElement UiElement
function ScrollContainer:setContent(uiElement)
  while #self.children > 0 do
    self.children[1]:detach()
  end
  self:addChild(uiElement)
end

return ScrollContainer
