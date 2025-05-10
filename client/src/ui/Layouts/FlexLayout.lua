local PATH = (...):gsub('%.[^%.]+$', '')
local Layout = require(PATH ..".Layout")

---@class FlexLayout : Layout
local FlexLayout = setmetatable({}, {__index = Layout})

---@param uiElement UiElement
function FlexLayout.fitSizeWidth(uiElement)
  for _, child in ipairs(uiElement.children) do
    child.layout.fitSizeWidth(child)
  end
  local w = uiElement.layout.getMinWidth(uiElement)
  uiElement.width = math.max(w, uiElement.minWidth)
end

---@param uiElement UiElement
function FlexLayout.fitSizeHeight(uiElement)
  for _, child in ipairs(uiElement.children) do
    child.layout.fitSizeHeight(child)
  end
  local h = uiElement.layout.getMinHeight(uiElement)
  uiElement.height = math.max(h, uiElement.minHeight)
end

function FlexLayout.updateWidths(uiElement, width)
  uiElement.layout.fitSizeWidth(uiElement)
  if width then
    uiElement.width = math.max(width, uiElement.width)
  end
  uiElement.layout.growChildrenWidth(uiElement)
end

function FlexLayout.updateHeights(uiElement, height)
  uiElement.layout.fitSizeHeight(uiElement)
  if height then
    uiElement.height = math.max(height, uiElement.height)
  end
  uiElement.layout.growChildrenHeight(uiElement)
end

---@param uiElement UiElement
---@return number
function FlexLayout.getMinWidth(uiElement)
  error("FlexLayout does not implement getMinWidth")
end

---@param uiElement UiElement
---@return number
function FlexLayout.getMinHeight(uiElement)
  error("FlexLayout does not implement getMinHeight")
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