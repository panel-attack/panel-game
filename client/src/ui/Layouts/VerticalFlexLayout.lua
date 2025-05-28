local import = require("common.lib.import")
local FlexLayout = require(PATH ..".FlexLayout")

---@class VerticalFlexLayout : FlexLayout
local VerticalFlexLayout = setmetatable({characteristic = "vertical"}, {__index = FlexLayout})

---@param uiElement UiElement
---@return number # the minimum width of the element as dictated by its children
function VerticalFlexLayout.getMinWidth(uiElement)
  local w = uiElement.padding * 2
  local maxWidth = 0

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxWidth = math.max(maxWidth, child.layout.getMinWidth(child))
    end
  end

  return w + maxWidth
end

function VerticalFlexLayout.getPreferredWidth(uiElement)
  local w = uiElement.padding * 2
  local maxWidth = 0

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxWidth = math.max(maxWidth, child.layout.getMinWidth(child), child:getPreferredWidth())
    end
  end

  return w + maxWidth
end

---@param uiElement UiElement
function VerticalFlexLayout.getMinHeight(uiElement)
  local h = uiElement.padding * 2 + uiElement.childGap * (#uiElement.children - 1)

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      h = h + child.newHeight
    end
  end

  return h
end

---@param uiElement UiElement
function VerticalFlexLayout.finalizeChildrenHeights(uiElement)
  if #uiElement.children == 0 then
    return
  end

  local growables = {}

  for i, child in ipairs(uiElement.children) do
    if child.isVisible and child.vFill and child.newHeight < child.maxHeight then
      growables[#growables+1] = child
    end
  end

  if #growables > 0 then
    local remainingHeight = uiElement.height - uiElement.layout.getMinHeight(uiElement)

    while #growables > 0 and remainingHeight > 0 do
      local smallest = growables[1].newHeight
      local secondSmallest = math.huge
      -- if growables[1] is already the smallest, it will increment the counter at some point within the loop so we can't count it yet
      local smallestCount = 1

      for i = 2, #growables do
        local growable = growables[i]
        if growable.newHeight < smallest then
          secondSmallest = smallest
          smallest = growable.newHeight
          smallestCount = 1
        elseif growable.newHeight > smallest then
          secondSmallest = math.min(secondSmallest, growable.newHeight)
        else
          smallestCount = smallestCount + 1
        end
      end

      local delta = secondSmallest - smallest
      local heightToAdd = math.min(delta, remainingHeight / smallestCount)

      if delta * smallestCount >= remainingHeight then
        for _, growable in ipairs(growables) do
          if growable.newHeight == smallest then
            local toAdd = math.min(heightToAdd, growable.maxHeight - growable.newHeight)
            growable.newHeight = growable.newHeight + toAdd
            remainingHeight = remainingHeight - toAdd
          end
        end
        if remainingHeight < 1 then
          -- we could run into floating point shenanigans here
          remainingHeight = 0
        end
      else
        for _, growable in ipairs(growables) do
          if growable.newHeight == smallest then
            local toAdd = math.min(heightToAdd, growable.maxHeight - growable.newHeight)
            growable.newHeight = growable.newHeight + toAdd
            remainingHeight = remainingHeight - toAdd
          end
        end
      end

      for i = #growables, 1, -1 do
        local growable = growables[i]
        if growable.newHeight >= growable.maxHeight then
          table.remove(growables, i)
        end
      end
    end
  end
end

---@param uiElement UiElement
function VerticalFlexLayout.finalizeChildrenWidths(uiElement)
  local maxWidth = uiElement.width - uiElement.padding * 2
  for _, child in ipairs(uiElement.children) do
    if child.hFill then
      child.newWidth = math.min(maxWidth, child.maxWidth)
    else
      child.newWidth = math.min(maxWidth, child.newWidth)
    end
  end
end

---@param uiElement UiElement
function VerticalFlexLayout.positionChildren(uiElement)
  local remainingHeight = uiElement.height - (uiElement.padding * 2 + uiElement.childGap * (#uiElement.children - 1))
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      remainingHeight = remainingHeight - child.height
    else
      -- we subtracted the childgap for this child earlier
      remainingHeight = remainingHeight + uiElement.childGap
    end
  end

  local y = uiElement.padding

  if uiElement.vAlign == "top" then
  elseif uiElement.vAlign == "center" then
    y = y + remainingHeight / 2
  elseif uiElement.vAlign == "bottom" then
    y = y + remainingHeight
  end

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      child.y = y

      if uiElement.hAlign == "left" then
        child.x = uiElement.padding
      elseif uiElement.hAlign == "center" then
        child.x = (uiElement.width - child.width) / 2
      elseif uiElement.hAlign == "right" then
        child.x = (uiElement.width - child.width) - uiElement.padding
      end
      child.x = math.round(child.x)
      child.y = math.round(child.y)
      y = y + uiElement.childGap + child.height
    end
  end
end

return VerticalFlexLayout