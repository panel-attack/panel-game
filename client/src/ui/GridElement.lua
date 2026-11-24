local PATH = (...):gsub('%.[^%.]+$', '')
local UiElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local DebugSettings = require("client.src.debug.DebugSettings")

local GridElement = class(function(gridElement, options)
  if options.content then
    gridElement.content = options.content
    -- in the cell's flow, so content that grows fills the cell
    gridElement:addChild(gridElement.content)
  end
  gridElement.description = options.description
  gridElement.gridOriginX = options.gridOriginX
  gridElement.gridOriginY = options.gridOriginY
  gridElement.gridWidth = options.gridWidth
  gridElement.gridHeight = options.gridHeight
  if options.drawBorders ~= nil then
    gridElement.drawBorders = options.drawBorders
  elseif DebugSettings.showUIElementBorders() then
    gridElement.drawBorders = true
  else
    gridElement.drawBorders = false
  end
  gridElement.TYPE = "GridElement"
end, UiElement)

function GridElement:drawSelf()
  if self.drawBorders then
    GraphicsUtil.drawRectangle("line", 0, 0, self.layoutRect.width, self.layoutRect.height)
  end
end

return GridElement
