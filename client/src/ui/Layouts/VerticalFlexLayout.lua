local PATH = (...):gsub('%.[^%.]+$', '')
local FlexLayout = require(PATH ..".FlexLayout")

---@class VerticalFlexLayout : FlexLayout
local VerticalFlexLayout = setmetatable({}, {__index = FlexLayout})

---@param uiElement UiElement
function VerticalFlexLayout.getMinWidth(uiElement)
  local w = uiElement.padding * 2
  local maxWidth = 0

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxWidth = math.max(maxWidth, child.newWidth)
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
function VerticalFlexLayout.growChildrenHeight(uiElement)
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
          growable.height = growable.newHeight
          table.remove(growables, i)
        end
      end
    end
  end
end

---@param uiElement UiElement
function VerticalFlexLayout.growChildrenWidth(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.hFill then
      child.newWidth = math.min(uiElement.width - uiElement.padding * 2, child.maxWidth)
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
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      if child.vAlign == "top" then
        child.y = y
      elseif child.vAlign == "center" then
        child.y = y + remainingHeight / 2
      elseif child.vAlign == "right" then
        child.y = y + remainingHeight
      end

      if child.hAlign == "left" then
        child.x = uiElement.padding
      elseif child.hAlign == "center" then
        child.x = (uiElement.width - child.width) / 2
      elseif child.hAlign == "right" then
        child.x = (uiElement.width - child.width) - uiElement.padding
      end
      child.x = math.round(child.x)
      child.y = math.round(child.y)
      y = y + uiElement.childGap + child.height
    end
  end
end

return VerticalFlexLayout