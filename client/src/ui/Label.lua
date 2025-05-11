local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class LabelOptions : UiElementOptions
---@field id string? The localization key; nil if there should be no translation
---@field text string? The raw text; ignored if there is a localization key
---@field replacements string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer? The size of the font
---@field wrap boolean? If the font should wrap around
---@field wrapRatio number? By which % of the unwrapped text the text should wrap

---@class Label : UiElement
---@field id string? The localization key
---@field replacementTable string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field text string The raw text or localization key
---@field font love.Font Cached font for recreating the love.Text on changes
---@field fontSize integer The size of the font
---@field wrap boolean If the font should wrap around
---@overload fun(options: LabelOptions): Label
local Label = class(
  function(self, options)
    self.id = options.id

    if self.id then
      self.replacementTable = options.replacements or {}
      self.text = loc(self.id, unpack(self.replacementTable))
    else
      self.text = options.text or ""
    end

    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"

    self.fontSize = options.fontSize or GraphicsUtil.fontSize
    self.font = options.font or GraphicsUtil.getGlobalFontWithSize(self.fontSize)

    local totalWidth = self.font:getWidth(self.text)
    if options.wrap ~= nil then
      self.wrap = options.wrap
    else
      self.wrap = true
    end

    local words = self.text:split()
    local maxWordWidth = self.font:getWidth(words[1])
    for i = 2, #words do
      maxWordWidth = math.max(maxWordWidth, self.font:getWidth(words[i]))
    end

    if options.minWidth ~= nil then
      self.minWidth = options.minWidth
    else
      if self.wrap then
        self.minWidth = maxWordWidth
      else
        self.minWidth = totalWidth
      end
    end

    self.width = options.width or totalWidth
    self.maxWidth = options.maxWidth or math.huge
    self.minHeight = options.minHeight or self.font:getHeight()
    self.height = options.height or self.font:getHeight()

    if options.maxHeight ~= nil then
      self.maxHeight = options.maxHeight
    else
      if self.wrap then
        self.maxHeight = (#words * self.font:getHeight())
      else
        self.maxHeight = self.font:getHeight()
      end
    end

    self.hFill = true
    self.vFill = false
  end,
  UIElement
)
Label.TYPE = "Label"

function Label:setFontSize(fontSize)
  self.fontSize = fontSize
  self.font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)
  local totalWidth = self.font:getWidth(self.text)
  self.width = totalWidth
  self.maxWidth = math.huge
  if not self.wrap then
    self.minWidth = totalWidth
  end
end

function Label:refreshLocalization()
  if self.id then
    self.text = loc(self.id, unpack(self.replacementTable))
  end
  self.font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)
  local totalWidth = self.font:getWidth(self.text)
  self.width = totalWidth
  self.maxWidth = totalWidth
  if not self.wrap then
    self.minWidth = totalWidth
  end
end

function Label:drawSelf()
  love.graphics.setFont(self.font)
  love.graphics.printf(self.text, self.x, self.y, self.width, self.hAlign)
end

function Label:setMinHeightForWidth()
  local refText = GraphicsUtil.newText(self.font)
  refText:setf(self.text, self.width, self.hAlign)
  self.minHeight = refText:getHeight()
end

return Label