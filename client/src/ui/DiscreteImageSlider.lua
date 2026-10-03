local PATH = (...):gsub('%.[^%.]+$', '')
local Slider = require(PATH .. ".Slider")
local StackPanel = require(PATH .. ".StackPanel")
local ImageContainer = require(PATH .. ".ImageContainer")
local UIElement = require(PATH .. ".UIElement")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

---@class DiscreteValue
---@field id any Unique identifier for this value
---@field image love.Texture Image to display for this value
---@field selectedImage love.Texture? Optional image to display when selected (defaults to image)
---@field scale number? Scale factor for the image (default: 1)

---@class DiscreteImageSliderOptions : UiElementOptions
---@field values DiscreteValue[]? Array of discrete values to display
---@field itemSpacing number? Spacing between items in pixels (default: 0)
---@field selectedValue any? Initially selected value ID
---@field onValueChange fun(slider:DiscreteImageSlider)? Callback when value changes

---@class DiscreteImageSlider: Slider
---@field values DiscreteValue[] Array of discrete values
---@field itemSpacing number Spacing between items
---@field stackPanel StackPanel Layout container for items
---@field valueIdToIndex table<any, number> Map from value ID to array index
---@overload fun(options: DiscreteImageSliderOptions): DiscreteImageSlider
local DiscreteImageSlider = class(
  function(self, options)
    self.values = options.values or {}
    self.itemSpacing = options.itemSpacing or 0
    self.onValueChange = options.onValueChange or function() end
    self.onlyChangeOnRelease = options.onlyChangeOnRelease or false

    -- Create StackPanel for layout (as a child)
    self.stackPanel = StackPanel({
      alignment = "left",
      hAlign = "left",
      vAlign = "top"
    })

    -- Build index map, populate StackPanel, and calculate dimensions
    self:rebuildLayout()

    -- Add StackPanel as a child so it draws automatically
    self:addChild(self.stackPanel)

    -- Set initial value
    local initialValue = options.selectedValue
    if initialValue then
      self.value = self:getIndexForId(initialValue) or 1
    else
      self.value = 1
    end

    -- Update image selection for initial state
    self:updateImageSelection()

    -- Set tickAmount for parent Slider compatibility
    self.tickAmount = 1
  end,
  Slider
)
DiscreteImageSlider.TYPE = "DiscreteImageSlider"

---@param id any Value identifier
---@return number? index Array index for this ID, or nil if not found
function DiscreteImageSlider:getIndexForId(id)
  return self.valueIdToIndex[id]
end

---@param index number Array index
---@return any? id Value identifier at this index, or nil if out of bounds
function DiscreteImageSlider:getIdForIndex(index)
  if index >= 1 and index <= #self.values then
    return self.values[index].id
  end
  return nil
end

---@return any? id Currently selected value ID
function DiscreteImageSlider:getSelectedId()
  return self:getIdForIndex(self.value)
end

---@param id any Value identifier to select
---@param committed boolean Whether to trigger onValueChange callback
function DiscreteImageSlider:setSelectedId(id, committed)
  local index = self:getIndexForId(id)
  if index then
    self:setValue(index, committed)
  end
end

function DiscreteImageSlider:setValue(newValue, committed)
  local oldValue = self.value

  -- Call parent to handle value change and callbacks
  Slider.setValue(self, newValue, committed)

  -- Update images if value actually changed
  if oldValue ~= self.value then
    self:updateImageSelection()
  end
end

function DiscreteImageSlider:updateImageSelection()
  for i, imageContainer in ipairs(self.imageContainers) do
    local value = imageContainer.discreteValue
    local isSelected = (i == self.value)
    local newImage = (isSelected and value.selectedImage) or value.image

    if imageContainer.image ~= newImage then
      imageContainer:setImage(newImage, nil, nil, value.scale or 1)
    end
  end
end

function DiscreteImageSlider:rebuildLayout()
  -- Clear existing layout
  while #self.stackPanel.children > 0 do
    self.stackPanel:remove(self.stackPanel.children[1])
  end

  -- Rebuild index map
  self.valueIdToIndex = {}
  for i, value in ipairs(self.values) do
    self.valueIdToIndex[value.id] = i
  end

  -- Store references to ImageContainers for updating selection state
  self.imageContainers = {}

  -- Populate StackPanel with ImageContainers for each value
  for i, value in ipairs(self.values) do
    local scale = value.scale or 1
    local image = value.image

    local imageContainer = ImageContainer({
      image = image,
      scale = scale,
      hAlign = "left",
      vAlign = "top"
    })

    -- Store reference for tracking selection and value
    imageContainer.discreteIndex = i
    imageContainer.discreteValue = value
    self.imageContainers[i] = imageContainer

    self.stackPanel:addElement(imageContainer)

    -- Add spacing after each item except the last
    if i < #self.values and self.itemSpacing > 0 then
      local spacer = UIElement({
        width = self.itemSpacing,
        height = imageContainer.height,
        hAlign = "left",
        vAlign = "top"
      })
      self.stackPanel:addElement(spacer)
    end
  end

  -- Update dimensions
  self.width = self.stackPanel.width

  -- Calculate max height from StackPanel children (the image containers)
  local stackPanelMaxHeight = 0
  for _, child in ipairs(self.stackPanel.children) do
    if child.height > stackPanelMaxHeight then
      stackPanelMaxHeight = child.height
    end
  end
  self.stackPanel.height = stackPanelMaxHeight

  -- Calculate total height including all direct children (e.g., labels in subclasses)
  local totalHeight = stackPanelMaxHeight
  for _, child in ipairs(self.children) do
    if child ~= self.stackPanel then
      -- For children positioned below stackPanel (with positive y offset)
      local childBottomEdge = child.y + child.height
      if childBottomEdge > totalHeight then
        totalHeight = childBottomEdge
      end
    end
  end
  self.height = totalHeight

  self.min = 1
  self.max = math.max(1, #self.values)
end

---@param newValues DiscreteValue[] New array of discrete values
function DiscreteImageSlider:setValues(newValues)
  self.values = newValues
  local oldValue = self.value
  self:rebuildLayout()

  -- Try to maintain selection if possible
  local newValue
  if oldValue > #self.values then
    newValue = math.max(1, #self.values)
  else
    newValue = oldValue
  end

  self:setValue(newValue, false)
end

---@param x number Screen x coordinate
---@return number index Value index for this position
function DiscreteImageSlider:getValueForPos(x)
  if #self.values == 0 then
    return 1
  end

  local screenX, screenY = self:getScreenPos()
  local relativeX = x - screenX

  -- Find which item was clicked based on StackPanel children positions
  local bestIndex = 1
  local bestDistance = math.huge

  for i, child in ipairs(self.stackPanel.children) do
    if child.discreteIndex then
      local itemScreenX = screenX + child.x
      local itemCenterX = itemScreenX + child.width / 2
      local distance = math.abs(relativeX - (child.x + child.width / 2))

      if distance < bestDistance then
        bestDistance = distance
        bestIndex = child.discreteIndex
      end
    end
  end

  return bestIndex
end

---@return number x X position of current value's center
function DiscreteImageSlider:getCurrentXForValue()
  if self.value < 1 or self.value > #self.values then
    return self.x
  end

  -- Find the UI element for this value index
  for _, child in ipairs(self.stackPanel.children) do
    if child.discreteIndex == self.value then
      return self.x + child.x + child.width / 2
    end
  end

  return self.x
end

-- Gets the rectangle of the currently selected item (for SliderMenuItem highlighting)
---@return {x: number, y: number, width: number, height: number}?
function DiscreteImageSlider:getSelectedItemRect()
  if self.value < 1 or self.value > #self.values then
    return nil
  end

  local selectedContainer = self.imageContainers[self.value]
  if not selectedContainer then
    return nil
  end

  return {
    x = selectedContainer.x,
    y = selectedContainer.y,
    width = selectedContainer.width,
    height = selectedContainer.height
  }
end

function DiscreteImageSlider:drawSelf()
  -- Draw simple static border around the currently selected item
  if self.value < 1 or self.value > #self.values then
    return
  end

  -- Find the selected image container
  local selectedContainer = self.imageContainers[self.value]
  if not selectedContainer then
    return
  end

  -- Draw static border
  local borderColor = GAME.theme.colors.menuDefaultBorderColor

  GraphicsUtil.setColor(borderColor[1], borderColor[2], borderColor[3], 0.8)
  GraphicsUtil.drawRectangle(
    "line",
    self.x + selectedContainer.x,
    self.y + selectedContainer.y,
    selectedContainer.width,
    selectedContainer.height
  )

  -- Reset color
  GraphicsUtil.setColor(1, 1, 1, 1)
end

return DiscreteImageSlider
