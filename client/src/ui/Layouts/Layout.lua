---@class Layout
local Layout = {}

---@param uiElement UiElement
---@param width number?
---@param height number?
function Layout.resize(uiElement, width, height)
  uiElement.layout.updateWidths(uiElement, width)

  -- transform width to height for width-to-height supporting uiElements based on the width pass
  uiElement:setMinHeightForWidth()

  uiElement.layout.updateHeights(uiElement, height)

  uiElement.layout.positionChildren(uiElement)
end

---@param uiElement UiElement
function Layout.updateWidths(uiElement, width)
  error("Layout does not implement positionChildren")
end

---@param uiElement UiElement
function Layout.updateHeights(uiElement, height)
  error("Layout does not implement positionChildren")
end

---@param uiElement UiElement
function Layout.positionChildren(uiElement)
  error("Layout does not implement positionChildren")
end


return Layout