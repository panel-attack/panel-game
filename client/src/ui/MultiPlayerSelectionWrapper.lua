local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local Label = require(PATH .. ".Label")
local Layout = require(PATH .. ".Layout")
local StackPanel = require(PATH .. ".StackPanel")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- forms a layer of abstraction between a player specific selector (e.g. GridCursor) and UiElements that exist per player
-- the MultiPlayerSelectionWrapper displays the UiElements of all players but upon selection only redirects inputs to the 
-- player that owns the input method
local MultiPlayerSelectionWrapper = class(function(wrapper, options)
  wrapper:setFocusable(true)
  wrapper.activeElement = nil
  wrapper.wrappedElements = {}

  wrapper.TYPE = "MultiPlayerSelectionWrapper"
end,
StackPanel)

function MultiPlayerSelectionWrapper:addElement(uiElement, player)
  self.wrappedElements[player] = uiElement
  StackPanel.addElement(self, uiElement)
end

function MultiPlayerSelectionWrapper:insertElementAtIndex(uiElement, index, player)
  self:addElement(uiElement, player)
  self:moveChild(uiElement, index)
end

---Passes focus on to the element of the player the input source belongs to
---@param inputSource InputSource
function MultiPlayerSelectionWrapper:onFocus(inputSource)
  self:forwardFocus(self.wrappedElements[inputSource.player], inputSource)
end

-- the title centered across the wrapper above the elements it stacks in a column
local TITLE_ROW_RULES = {sizing = {horizontal = Layout.GROW}, childAlignment = Layout.CENTER_HORIZONTALLY}

local COLORS = {
  border = {1.0, 0.8, 0.1, 0.4}, -- Bright gold border  
  white = {1, 1, 1, 1}
}
function MultiPlayerSelectionWrapper:drawSelf()
  if self:hasFocus() then
    love.graphics.setLineWidth(6)
    GraphicsUtil.setColor(COLORS.border)
    love.graphics.rectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
    GraphicsUtil.setColor(COLORS.white)
    love.graphics.setLineWidth(1)
  end
end

function MultiPlayerSelectionWrapper:setTitle(string)
  if self.alignment == "top" then
    self.title = Label({text = string})
    local titleRow = UiElement({layoutRules = TITLE_ROW_RULES})
    titleRow:addChild(self.title)
    StackPanel.insertElementAtIndex(self, titleRow, 1)
  else
    self.title = Label({text = string, layoutRules = {floating = Layout.floatAt("centerTop")}})
    self:addChild(self.title)
  end
end

return MultiPlayerSelectionWrapper