local import = require("common.lib.import")
local Button = import("./Button")
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
  self.label.hAlign = "left"
  self.label.vAlign = "top"
  --self.label
  self:addChild(self.label)

  -- stretch to fit text+icon
  local width, height = self.label:getEffectiveDimensions()
  self.height = math.max(math.max(self.iconSize, height) + self.HEIGHT_PADDING * 2, self.height)

  -- reposition label based on new stretch
  if self.width > width + self.WIDTH_PADDING * 3 + self.iconSize then
    self.label.x = (self.width - (width + self.WIDTH_PADDING)) / 2 + self.WIDTH_PADDING
  else
    self.width = width + self.WIDTH_PADDING * 3 + self.iconSize
    self.label.x = self.width - width -self.WIDTH_PADDING
  end
  self.label.y = self.height - height - self.HEIGHT_PADDING
end,
Button)

function IconTextButton:drawChildren()
  local imageWidth, imageHeight = self.icon:getDimensions()
  local scale = math.min(self.iconSize / imageWidth, self.iconSize / imageHeight)
  GraphicsUtil.draw(self.icon, self.label.x - self.WIDTH_PADDING - self.iconSize, self.label.y + (self.label.height - self.iconSize) / 2, 0, scale, scale)

  self.label:draw()
end

return IconTextButton