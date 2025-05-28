local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local HorizontalWrapLayout = require(PATH .. ".Layouts.HorizontalWrapLayout")

---@class LabelOptions : UiElementOptions
---@field id string? The localization key; nil if there should be no translation
---@field text string? The raw text; ignored if there is a localization key
---@field replacements string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer? The size of the font
---@field wrap boolean? If the font should wrap around

---@class Label : UiElement
---@operator call(LabelOptions): Label
---@field id string? The localization key
---@field replacementTable string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field text string The raw text or localization key
---@field font love.Font Cached font for recreating the love.Text on changes
---@field fontSize FontSize The size of the font
---@field wrap boolean If the font should wrap around
---@overload fun(options: LabelOptions): Label
---@type Label
local Label = class(
  function(self, options)
    self.id = options.id

    if self.id then
      self.replacementTable = options.replacements or {}
      self.text = loc(self.id, unpack(self.replacementTable))
    else
      self.text = options.text or ""
    end

    self.hAlign = options.hAlign or "center"
    self.vAlign = options.vAlign or "center"

    self.fontSize = options.fontSize or "normal"
    local font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)

    if options.wrap ~= nil then
      self.wrap = options.wrap
    else
      self.wrap = true
    end
    -- min sizes are set with this function
    self:recalculateSizes()

    self.width = options.width or self.preferredWidth
    self.maxWidth = options.maxWidth or math.huge
    self.height = options.height or font:getHeight()
    self.maxHeight = options.maxHeight or math.huge

    self.hFill = true
    self.vFill = false
  end,
  UIElement
)

Label.TYPE = "Label"
Label.layout = HorizontalWrapLayout

function Label:recalculateSizes()
  local font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)
  local words = self.text:split()
  local maxWordWidth = font:getWidth(words[1])
  for i = 2, #words do
    maxWordWidth = math.max(maxWordWidth, font:getWidth(words[i]))
  end

  self.minHeight = font:getHeight()
  self.preferredWidth = font:getWidth(self.text)
  if self.wrap then
    self.minWidth = maxWordWidth
  else
    self.minWidth = self.preferredWidth
  end
end

---@param fontSize FontSize
function Label:setFontSize(fontSize)
  self.fontSize = fontSize
  self:recalculateSizes()
end

---@param id string
---@param replacements table?
function Label:setId(id, replacements)
  self.id = id
  self.replacementTable = replacements or {}
  self.text = loc(self.id, unpack(self.replacementTable))
  self:recalculateSizes()
end

---@param text string
function Label:setText(text)
  self.text = text
  self:recalculateSizes()
end

function Label:refreshLocalization()
  if self.id then
    self.text = loc(self.id, unpack(self.replacementTable))
  end
  self:recalculateSizes()
end

function Label:drawSelf()
  GraphicsUtil.printf(self.text, self.x, self.y, self.width, self.hAlign, nil, nil, self.fontSize)
end

function Label:getPreferredWidth()
  return self.preferredWidth
end

function Label:getMinHeight()
  return GraphicsUtil.getTextHeightForWidth(self.fontSize, self.text, self.width, self.hAlign)
end

function Label:addChild()
  error("Labels cannot have children")
end

return Label