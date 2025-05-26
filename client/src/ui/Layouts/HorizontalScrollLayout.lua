local PATH = (...):gsub('%.[^%.]+$', '')
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")
local util = require("common.lib.util")

---@class HorizontalScrollLayout : HorizontalFlexLayout
local HorizontalScrollLayout = setmetatable({}, {__index = HorizontalFlexLayout})

function HorizontalScrollLayout.getMinWidth(uiElement)
  return util.bound(uiElement.minWidth, HorizontalFlexLayout.getMinWidth(uiElement), uiElement.maxWidth)
end

function HorizontalScrollLayout.getPreferredWidth(uiElement)
  return util.bound(uiElement.minWidth, HorizontalFlexLayout.getPreferredWidth(uiElement), uiElement.maxWidth)
end

function HorizontalScrollLayout.finalizeChildrenWidths(uiElement)
  -- no growing because we scroll in this direction
end

---@param uiElement UiElement
function HorizontalScrollLayout.positionChildren(uiElement)
  local x = uiElement.padding
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.x = x

      if uiElement.vAlign == "top" then
        child.y = uiElement.padding
      elseif uiElement.vAlign == "center" then
        child.y = (uiElement.height - child.height) / 2
      elseif uiElement.vAlign == "bottom" then
        child.y = (uiElement.height - child.height) - uiElement.padding
      end
      child.x = math.round(child.x)
      child.y = math.round(child.y)
      x = x + uiElement.childGap + child.width
    end
  end

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.layout.positionChildren(child)
    end
  end
end

return HorizontalScrollLayout