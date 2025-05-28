local import = require("common.lib.import")
local Layout = require(PATH ..".Layout")

---@class StaticLayout : Layout
local StaticLayout = setmetatable({}, {__index = Layout})

---@param uiElement UiElement
function StaticLayout.setWidth(uiElement, width)
end

---@param uiElement UiElement
function StaticLayout.setHeight(uiElement, height)
end

---@param uiElement UiElement
function StaticLayout.positionChildren(uiElement)
end

---@param uiElement UiElement
---@return number
function StaticLayout.getMinWidth(uiElement)
  return uiElement.width
end

function StaticLayout.getPreferredWidth(uiElement)
  return uiElement.width
end

---@param uiElement UiElement
---@return number
function StaticLayout.getMinHeight(uiElement)
  return uiElement.height
end

return StaticLayout