local PATH = (...):gsub('%.[^%.]+$', '')
local MenuItem = require(PATH .. ".MenuItem")
local Label = require(PATH .. ".Label")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

---@class SliderMenuItem : MenuItem
local SliderMenuItem = class(function(self, options)
  self.selected = false
  self.TYPE = "SliderMenuItem"
  self.labelText = options and options.labelText or nil
  self.slider = options and options.slider or nil
end, MenuItem)

--- Creates a SliderMenuItem with label and slider
---@param options table Options table with labelText, slider
---@return SliderMenuItem
function SliderMenuItem.create(options)
  assert(options.labelText ~= nil)
  assert(options.slider ~= nil)

  local SPACE_BETWEEN = 16

  local menuItem = SliderMenuItem(options)

  -- Create label (left side)
  local label = Label({
    text = options.labelText
  })

  -- Position slider (right side)
  local slider = options.slider

  -- Store references
  menuItem.label = label
  menuItem.slider = slider

  -- the label and the slider in a row, centered on each other
  menuItem:setLayoutRule("childGap", SPACE_BETWEEN)
  menuItem:setLayoutRule("padding", {right = MenuItem.PADDING, top = MenuItem.PADDING, bottom = MenuItem.PADDING})
  menuItem:setLayoutRule("childAlignment", {y = "center"})

  -- Add children
  menuItem:addChild(label)
  menuItem:addChild(slider)

  return menuItem
end

function SliderMenuItem:drawSelf()
  if self.selected and self.slider.getSelectedItemRect then
    -- Get the rectangle of the currently selected slider item
    local rect = self.slider:getSelectedItemRect()

    if rect then
      -- Use same pulsing effect as regular menu items
      local baseOpacity = 0.15
      local selectedAdditionalOpacity = 0.5
      local fillOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 16 + baseOpacity + selectedAdditionalOpacity
      local borderOpacity = (math.cos(6 * love.timer.getTime()) + 1) / 4 + baseOpacity + selectedAdditionalOpacity

      -- Convert slider-relative coordinates to this item's drawing coordinates
      local sliderRect = self.slider.layoutRect
      local absoluteX = sliderRect.x + rect.x
      local absoluteY = sliderRect.y + rect.y

      -- Draw pulsing background fill
      local bgColor = GAME.theme.colors.menuSelectedBackgroundColor
      GraphicsUtil.drawRectangle("fill", absoluteX, absoluteY, rect.width, rect.height,
        bgColor[1], bgColor[2], bgColor[3], fillOpacity)

      -- Draw pulsing border
      local borderColor = GAME.theme.colors.menuSelectedBorderColor
      GraphicsUtil.drawRectangle("line", absoluteX, absoluteY, rect.width, rect.height,
        borderColor[1], borderColor[2], borderColor[3], borderOpacity)
    end
  end
end

function SliderMenuItem:receiveInputsSelf(inputSource, dt)
  if self.slider then
    self.slider:receiveInputs(inputSource, dt)
  end
end

return SliderMenuItem
