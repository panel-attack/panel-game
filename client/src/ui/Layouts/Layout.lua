---@enum LayoutCharacteristic
local LayoutCharacteristics = { none = "none", horizontal = "horizontal", vertical = "vertical"}

---@class Layout
---@field characteristic LayoutCharacteristic
local Layout = {
  characteristic = LayoutCharacteristics.none,
  Characteristics = LayoutCharacteristics
}

---@param uiElement UiElement
---@param width number?
---@param height number?
function Layout.resize(uiElement, width, height)
  Layout.updateWidths(uiElement, width)
  Layout.updateHeights(uiElement, height)
  Layout.updatePositions(uiElement)
  Layout.runResizedCallbacks(uiElement)
end

function Layout.runResizedCallbacks(uiElement)
  if uiElement.onResized then
    uiElement:onResized()
  end

  for _, child in ipairs(uiElement.children) do
    Layout.runResizedCallbacks(child)
  end
end

---@param uiElement UiElement
function Layout.updateWidths(uiElement, width)
  uiElement.layout.setWidth(uiElement, width)
  uiElement.layout.finalizeChildrenWidths(uiElement)

  for i, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.layout.updateWidths(child, child.newWidth)
    end
  end
end

---@param uiElement UiElement
---@param width integer?
function Layout.setWidth(uiElement, width)
  error("Layout does not implement setWidth")
end

function Layout.finalizeChildrenWidths(uiElement)
  error("Layout does not implement finalizeChildrenWidths")
end

---@param uiElement UiElement
function Layout.updateHeights(uiElement, height)
  uiElement.layout.setHeight(uiElement, height)
  uiElement.layout.finalizeChildrenHeights(uiElement)

  for i, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.layout.updateHeights(child, child.newHeight)
    end
  end
end

function Layout.setHeight(uiElement, height)
  error("Layout does not implement setHeight")
end

function Layout.finalizeChildrenHeights(uiElement)
  error("Layout does not implement finalizeChildrenHeights")
end

function Layout.updatePositions(uiElement)
  uiElement.layout.positionChildren(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.layout.updatePositions(child)
    end
  end
end

---@param uiElement UiElement
function Layout.positionChildren(uiElement)
  error("Layout does not implement positionChildren")
end

---@param uiElement UiElement
---@return number # the minimum width of the element as dictated by its children
function Layout.getMinWidth(uiElement)
  error("Layout does not implement getMinWidth")
end

---@param uiElement UiElement
---@return number # the minimum height of the element as dictated by its children
function Layout.getMinHeight(uiElement)
  error("Layout does not implement getMinHeight")
end

---@param uiElement UiElement
---@return number # the preferred width of the element based on the preferred widths of its children
function Layout.getPreferredWidth(uiElement)
  error("Layout does not implement getPreferredWidth")
end


return Layout