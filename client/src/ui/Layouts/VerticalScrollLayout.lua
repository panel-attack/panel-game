local PATH = (...):gsub('%.[^%.]+$', '')
local VerticalFlexLayout = require(PATH ..".VerticalFlexLayout")
local util = require("common.lib.util")

---@class VerticalScrollLayout : VerticalFlexLayout
local VerticalScrollLayout = setmetatable({}, {__index = VerticalFlexLayout})

function VerticalScrollLayout.getMinHeight(uiElement)
  return util.bound(uiElement.minHeight, VerticalFlexLayout.getMinHeight(uiElement), uiElement.maxHeight)
end

function VerticalScrollLayout.growChildrenHeight(uiElement)
  -- no growing because we scroll in this direction
end

---@param uiElement UiElement
function VerticalScrollLayout.positionChildren(uiElement)
  local y = uiElement.padding
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.y = y

      if child.hAlign == "left" then
        child.x = uiElement.padding
      elseif child.hAlign == "center" then
        child.x = (uiElement.width - child.width) / 2
      elseif child.hAlign == "right" then
        child.x = (uiElement.width - child.width) - uiElement.padding
      end
      child.x = math.round(child.x)
      child.y = math.round(child.y)
      y = y + uiElement.childGap + child.height
    end
  end

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.layout.positionChildren(child)
    end
  end
end

return VerticalScrollLayout