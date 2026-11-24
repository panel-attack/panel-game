-- The player's choice of graphics backend, saved as config.renderer and applied by love.conf on the next launch,
-- and the restart onto another backend when Vulkan stops working.
-- LÖVE 12 starts on Vulkan whenever the driver offers it and never falls back once it has started,
-- so a player whose driver loses the Vulkan device needs a way to start on OpenGL instead.
local RendererSetting = {}

-- let LÖVE pick, which is Vulkan or Metal where available
RendererSetting.AUTO = "auto"
RendererSetting.OPENGL = "opengl"
RendererSetting.VALUES = {RendererSetting.AUTO, RendererSetting.OPENGL}

-- parts of the errors LÖVE's Vulkan backend throws once it has lost the device
local VULKAN_FAILURE_MESSAGES = {"draw command buffer", "swap chain", "stream buffer"}

---@class RendererFallbackRestart
---@field rendererFallback string the LÖVE renderer name the restarted game leaves out

---@param value any
---@return boolean # whether value is a renderer setting the game knows
function RendererSetting.isValid(value)
  return value == RendererSetting.AUTO or value == RendererSetting.OPENGL
end

---@param renderer string the config.renderer value
---@return string[]? # the t.graphics.renderers list for love.conf, nil keeps LÖVE's own order
function RendererSetting.loveRenderers(renderer)
  if renderer == RendererSetting.OPENGL then
    return {"opengl"}
  end
  return nil
end

---@param message string an error message
---@param rendererName string the renderer the game runs on, as love.graphics.getRendererInfo names it
---@return boolean # whether the error came from a Vulkan device that stopped working
function RendererSetting.isVulkanFailure(message, rendererName)
  if rendererName ~= "Vulkan" then
    return false
  end
  local lowercaseMessage = message:lower()
  for _, failureMessage in ipairs(VULKAN_FAILURE_MESSAGES) do
    if lowercaseMessage:find(failureMessage, 1, true) then
      return true
    end
  end
  return false
end

---@param restartValue any love.restart, the value LÖVE was restarted with
---@return boolean # whether this launch is the restart after a Vulkan failure
function RendererSetting.isFallbackLaunch(restartValue)
  return type(restartValue) == "table" and type(restartValue.rendererFallback) == "string"
end

-- The value to restart LÖVE with so the game starts again without Vulkan, or nil if the error is not a Vulkan failure
-- or this launch already is that restart.
---@param message string an error message
---@param rendererName string the renderer the game runs on, as love.graphics.getRendererInfo names it
---@param restartValue any love.restart, the value this launch was restarted with
---@return RendererFallbackRestart?
function RendererSetting.fallbackRestartValue(message, rendererName, restartValue)
  if RendererSetting.isFallbackLaunch(restartValue) or not RendererSetting.isVulkanFailure(message, rendererName) then
    return nil
  end
  return {rendererFallback = "vulkan"}
end

---@param restartValue any love.restart, the value this launch was restarted with
---@return string[]? # the t.graphics.excluderenderers list for love.conf, nil leaves out nothing
function RendererSetting.excludedRenderers(restartValue)
  if RendererSetting.isFallbackLaunch(restartValue) then
    return {restartValue.rendererFallback}
  end
  return nil
end

return RendererSetting
