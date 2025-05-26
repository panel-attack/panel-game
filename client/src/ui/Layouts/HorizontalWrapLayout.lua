local PATH = (...):gsub('%.[^%.]+$', '')
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")
local util = require("common.lib.util")

---@class HorizontalWrapLayout : HorizontalFlexLayout
local HorizontalWrapLayout = setmetatable({}, {__index = HorizontalFlexLayout})

function HorizontalWrapLayout.resize(uiElement, width, height)
  HorizontalFlexLayout.resize(uiElement, width, height)
end

function HorizontalWrapLayout.getMinWidth(uiElement)
  local w = uiElement.padding * 2
  local maxWidth = 0

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxWidth = math.max(maxWidth, child.newWidth, child.minWidth)
    end
  end

  return w + maxWidth
end

---@param uiElement UiElement
function HorizontalWrapLayout.getMinHeight(uiElement)
  return uiElement:getMinHeight()
end

---@param uiElement UiElement
function HorizontalWrapLayout.positionChildren(uiElement)
  if not uiElement.tempRows or #uiElement.tempRows == 1 then
    HorizontalFlexLayout.positionChildren(uiElement)
  else
    local x = uiElement.padding
    local y = uiElement.padding
    local row = 1
    for _, child in ipairs(uiElement.children) do
      if child.isVisible then
        if child.tempRow > row then
          x = uiElement.padding
          y = y + uiElement.tempRows[row] + uiElement.childGap
          row = child.tempRow
        end

        child.x = math.round(x)
        child.y = math.round(y)
        x = x + uiElement.childGap + child.width
        child.tempRow = nil
      end
    end
    uiElement.tempRows = nil
  end

end

return HorizontalWrapLayout