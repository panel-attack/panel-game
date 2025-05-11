local PATH = (...):gsub('%.[^%.]+$', '')
local HorizontalFlexLayout = require(PATH ..".HorizontalFlexLayout")

---@class HorizontalScrollLayout : HorizontalFlexLayout
local HorizontalScrollLayout = setmetatable({}, {__index = HorizontalFlexLayout})

---@param uiElement UiElement
function HorizontalScrollLayout.positionChildren(uiElement)
  local x = uiElement.padding
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.x = x

      if child.vAlign == "top" then
        child.y = uiElement.padding
      elseif child.vAlign == "center" then
        child.y = (uiElement.height - child.height) / 2
      elseif child.vAlign == "bottom" then
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