local import = require("common.lib.import")
local Button = import("./Button")
local Layout = import("./Layout")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class IconTextButtonOptions : ButtonOptions
---@field icon love.Texture
---@field iconSize integer
---@field label Label

---@class IconTextButton : Button
---@operator call(IconTextButtonOptions): IconTextButton
local IconTextButton = class(
---@param self IconTextButton
---@param options IconTextButtonOptions
function(self, options)
  self.icon = options.icon
  self.iconSize = options.iconSize

  self.label = options.label
  self.label.textAlign = "left"
  self.label:refreshFormatting()

  -- stretch to fit text+icon
  local labelWidth, labelHeight = self.label:getEffectiveDimensions()
  local width = Layout.fixedLength(self.layoutRules, "horizontal") or 0
  local height = math.max(math.max(self.iconSize, labelHeight) + self.HEIGHT_PADDING * 2,
                          Layout.fixedLength(self.layoutRules, "vertical") or 0)

  -- place the label based on the new stretch, the icon going left of it
  local labelX
  if width > labelWidth + self.WIDTH_PADDING * 3 + self.iconSize then
    labelX = (width - (labelWidth + self.WIDTH_PADDING)) / 2 + self.WIDTH_PADDING
  else
    width = labelWidth + self.WIDTH_PADDING * 3 + self.iconSize
    labelX = width - labelWidth - self.WIDTH_PADDING
  end
  local labelY = height - labelHeight - self.HEIGHT_PADDING
  self:setLayoutRule("sizing", Layout.fixedSize(width, height))
  self.label:setLayoutRule("floating", Layout.floatAt("leftTop", labelX, labelY))
  self:addChild(self.label)
end,
Button)

function IconTextButton:drawChildren()
  local imageWidth, imageHeight = self.icon:getDimensions()
  local scale = math.min(self.iconSize / imageWidth, self.iconSize / imageHeight)
  local labelRect = self.label.layoutRect
  local iconX = labelRect.x - self.WIDTH_PADDING - self.iconSize
  GraphicsUtil.draw(self.icon, iconX, labelRect.y + (labelRect.height - self.iconSize) / 2, 0, scale, scale)

  self.label:draw()
end

return IconTextButton
