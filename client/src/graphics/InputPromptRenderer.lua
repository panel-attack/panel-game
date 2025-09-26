local GraphicsUtil = require("client.src.graphics.graphics_util")

local InputPromptRenderer = {}

-- Renders an input prompt icon at the specified position
---@param deviceType string "controller", "keyboard", "touch", or "mouse"
---@param x number
---@param y number
---@param size number? icon size (default: 32)
---@param alpha number? alpha/opacity (default: 1)
---@param controllerImageVariant string? specific controller image variant key
function InputPromptRenderer.renderIcon(deviceType, x, y, size, alpha, controllerImageVariant)
  if not GAME.theme then
    return
  end

  size = size or 32
  alpha = alpha or 1

  local icon = GAME.theme:getSpecificInputIcon(deviceType, controllerImageVariant)
  if not icon then
    return
  end

  GraphicsUtil.setColor(1, 1, 1, alpha)

  local iconWidth = icon:getWidth()
  local iconHeight = icon:getHeight()
  local scale = size / math.max(iconWidth, iconHeight)

  love.graphics.draw(icon, x, y, 0, scale, scale)

  GraphicsUtil.setColor(1, 1, 1, 1)
end

-- Renders an input prompt icon centered at the specified position
---@param deviceType string "controller", "keyboard", "touch", or "mouse"
---@param centerX number
---@param centerY number
---@param size number? icon size (default: 32)
---@param alpha number? alpha/opacity (default: 1)
---@param controllerImageVariant string? specific controller image variant key
function InputPromptRenderer.renderIconCentered(deviceType, centerX, centerY, size, alpha, controllerImageVariant)
  if not GAME.theme then
    return
  end

  size = size or 32
  local icon = GAME.theme:getSpecificInputIcon(deviceType, controllerImageVariant)
  if not icon then
    return
  end

  local iconWidth = icon:getWidth()
  local iconHeight = icon:getHeight()
  local scale = size / math.max(iconWidth, iconHeight)

  local scaledWidth = iconWidth * scale
  local scaledHeight = iconHeight * scale

  local x = centerX - scaledWidth / 2
  local y = centerY - scaledHeight / 2

  InputPromptRenderer.renderIcon(deviceType, x, y, size, alpha, controllerImageVariant)
end

-- Renders an input prompt icon with a device number overlay
---@param deviceType string "controller", "keyboard", "touch", or "mouse"
---@param centerX number
---@param centerY number
---@param size number? icon size (default: 32)
---@param alpha number? alpha/opacity (default: 1)
---@param controllerImageVariant string? specific controller image variant key
---@param deviceNumber integer? device configuration number (1-9, nil for no number)
function InputPromptRenderer.renderIconWithNumber(deviceType, centerX, centerY, size, alpha, controllerImageVariant, deviceNumber)
  if not GAME.theme then
    return
  end

  -- Render the main device icon
  InputPromptRenderer.renderIconCentered(deviceType, centerX, centerY, size, alpha, controllerImageVariant)

  -- Render device number overlay if provided
  if deviceNumber and deviceNumber > 1 and deviceNumber <= 9 then
    local numberIcon = GAME.theme:getDeviceNumberIcon(deviceNumber)
    if numberIcon then
      GraphicsUtil.setColor(1, 1, 1, alpha)

      local numberSize = math.max(size * 0.4, 16) -- Number should be smaller but visible
      local numberWidth = numberIcon:getWidth()
      local numberHeight = numberIcon:getHeight()
      local numberScale = numberSize / math.max(numberWidth, numberHeight)

      -- Position number in bottom-right corner of device icon
      local numberX = centerX + (size * 0.25) - (numberWidth * numberScale * 0.5)
      local numberY = centerY + (size * 0.25) - (numberHeight * numberScale * 0.5)

      love.graphics.draw(numberIcon, numberX, numberY, 0, numberScale, numberScale)

      GraphicsUtil.setColor(1, 1, 1, 1)
    end
  end
end

return InputPromptRenderer