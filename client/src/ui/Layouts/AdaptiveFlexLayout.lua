local PATH = (...):gsub('%.[^%.]+$', '')
local VerticalFlexLayout = require(PATH ..".VerticalFlexLayout")
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")

---@class AdaptiveFlexLayout : FlexLayout
local AdaptiveFlexLayout = setmetatable({}, {__index = HorizontalFlexLayout})

function AdaptiveFlexLayout.resize(uiElement, width, height)
  local mt = getmetatable(AdaptiveFlexLayout)
  if width and height then
    if width < height and mt.__index ~= VerticalFlexLayout then
      mt.__index = VerticalFlexLayout
    elseif height < width and mt.__index ~= HorizontalFlexLayout then
      mt.__index = HorizontalFlexLayout
    end
  end

  uiElement.layout.updateWidths(uiElement, width)

  -- transform width to height for width-to-height supporting uiElements based on the width pass
  uiElement:setMinHeightForWidth()

  uiElement.layout.updateHeights(uiElement, height)

  uiElement.layout.positionChildren(uiElement)

  if uiElement.onResize then
    uiElement:onResize()
  end
end

return AdaptiveFlexLayout