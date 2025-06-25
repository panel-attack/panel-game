local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class LabelOptions : UiElementOptions
---@field text string The raw text or localization key
---@field translate boolean? Whether the game looks for a localization for text or not
---@field replacements string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer? The size of the font
---@field wrapWidth? number the number of pixels to go before wrapping

---@class Label : UiElement
---@field text string The raw text or localization key
---@field translate boolean Whether the game looks for a localization for text or not
---@field replacementTable string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer The size of the font
---@field wrapWidth? number the number of pixels to go before wrapping
---@field font love.Font Cached font for recreating the love.Text on changes
---@field fillColors table? List of red, green, blue, and alpha color for fill, no fill if nil
---@field strokeColors table? List of red, green, blue, and alpha color for stroke, no stroke if nil
---@field drawable love.Text Cached love.Text for redrawing
---@field autoSizeToText boolean true if the text should change the width and height
---@overload fun(options: LabelOptions): Label
local Label = class(
  function(self, options)
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"
    self.hFill = options.hFill or false
    self.autoSizeToText = (self.width == 0 or self.height == 0)
    self.wrapWidth = options.wrapWidth or nil
    self.fontSize = options.fontSize or GraphicsUtil.fontSize

    self:setText(options.text, options.replacements, options.translate)
  end,
  UIElement
)
Label.TYPE = "Label"

function Label:getEffectiveDimensions()
  return self.drawable:getDimensions()
end

function Label:setText(text, replacementTable, translate)
  if text == self.text and replacementTable == self.replacementTable and self.translate == translate then
    return
  end

  -- whether we should translate the label or not
  if translate ~= nil then
    self.translate = translate
  elseif self.translate == nil then
    self.translate = true
  end

  if replacementTable then
    -- list of parameters for translating the label (e.g. numbers/names to replace placeholders with)
    self.replacementTable = replacementTable
  elseif not self.replacementTable then
    self.replacementTable = {}
  end

  if text then
    self.text = text
  end

  if self.translate then
    -- always need a new text cause the font might have changed
    self.drawable = GraphicsUtil.newText(GraphicsUtil.getGlobalFontWithSize(self.fontSize), loc(self.text, unpack(self.replacementTable)))
  else
    if not self.drawable then
      self.drawable = GraphicsUtil.newText(GraphicsUtil.getGlobalFontWithSize(self.fontSize), self.text)
    end
  end

  self:refreshFormatting()
end

-- Sets the wrapping and alignment of the text
--@field wrapWidth number the number of pixels to go before wrapping
--@field hAlign String left center or right
function Label:setWrap(wrapWidth, hAlign)
  self.wrapWidth = wrapWidth
  self.hAlign = hAlign or self.hAlign
  self:refreshFormatting()
end

function Label:setFillColors(red, green, blue, alpha)
  self.fillColors = {red, green, blue, alpha}
  self:refreshFormatting()
end

function Label:setStrokeColors(red, green, blue, alpha)
  self.strokeColors = {red, green, blue, alpha}
  self:refreshFormatting()
end

function Label:refreshFormatting()
  local text = self.text

  if self.translate then
    text = loc(self.text, unpack(self.replacementTable))
  end

  if self.wrapWidth then
    self.drawable:setf(text, self.wrapWidth, self.hAlign)
  else
    self.drawable:set(text)
  end
  if self.autoSizeToText then
    self.width = self.drawable:getWidth()
    self.height = self.drawable:getHeight()
  end
end

function Label:onResize()
  self:refreshFormatting()
end

function Label:refreshLocalization()
  if self.translate then
    local font = GraphicsUtil.getGlobalFontWithSize(self.fontSize)

    -- always need a new text cause the font might have changed
    self.drawable = GraphicsUtil.newText(font, loc(self.text, unpack(self.replacementTable)))
    self:refreshFormatting()
  end
end

function Label:drawSelf()
  if self.fillColors then
    GraphicsUtil.drawRectangle("fill", self.x, self.y, self.width, self.height, self.fillColors[1], self.fillColors[2], self.fillColors[3], self.fillColors[4])
  end
  if self.strokeColors then
    GraphicsUtil.drawRectangle("line", self.x, self.y, self.width, self.height, self.strokeColors[1], self.strokeColors[2], self.strokeColors[3], self.strokeColors[4])
  end
  GraphicsUtil.drawClearText(self.drawable, math.round(self.x), math.round(self.y))
end

return Label