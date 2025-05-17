local PATH = (...):gsub('%.[^%.]+$', '')
local Layout = require(PATH ..".Layout")

---@class FlexLayout : Layout
local FlexLayout = setmetatable({}, {__index = Layout})

---@param uiElement UiElement
function FlexLayout.fitSizeWidth(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.layout.fitSizeWidth then
      child.layout.fitSizeWidth(child)
    end
  end
  local w = uiElement.layout.getMinWidth(uiElement)
  uiElement.newWidth = math.max(w, uiElement:getBaseWidth())
end

---@param uiElement UiElement
function FlexLayout.fitSizeHeight(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.layout.fitSizeHeight then
      child.layout.fitSizeHeight(child)
    end
  end
  local h = uiElement.layout.getMinHeight(uiElement)
  uiElement.newHeight = math.max(h, uiElement:getBaseHeight())
end

function FlexLayout.updateWidths(uiElement, width)
  if not uiElement.newWidth then
    uiElement.layout.fitSizeWidth(uiElement)
  end
  if width then
    uiElement.width = math.max(width, uiElement.newWidth)
  else
    uiElement.width = uiElement.newWidth
  end
  uiElement.newWidth = nil
  uiElement.layout.growChildrenWidth(uiElement)
end

function FlexLayout.updateHeights(uiElement, height)
  if not uiElement.newHeight then
    uiElement.layout.fitSizeHeight(uiElement)
  end
  if height then
    uiElement.height = math.max(height, uiElement.newHeight)
  else
    uiElement.height = uiElement.newHeight
  end
  uiElement.newHeight = nil
  uiElement.layout.growChildrenHeight(uiElement)
end

---@param uiElement UiElement
function FlexLayout.growChildrenWidth(uiElement)
  error("FlexLayout does not implement growChildrenWidth")
end

---@param uiElement UiElement
function FlexLayout.growChildrenHeight(uiElement)
  error("FlexLayout does not implement growChildrenHeight")
end

return FlexLayout