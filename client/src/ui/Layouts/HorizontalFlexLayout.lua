local PATH = (...):gsub('%.[^%.]+$', '')
local FlexLayout = require(PATH ..".FlexLayout")

---@class HorizontalFlexLayout : FlexLayout
local HorizontalFlexLayout = setmetatable({characteristic = "horizontal"}, {__index = FlexLayout})

---@param uiElement UiElement
function HorizontalFlexLayout.getMinWidth(uiElement)
  local w = uiElement.padding * 2 + uiElement.childGap * (#uiElement.children - 1)

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      w = w + child.newWidth
    end
  end

  return w
end

---@param uiElement UiElement
function HorizontalFlexLayout.getMinHeight(uiElement)
  local h = uiElement.padding * 2
  local maxHeight = 0

  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      maxHeight = math.max(maxHeight, child.newHeight)
    end
  end

  return h + maxHeight
end

local growables = {}
local shrinkables = {}

---@param uiElement UiElement
function HorizontalFlexLayout.growChildrenWidth(uiElement)
  if #uiElement.children == 0 then
    return
  end

  local remainingWidth = uiElement.width - uiElement.layout.getMinWidth(uiElement)

  if remainingWidth >= 1 then
    table.clear(growables)

    for i, child in ipairs(uiElement.children) do
      if child.isVisible and child.hFill and child.newWidth < child.maxWidth then
        growables[#growables+1] = child
      end
    end

    if #growables > 0 then

      while #growables > 0 and remainingWidth > 0 do
        local smallest = growables[1].newWidth
        local secondSmallest = math.huge
        -- if growables[1] is already the smallest, it will increment the counter at some point within the loop so we can't count it yet
        local smallestCount = 1

        for i = 2, #growables do
          local growable = growables[i]
          if growable.newWidth < smallest then
            secondSmallest = smallest
            smallest = growable.newWidth
            smallestCount = 1
          elseif growable.newWidth > smallest then
            secondSmallest = math.min(secondSmallest, growable.newWidth)
          else
            smallestCount = smallestCount + 1
          end
        end

        local delta = secondSmallest - smallest
        local widthToAdd = math.min(delta, remainingWidth / smallestCount)

        if delta * smallestCount >= remainingWidth then
          for _, growable in ipairs(growables) do
            if growable.newWidth == smallest then
              local toAdd = math.min(widthToAdd, growable.maxWidth - growable.newWidth)
              growable.newWidth = growable.newWidth + toAdd
              remainingWidth = remainingWidth - toAdd
            end
          end
          if remainingWidth < 1 then
            -- we could run into floating point shenanigans here
            remainingWidth = 0
          end
        else
          for _, growable in ipairs(growables) do
            if growable.newWidth == smallest then
              local toAdd = math.min(widthToAdd, growable.maxWidth - growable.newWidth)
              growable.newWidth = growable.newWidth + toAdd
              remainingWidth = remainingWidth - toAdd
            end
          end
        end

        for i = #growables, 1, -1 do
          local growable = growables[i]
          if growable.newWidth >= growable.maxWidth then
            table.remove(growables, i)
          end
        end
      end
    end
  elseif remainingWidth <= 1 then
    table.clear(shrinkables)

    for i, child in ipairs(uiElement.children) do
      if child.isVisible and child.hFill and child.newWidth > child.minWidth then
        shrinkables[#shrinkables+1] = child
      end
    end

    if #shrinkables > 0 then
      while #shrinkables > 0 and remainingWidth < 0 do
        local biggest = shrinkables[1].newWidth
        local secondBiggest = 0
        -- if growables[1] is already the smallest, it will increment the counter at some point within the loop so we can't count it yet
        local biggestCount = 1

        for i = 2, #shrinkables do
          local shrinkable = shrinkables[i]
          if shrinkable.newWidth > biggest then
            secondBiggest = biggest
            biggest = shrinkable.newWidth
            biggestCount = 1
          elseif shrinkable.newWidth < biggest then
            secondBiggest = math.max(secondBiggest, shrinkable.newWidth)
          else
            biggestCount = biggestCount + 1
          end
        end

        local delta = secondBiggest - biggest
        local widthToSubtract = math.min(delta, math.abs(remainingWidth / biggestCount))

        if delta * biggestCount >= -remainingWidth then
          for _, shrinkable in ipairs(shrinkables) do
            if shrinkable.newWidth == biggest then
              local toSubtract = math.min(widthToSubtract, shrinkable.newWidth - shrinkable.minWidth)
              shrinkable.newWidth = shrinkable.newWidth - toSubtract
              remainingWidth = remainingWidth + toSubtract
            end
          end
          if remainingWidth < 1 then
            -- we could run into floating point shenanigans here
            remainingWidth = 0
          end
        else
          for _, shrinkable in ipairs(shrinkables) do
            if shrinkable.newWidth == biggest then
              local toSubtract = math.min(widthToSubtract, shrinkable.newWidth - shrinkable.minWidth)
              shrinkable.newWidth = shrinkable.newWidth - toSubtract
              remainingWidth = remainingWidth + toSubtract
            end
          end
        end

        for i = #shrinkables, 1, -1 do
          local shrinkable = shrinkables[i]
          if shrinkable.newWidth <= shrinkable.minWidth then
            table.remove(shrinkables, i)
          end
        end
      end
    end
  end
end

---@param uiElement UiElement
function HorizontalFlexLayout.growChildrenHeight(uiElement)
  for _, child in ipairs(uiElement.children) do
    if child.vFill then
      child.newHeight = math.min(uiElement.height - uiElement.padding * 2, child.maxHeight)
    end
    if child.layout.growChildrenHeight then
      child.layout.growChildrenHeight(child)
    end
  end
end

---@param uiElement UiElement
function HorizontalFlexLayout.positionChildren(uiElement)
  local remainingWidth = uiElement.width - (uiElement.padding * 2 + uiElement.childGap * (#uiElement.children - 1))
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      remainingWidth = remainingWidth - child.width
    else
      -- we subtracted the childgap for invisible children earlier
      remainingWidth = remainingWidth + uiElement.childGap
    end
  end

  local x = uiElement.padding
  for _, child in ipairs(uiElement.children) do
    if child.isVisible then
      if child.hAlign == "left" then
        child.x = x
      elseif child.hAlign == "center" then
        child.x = x + remainingWidth / 2
      elseif child.hAlign == "right" then
        child.x = x + remainingWidth
      end

      if child.vAlign == "top" then
        child.y = uiElement.padding
      elseif child.vAlign == "center" then
        child.y = (uiElement.height - child.height) / 2
      elseif child.vAlign == "bottom" then
        child.y = (uiElement.height - child.height) - uiElement.padding
      end
      child.x = math.round(child.x)
      child.y = math.round(child.y)
      x = x + uiElement.childGap + child.width
    end
  end
end

return HorizontalFlexLayout