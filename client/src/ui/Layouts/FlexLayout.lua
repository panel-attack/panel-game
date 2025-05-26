local PATH = (...):gsub('%.[^%.]+$', '')
local Layout = require(PATH ..".Layout")
local util = require("common.lib.util")

---@class FlexLayout : Layout
local FlexLayout = setmetatable({}, {__index = Layout})

---@param uiElement UiElement
function FlexLayout.fitSizeWidth(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.layout.fitSizeWidth then
      child.layout.fitSizeWidth(child)
    end
  end
  local w = uiElement.layout.getPreferredWidth(uiElement)
  uiElement.newWidth = math.max(w, uiElement:getPreferredWidth(), uiElement.minWidth)
end

---@param uiElement UiElement
function FlexLayout.fitSizeHeight(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.layout.fitSizeHeight then
      child.layout.fitSizeHeight(child)
    end
  end
  local h = uiElement.layout.getMinHeight(uiElement)
  uiElement.newHeight = math.max(h, uiElement.minHeight)
end

function FlexLayout.setWidth(uiElement, width)
  if not uiElement.newWidth then
    uiElement.layout.fitSizeWidth(uiElement)
  end

  local minWidth = uiElement.layout.getMinWidth(uiElement)
  if not uiElement.controlsWindow then
    minWidth = math.max(minWidth, uiElement.minWidth)
  end
  if width then
    if width > minWidth then
      uiElement.width = util.bound(minWidth, uiElement.newWidth, width)
    else
      uiElement.width =  math.max(minWidth, uiElement.newWidth)
    end
  else
    uiElement.width = util.bound(minWidth, uiElement.newWidth, uiElement.maxWidth)
  end

  uiElement.newWidth = nil
end

function FlexLayout.setHeight(uiElement, height)
  if not uiElement.newHeight then
    uiElement.layout.fitSizeHeight(uiElement)
  end
  if height then
    uiElement.height = math.max(height, uiElement.newHeight)
  else
    uiElement.height = uiElement.newHeight
  end
  uiElement.newHeight = nil
end

---@param uiElement UiElement
function FlexLayout.finalizeChildrenWidths(uiElement)
  error("FlexLayout does not implement finalizeChildrenWidths")
end

---@param uiElement UiElement
function FlexLayout.finalizeChildrenHeights(uiElement)
  error("FlexLayout does not implement finalizeChildrenHeights")
end

return FlexLayout