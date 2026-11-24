local PATH = (...):gsub('%.[^%.]+$', '')
local UIElement = require(PATH .. ".UIElement")
local Layout = require(PATH .. ".Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

local NO_SIZING = {}

-- Returns the width of the text's widest word in the font, the narrowest the text wraps to
---@param font love.Font
---@param text string
---@return number
local function widestWord(font, text)
  local widest = 0
  for word in text:gmatch("%S+") do
    widest = math.max(widest, font:getWidth(word))
  end
  return widest
end

---@class LabelOptions : UiElementOptions
---@field text string The raw text or localization key
---@field translate boolean? Whether the game looks for a localization for text or not
---@field replacements string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field fontSize integer? The size of the font
---@field wrapWidth number? wraps the text, the label being at most this wide with its padding: its sizing.horizontal.max
---@field textAlign ("left" | "center" | "right")? how wrapped lines are aligned within the label, left if not given
---@field padding number? Uniform padding on all sides in pixels
---@field paddingTop number? Top padding in pixels
---@field paddingRight number? Right padding in pixels
---@field paddingBottom number? Bottom padding in pixels
---@field paddingLeft number? Left padding in pixels
---@field textColor table? List of red, green, blue, and alpha color for text

-- Text, sized by the layout to fit it unless its sizing is fixed. Text that wraps is laid out again at the width the
-- layout gives it, which is at most its wrap width.
---@class Label : UiElement
---@field text string The raw text or localization key
---@field translate boolean Whether the game looks for a localization for text or not
---@field replacementTable string[]? Additional strings to perform string format on a localized key with parts marked for replacement
---@field shownText string the text shown, translated when the label translates
---@field fontSize integer The size of the font
---@field wraps boolean true for text that wraps at the label's width
---@field textAlign ("left" | "center" | "right") how wrapped lines are aligned within the label
---@field fillColors table? List of red, green, blue, and alpha color for fill, no fill if nil
---@field strokeColors table? List of red, green, blue, and alpha color for stroke, no stroke if nil
---@field textColor table? List of red, green, blue, and alpha color for text
---@field drawable love.TextBatch Cached love.TextBatch for redrawing
---@field contentWidth number the width of the text on one line, or wrapped at its width cap, with the padding
---@field smallestWidth number the narrowest the text wraps to, with the padding
---@field contentHeight number the height of the laid out text with the padding
---@field formattedWidth number? the label's width the text was last laid out at, nil for text that doesn't wrap
---@field paddingTop number Top padding in pixels
---@field paddingRight number Right padding in pixels
---@field paddingBottom number Bottom padding in pixels
---@field paddingLeft number Left padding in pixels
---@overload fun(options: LabelOptions): Label
local Label = class(
  function(self, options)
    self.textAlign = options.textAlign or "left"
    self.wraps = options.wrapWidth ~= nil
    self.fontSize = options.fontSize or GraphicsUtil.fontSize
    local padding = options.padding or 0
    self.paddingTop = options.paddingTop or padding
    self.paddingRight = options.paddingRight or padding
    self.paddingBottom = options.paddingBottom or padding
    self.paddingLeft = options.paddingLeft or padding
    self.textColor = options.textColor
    if options.wrapWidth then
      self:limitWidth(options.wrapWidth)
    end

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

-- Caps the label's width, its padding included, through its width sizing; a fixed width is left as it is
---@param most number?
function Label:limitWidth(most)
  local sizing = self.layoutRules.sizing or NO_SIZING
  local width = sizing.horizontal or Layout.FIT
  if width.type ~= "fixed" and width.max ~= most then
    self:setLayoutRule("sizing", {horizontal = {type = width.type, min = width.min, max = most}, vertical = sizing.vertical})
  end
end

-- Wraps the text at the label's width, which is at most the wrap width
---@param wrapWidth number the widest the label is with its padding
---@param textAlign ("left" | "center" | "right")? how the wrapped lines are aligned, unchanged if not given
function Label:setWrap(wrapWidth, textAlign)
  self.wraps = true
  self.textAlign = textAlign or self.textAlign
  self:limitWidth(wrapWidth)
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

-- Lays the text out at the label's current width and measures it, marking the layout dirty if its measure changed
function Label:refreshFormatting()
  if self.translate then
    self.shownText = loc(self.text, unpack(self.replacementTable))
  else
    self.shownText = self.text
  end
  self:formatAt(self:getCurrentWidth())
  self:measureText()
end

---@return number? # the width wrapping text is laid out at now, with the padding: the last layout's, or its width cap
--- before its first layout; nil for text that doesn't wrap
function Label:getCurrentWidth()
  if not self.wraps then
    return nil
  end
  if self.sizedWidth then
    return self:getInnerWidth(self.sizedWidth)
  end
  return self:getWidthCap()
end

---@return number? # the widest the label's width sizing lets it be with its padding, nil without a cap
function Label:getWidthCap()
  local sizing = self.layoutRules.sizing
  return sizing and sizing.horizontal and sizing.horizontal.max
end

-- The width the layout leaves the text and its padding inside the label's layout padding, which a label rarely has
---@param width number the label's width
---@return number
function Label:getInnerWidth(width)
  local padding = self.layoutRules.padding
  if padding then
    return width - (padding.left or 0) - (padding.right or 0)
  end
  return width
end

-- Lays the text out at the width, its padding included: wrapped, or on one line without a width
---@param width number?
function Label:formatAt(width)
  if self.wraps and width then
    self.drawable:setf(self.shownText, math.max(0, width - self.paddingLeft - self.paddingRight), self.textAlign)
  else
    self.drawable:set(self.shownText)
  end
  self.formattedWidth = width
end

-- Measures the text with the padding, marking the layout dirty if the measure changed. Wrapping text with a width cap
-- is as wide as its widest line wrapped at the cap.
function Label:measureText()
  local paddingX = self.paddingLeft + self.paddingRight
  local width, smallest
  if self.wraps then
    local font = self.drawable:getFont()
    local cap = self:getWidthCap()
    if cap then
      width = font:getWrap(self.shownText, math.max(0, cap - paddingX)) + paddingX
    else
      width = font:getWidth(self.shownText) + paddingX
    end
    smallest = math.min(width, widestWord(font, self.shownText) + paddingX)
  else
    width = self.drawable:getWidth() + paddingX
    smallest = width
  end
  local height = self.drawable:getHeight() + self.paddingTop + self.paddingBottom
  if width ~= self.contentWidth or smallest ~= self.smallestWidth or height ~= self.contentHeight then
    self.contentWidth, self.smallestWidth, self.contentHeight = width, smallest, height
    self:markLayoutDirty()
  end
end

---@return number # the width of the text with the padding, which the layout fits the label to
---@return number # the narrowest the text wraps to with the padding, which a flow may shrink the label to
function Label:measureContentWidth()
  return self.contentWidth, self.smallestWidth
end

-- Lays wrapping text out at the width
---@param width number
---@return number # the height of the text with the padding at the width
function Label:measureContentHeight(width)
  if self.wraps then
    if width ~= self.formattedWidth then
      self:formatAt(width)
    end
    self.contentHeight = self.drawable:getHeight() + self.paddingTop + self.paddingBottom
  end
  return self.contentHeight
end

-- Lays wrapping text out again at the label's new width
function Label:onResize()
  local width = self:getCurrentWidth()
  if width and width ~= self.formattedWidth then
    self:formatAt(width)
  end
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
  local width, height = self.layoutRect.width, self.layoutRect.height
  if self.fillColors then
    local fill = self.fillColors
    GraphicsUtil.drawRectangle("fill", 0, 0, width, height, fill[1], fill[2], fill[3], fill[4])
  end
  if self.strokeColors then
    local stroke = self.strokeColors
    GraphicsUtil.drawRectangle("line", 0, 0, width, height, stroke[1], stroke[2], stroke[3], stroke[4])
  end

  local textX = self.paddingLeft
  local textY = self.paddingTop
  if self.textColor then
    GraphicsUtil.setColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4])
    GraphicsUtil.draw(self.drawable, math.round(textX), math.round(textY))
    GraphicsUtil.setColor(1, 1, 1, 1)
  else
    GraphicsUtil.drawClearText(self.drawable, math.round(textX), math.round(textY))
  end
end

return Label
