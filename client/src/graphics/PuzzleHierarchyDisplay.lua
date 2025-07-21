local class = require("common.lib.class")
local UiElement = require("client.src.ui.UIElement")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class PuzzleHierarchyDisplayOptions : UiElementOptions
---@field puzzleSet PuzzleSet
---@field puzzleSetIndices integer[]
---@field puzzleIndex integer?

---@class PuzzleHierarchyDisplay : UiElement
---@field puzzleSet PuzzleSet
---@field puzzleSetIndices integer[]
---@field puzzleIndex integer?
local PuzzleHierarchyDisplay = class(function(self, options)
  self.puzzleSet = options.puzzleSet
  self.puzzleSetIndices = options.puzzleSetIndices or {}
  self.puzzleIndex = options.puzzleIndex
end, UiElement)

function PuzzleHierarchyDisplay:updateDisplay(puzzleSet, puzzleSetIndices, puzzleIndex)
  self.puzzleSet = puzzleSet
  self.puzzleSetIndices = puzzleSetIndices or {}
  self.puzzleIndex = puzzleIndex
end

function PuzzleHierarchyDisplay:getDisplayText()
  if not self.puzzleSet then
    return ""
  end
  
  local parts = {}
  local currentSet = self.puzzleSet
  
  -- Add root set name
  parts[#parts + 1] = currentSet.localizedSetName or currentSet.setName
  
  -- Navigate through hierarchy and collect set names
  if self.puzzleSetIndices then
    for i = 1, #self.puzzleSetIndices do
      local index = self.puzzleSetIndices[i]
      if currentSet.puzzleSets and currentSet.puzzleSets[index] then
        currentSet = currentSet.puzzleSets[index]
        parts[#parts + 1] = currentSet.localizedSetName or currentSet.setName
      else
        break
      end
    end
  end
  
  -- Add current puzzle index only if specified
  if self.puzzleIndex then
    parts[#parts + 1] = "Puzzle " .. self.puzzleIndex
  end
  
  return table.concat(parts, " > ")
end

function PuzzleHierarchyDisplay:drawSelf()
  self:drawHierarchyWithStyling()
end

function PuzzleHierarchyDisplay:drawHierarchyWithStyling()
  if not self.puzzleSet then
    return
  end
  
  GraphicsUtil.setColor(0.1, 0.1, 0.2, 0.8)
  love.graphics.rectangle("fill", self.x - 8, self.y - 4, self.width + 16, 28)
  
  GraphicsUtil.setColor(0.4, 0.7, 1.0, 0.9)
  love.graphics.rectangle("line", self.x - 8, self.y - 4, self.width + 16, 28)
  
  local parts = {}
  local currentSet = self.puzzleSet
  local xOffset = 0
  
  parts[#parts + 1] = {text = currentSet.localizedSetName or currentSet.setName, type = "root"}
  
  if self.puzzleSetIndices then
    for i = 1, #self.puzzleSetIndices do
      local index = self.puzzleSetIndices[i]
      if currentSet.puzzleSets and currentSet.puzzleSets[index] then
        currentSet = currentSet.puzzleSets[index]
        parts[#parts + 1] = {text = currentSet.localizedSetName or currentSet.setName, type = "set"}
      else
        break
      end
    end
  end
  
  if self.puzzleIndex then
    parts[#parts + 1] = {text = "Puzzle " .. self.puzzleIndex, type = "puzzle"}
  end
  
  -- Draw each part with appropriate styling
  for i, part in ipairs(parts) do
    if part.type == "root" then
      GraphicsUtil.setColor(0.9, 0.9, 0.4, 1.0)
    elseif part.type == "set" then
      GraphicsUtil.setColor(0.7, 0.8, 1.0, 1.0)
    elseif part.type == "puzzle" then
      GraphicsUtil.setColor(1.0, 0.8, 0.4, 1.0)
    end
    
    love.graphics.print(part.text, self.x + xOffset, self.y)
    xOffset = xOffset + love.graphics.getFont():getWidth(part.text)
    
    -- Draw separator arrow with dimmed color
    if i < #parts then
      GraphicsUtil.setColor(0.6, 0.6, 0.6, 0.8)
      love.graphics.print(" > ", self.x + xOffset, self.y)
      xOffset = xOffset + love.graphics.getFont():getWidth(" > ")
    end
  end
  
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return PuzzleHierarchyDisplay