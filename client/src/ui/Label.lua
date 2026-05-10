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
---@field padding number? Uniform padding on all sides in pixels
---@field paddingTop number? Top padding in pixels
---@field paddingRight number? Right padding in pixels
---@field paddingBottom number? Bottom padding in pixels
---@field paddingLeft number? Left padding in pixels
---@field textColor table? List of red, green, blue, and alpha color for text

---@class Label : UiElement
---@field text string The raw text or localization key
---@field translate boolean Whether the game looks for a localization for text or not
---@field replacementTable string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer The size of the font
---@field wrapWidth? number the number of pixels to go before wrapping
---@field font love.Font Cached font for recreating the love.TextBatch on changes
---@field fillColors table? List of red, green, blue, and alpha color for fill, no fill if nil
---@field strokeColors table? List of red, green, blue, and alpha color for stroke, no stroke if nil
---@field textColor table? List of red, green, blue, and alpha color for text
---@field drawable love.TextBatch Cached love.TextBatch for redrawing
---@field autoSizeWidth boolean true if the text should change the width
---@field autoSizeHeight boolean true if the text should change the height
---@field paddingTop number Top padding in pixels
---@field paddingRight number Right padding in pixels
---@field paddingBottom number Bottom padding in pixels
---@field paddingLeft number Left padding in pixels
---@overload fun(options: LabelOptions): Label
local Label = class(
  function(self, options)
    self.hAlign = options.hAlign or "left"
    self.vAlign = options.vAlign or "top"
    self.hFill = options.hFill or false
    self.autoSizeWidth = self.width == 0
    self.autoSizeHeight = self.height == 0
    self.wrapWidth = options.wrapWidth or nil
    self.fontSize = options.fontSize or GraphicsUtil.fontSize
    local padding = options.padding or 0
    self.paddingTop = options.paddingTop or padding
    self.paddingRight = options.paddingRight or padding
    self.paddingBottom = options.paddingBottom or padding
    self.paddingLeft = options.paddingLeft or padding
    self.textColor = options.textColor

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
  else
    self.text = ""
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

function Label:setPadding(padding, paddingTop, paddingRight, paddingBottom, paddingLeft)
  if padding then
    self.paddingTop = paddingTop or padding
    self.paddingRight = paddingRight or padding
    self.paddingBottom = paddingBottom or padding
    self.paddingLeft = paddingLeft or padding
  else
    self.paddingTop = paddingTop or self.paddingTop
    self.paddingRight = paddingRight or self.paddingRight
    self.paddingBottom = paddingBottom or self.paddingBottom
    self.paddingLeft = paddingLeft or self.paddingLeft
  end
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

function Label:setTextColor(red, green, blue, alpha)
  self.textColor = {red, green, blue, alpha}
end

function Label:refreshFormatting()
  local text = self.text

  if self.translate then
    text = loc(self.text, unpack(self.replacementTable))
  end

  local contentWidth = self.wrapWidth
  if contentWidth and (self.paddingLeft + self.paddingRight) > 0 then
    contentWidth = contentWidth - self.paddingLeft - self.paddingRight
  end

  if contentWidth then
    self.drawable:setf(text, contentWidth, self.hAlign)
  else
    self.drawable:set(text)
  end
  
  if self.autoSizeWidth then
    self.width = self.drawable:getWidth() + self.paddingLeft + self.paddingRight
  end

  if self.autoSizeHeight then
    self.height = self.drawable:getHeight() + self.paddingTop + self.paddingBottom
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
  
  local textX = self.x + self.paddingLeft
  local textY = self.y + self.paddingTop
  local color = self.textColor or {1, 1, 1, 1}
  GraphicsUtil.setColor(color[1], color[2], color[3], color[4])
  GraphicsUtil.draw(self.drawable, math.round(textX), math.round(textY))
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return Label