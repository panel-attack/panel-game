local PATH = (...):gsub('%.[^%.]+$', '')
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")
local util = require("common.lib.util")

---@class HorizontalWrapLayout : HorizontalFlexLayout
local HorizontalWrapLayout = setmetatable({}, {__index = HorizontalFlexLayout})

function HorizontalWrapLayout.getMinWidth(uiElement)
  return util.bound(uiElement.minWidth, uiElement:getBaseWidth(), uiElement.maxWidth)
end

---@param uiElement UiElement
function HorizontalWrapLayout.getMinHeight(uiElement)
  local h = uiElement.padding * 2
  local maxHeight = 0
  uiElement.tempRows = {}

  local childrenInCurrentRow = 0
  local rowCount = 1
  local width = uiElement.padding
  for i, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxHeight = math.max(maxHeight, child.newHeight)
      if width + child.newWidth + uiElement.padding + childrenInCurrentRow * uiElement.childGap > uiElement.width then
        uiElement.tempRows[rowCount] = maxHeight
        rowCount = rowCount + 1
        width = uiElement.padding + child.newWidth
        childrenInCurrentRow = 1
        maxHeight = child.newHeight
      else
        childrenInCurrentRow = childrenInCurrentRow + 1
        width = width + child.newWidth
      end
      child.tempRow = rowCount
    end
  end

  uiElement.tempRows[rowCount] = maxHeight
  h = h + (#uiElement.tempRows - 1) * uiElement.childGap
  for i = 1, #uiElement.tempRows do
    h = h + uiElement.tempRows[i]
  end

  return h
end

---@param uiElement UiElement
function HorizontalWrapLayout.positionChildren(uiElement)
  if #uiElement.tempRows == 1 then
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