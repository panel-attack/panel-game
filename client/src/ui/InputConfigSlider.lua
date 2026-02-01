local PATH = (...):gsub('%.[^%.]+$', '')
local DiscreteImageSlider = require(PATH .. ".DiscreteImageSlider")
local Label = require(PATH .. ".Label")
local ImageContainer = require(PATH .. ".ImageContainer")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")

---@class InputConfigSliderOptions : DiscreteImageSliderOptions
---@field onValueChange fun(slider:InputConfigSlider)? callback for whenever the value is changed

-- A visual slider for input configuration selection showing controller/keyboard icons
---@class InputConfigSlider: DiscreteImageSlider
---@field deviceLabel Label Label showing selected device name
---@field iconSize number Size of device icons
---@overload fun(options: InputConfigSliderOptions): InputConfigSlider
local InputConfigSlider = class(
---@param self InputConfigSlider
---@param options InputConfigSliderOptions
  function(self, options)
    -- Get controller image width to calculate icon size
    local controllerImage = GAME.theme:getInputPromptIcon("controller")
    local imageWidth = controllerImage and controllerImage:getWidth() or 128
    local iconSize = imageWidth / 2

    -- Store iconSize for later use
    self.iconSize = iconSize

    self.itemSpacing = 2
    self.selectedValue = options.selectedValue or 1

    -- Create label for device name
    local config = GAME.input.inputConfigurations[options.selectedValue or 1]
    local labelText = (config and not config:isEmpty() and config.deviceName) or "Empty Slot"
    self.deviceLabel = Label({
      text = labelText,
      translate = false,
      hAlign = "center",
      y = iconSize + 6
    })

    -- Add label as child
    self:addChild(self.deviceLabel)

    self:refresh()
  end,
  DiscreteImageSlider
)
InputConfigSlider.TYPE = "InputConfigSlider"

-- Checks if a configuration slot has any key bindings
---@param configIndex number Configuration slot index
---@return boolean
function InputConfigSlider:hasBindings(configIndex)
  local config = GAME.input.inputConfigurations[configIndex]
  if not config then
    return false
  end

  return not config:isEmpty()
end


-- Finds the first empty configuration slot
---@return number? index of first empty slot or nil if all full
function InputConfigSlider:findNextAvailableSlot()
  for i = 1, input.maxConfigurations do
    if not self:hasBindings(i) then
      return i
    end
  end
  return nil
end

-- Builds DiscreteValue array from current input configurations
---@return DiscreteValue[] values Array of values for DiscreteImageSlider
function InputConfigSlider:buildValuesArray()
  local values = {}
  local iconScale = self.iconSize / 128 -- Controller images are 128x128
  local nextAvailableSlot = self:findNextAvailableSlot()

  for i = 1, #input.inputConfigurations do
    if self:hasBindings(i) then
      -- Get device-specific icon
      local config = GAME.input.inputConfigurations[i]
      if config and config.deviceType and config.deviceType ~= "touch" then
        local icon = GAME.theme:getSpecificInputIcon(config.deviceType, config.controllerImageVariant)
        if icon then
          values[#values + 1] = {
            id = i,
            image = icon,
            scale = iconScale
          }
        end
      end
    elseif i == nextAvailableSlot then
      -- Show "+" icon for first empty slot
      local plusIcon = GAME.theme:getInputPromptIcon("controller_add")
      if plusIcon then
        values[#values + 1] = {
          id = i,
          image = plusIcon,
          scale = iconScale
        }
      end
    end
  end

  return values
end

-- Refreshes the slider visual (call when configs change)
function InputConfigSlider:refresh()
  local newValues = self:buildValuesArray()
  self:setValues(newValues)

  -- Update label text
  local config = GAME.input.inputConfigurations[self.value]
  local labelText = (config and not config:isEmpty() and config.deviceName) or "Empty Slot"
  self.deviceLabel:setText(labelText)
end

function InputConfigSlider:setValue(newValue, committed)
  -- Call parent to handle value change
  DiscreteImageSlider.setValue(self, newValue, committed)

  -- Update label text when selection changes
  local config = GAME.input.inputConfigurations[self.value]
  local labelText = (config and not config:isEmpty() and config.deviceName) or "Empty Slot"
  self.deviceLabel:setText(labelText)
end

function InputConfigSlider:rebuildLayout()
  -- Call parent to rebuild layout
  DiscreteImageSlider.rebuildLayout(self)

  -- Add error indicators to incomplete configurations
  for _, imageContainer in ipairs(self.imageContainers) do
    local valueId = imageContainer.discreteValue.id
    local config = GAME.input.inputConfigurations[valueId]

    -- Check if configuration is incomplete (has bindings but not all keys)
    if config and not config:isEmpty() and not config:isFullyConfigured() then
      -- Get error indicator icon
      local errorIcon = GAME.theme:getInputPromptIcon("controller_error")
      if errorIcon then
        -- Create error indicator as child with red tint
        local errorIndicator = ImageContainer({
          image = errorIcon,
          scale = 0.18
        })

        -- Position in bottom-right corner of the device icon
        errorIndicator.x = imageContainer.width / 2 - (errorIndicator.width / 2)
        errorIndicator.y = imageContainer.height - (errorIndicator.height) - 2

        -- Add as child of the image container
        imageContainer:addChild(errorIndicator)
      end
    end
  end
end

return InputConfigSlider
