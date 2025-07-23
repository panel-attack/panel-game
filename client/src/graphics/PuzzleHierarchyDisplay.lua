local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- Display constants
local BACKGROUND_PADDING = 8
local SEPARATOR_WIDTH = 16

local COLORS = {
  background = {0.05, 0.05, 0.1, 0.75},
  border = {1.0, 0.8, 0.1, 0.4}, -- Bright gold border  
  white = {1, 1, 1, 1}
}

-- Progressive gold color system - gets darker/richer with depth
local function getGoldColorForDepth(depth)
  if depth == 0 then
    return {1.0, 0.9, 0.4, 1.0} -- Bright light gold (root)
  elseif depth == 1 then
    return {1.0, 0.8, 0.2, 1.0} -- Medium gold (first level sets)
  elseif depth == 2 then
    return {0.9, 0.7, 0.1, 1.0} -- Darker gold (second level sets)
  elseif depth == 3 then
    return {0.85, 0.65, 0.075, 1.0} -- Deep gold (third level sets)
  else
    return {0.8, 0.6, 0.05, 1.0} -- Deepest gold (puzzle or deeper levels)
  end
end

---@class PuzzleHierarchyDisplayOptions : UiElementOptions
---@field puzzleSet PuzzleSet
---@field puzzleSetIndices integer[]
---@field puzzleIndex integer?

---@class PuzzleHierarchyDisplay : UiElement
---@field puzzleSet PuzzleSet
---@field puzzleSetIndices integer[]
---@field puzzleIndex integer?
---@field cachedParts table[]?
local PuzzleHierarchyDisplay = class(function(self, options)
  self.puzzleSet = options.puzzleSet
  self.puzzleSetIndices = options.puzzleSetIndices or {}
  self.puzzleIndex = options.puzzleIndex
  self.cachedParts = nil
  self:buildParts()
end, UiElement)

function PuzzleHierarchyDisplay:updateDisplay(puzzleSet, puzzleSetIndices, puzzleIndex)
  self.puzzleSet = puzzleSet
  self.puzzleSetIndices = puzzleSetIndices or {}
  self.puzzleIndex = puzzleIndex
  self:buildParts()
end

function PuzzleHierarchyDisplay:buildParts()
  if not self.puzzleSet then
    self.cachedParts = {}
    self:updateDimensions()
    return
  end
  
  local parts = {}
  local currentSet = self.puzzleSet
  local depth = 0
  
  -- Add root set name
  parts[#parts + 1] = {
    text = currentSet.localizedSetName or currentSet.setName, 
    type = "root", 
    depth = depth
  }
  
  -- Navigate through hierarchy and collect set names
  if self.puzzleSetIndices then
    for i = 1, #self.puzzleSetIndices do
      local index = self.puzzleSetIndices[i]
      if currentSet.puzzleSets and currentSet.puzzleSets[index] then
        currentSet = currentSet.puzzleSets[index]
        depth = depth + 1
        parts[#parts + 1] = {
          text = currentSet.localizedSetName or currentSet.setName, 
          type = "set", 
          depth = depth
        }
      else
        break
      end
    end
  end
  
  -- Add current puzzle index only if specified
  if self.puzzleIndex then
    depth = depth + 1
    parts[#parts + 1] = {
      text = "Puzzle " .. self.puzzleIndex, 
      type = "puzzle", 
      depth = depth
    }
  end
  
  self.cachedParts = parts
  self:updateDimensions()
end

function PuzzleHierarchyDisplay:calculateContentWidth()
  if not self.cachedParts or #self.cachedParts == 0 then
    return 0
  end
  
  local totalWidth = 0
  local font = love.graphics.getFont()
  
  for i, part in ipairs(self.cachedParts) do
    totalWidth = totalWidth + font:getWidth(part.text)
    
    -- Add separator width if not the last element
    if i < #self.cachedParts then
      totalWidth = totalWidth + SEPARATOR_WIDTH + 12 -- 6px padding on each side
    end
  end
  
  return totalWidth
end

function PuzzleHierarchyDisplay:updateDimensions()
  local contentWidth = self:calculateContentWidth()
  local font = love.graphics.getFont()
  
  self.width = contentWidth + (BACKGROUND_PADDING * 2)
  self.height = font:getHeight("A") + (BACKGROUND_PADDING * 2)
end

function PuzzleHierarchyDisplay:drawSteampunkSeparator(x, y)
  GraphicsUtil.setColor(COLORS.white)
  local image = themes[config.theme].images.separator
  GraphicsUtil.draw(image, x, y, 0, 1, 1, 0, 0)
end

function PuzzleHierarchyDisplay:getDisplayText()
  if not self.cachedParts or #self.cachedParts == 0 then
    return ""
  end
  
  local textParts = {}
  for i, part in ipairs(self.cachedParts) do
    textParts[#textParts + 1] = part.text
  end
  
  return table.concat(textParts, " > ")
end

function PuzzleHierarchyDisplay:drawSelf()
  self:drawHierarchyWithStyling()
end

function PuzzleHierarchyDisplay:drawHierarchyWithStyling()
  if not self.cachedParts or #self.cachedParts == 0 then
    return
  end
  
  -- Draw background with auto-sized dimensions
  GraphicsUtil.setColor(COLORS.background)
  love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
  
  GraphicsUtil.setColor(COLORS.border)
  love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
  
  -- Center content within the component
  local contentWidth = self:calculateContentWidth()
  local startX = self.x + (self.width - contentWidth) / 2
  local drawY = self.y + BACKGROUND_PADDING
  local xOffset = 0
  
  -- Draw each part with progressive gold colors
  for i, part in ipairs(self.cachedParts) do
    local goldColor = getGoldColorForDepth(part.depth)
    GraphicsUtil.setColor(goldColor)
    
    love.graphics.print(part.text, startX + xOffset, drawY)
    xOffset = xOffset + love.graphics.getFont():getWidth(part.text)
    
    -- Draw separator with spacing
    if i < #self.cachedParts then
      xOffset = xOffset + 6 -- Space before separator
      self:drawSteampunkSeparator(startX + xOffset, drawY - 2)
      xOffset = xOffset + SEPARATOR_WIDTH + 6 -- Space after separator
    end
  end
  
  GraphicsUtil.setColor(COLORS.white)
end

return PuzzleHierarchyDisplay