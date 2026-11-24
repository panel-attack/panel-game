local RendererSetting = require("client.src.graphics.RendererSetting")
local RendererFallbackSetup = require("client.src.scenes.RendererFallbackSetup")
local json = require("common.lib.dkjson")

-- the messages LÖVE's Vulkan backend threw in player crash reports
local VULKAN_FAILURES = {
  "failed to submit draw command buffer",
  "Failed to submit Vulkan draw command buffer: device lost",
  "Cannot create stream buffer: out of device graphics memory",
  "Failed to create Vulkan swap chain: initialization failed",
}

local function automaticLeavesLoveRenderersAlone()
  assert(RendererSetting.loveRenderers(RendererSetting.AUTO) == nil)
end

local function openGLIsTheOnlyRendererLoveMayPick()
  local renderers = RendererSetting.loveRenderers(RendererSetting.OPENGL)
  assert(renderers and #renderers == 1 and renderers[1] == "opengl")
end

local function vulkanFailureRestartsWithoutVulkan()
  for _, message in ipairs(VULKAN_FAILURES) do
    local restartValue = RendererSetting.fallbackRestartValue(message, "Vulkan", nil)
    assert(restartValue, message)
    local excluded = RendererSetting.excludedRenderers(restartValue)
    assert(excluded and #excluded == 1 and excluded[1] == "vulkan", message)
    assert(RendererSetting.isFallbackLaunch(restartValue), message)
  end
end

local function otherErrorsDoNotRestart()
  assert(RendererSetting.fallbackRestartValue("main.lua:12: attempt to index a nil value", "Vulkan", nil) == nil)
end

local function vulkanMessagesOnOtherRenderersDoNotRestart()
  assert(RendererSetting.fallbackRestartValue(VULKAN_FAILURES[1], "OpenGL", nil) == nil)
  assert(RendererSetting.fallbackRestartValue(VULKAN_FAILURES[1], "Metal", nil) == nil)
end

local function fallbackLaunchDoesNotRestartAgain()
  local restartValue = RendererSetting.fallbackRestartValue(VULKAN_FAILURES[1], "Vulkan", nil)
  assert(RendererSetting.fallbackRestartValue(VULKAN_FAILURES[1], "Vulkan", restartValue) == nil)
end

local function ordinaryLaunchExcludesNothing()
  assert(RendererSetting.excludedRenderers(nil) == nil)
  assert(not RendererSetting.isFallbackLaunch(nil))
  -- LÖVE's own restart value when a game is dropped on the no-game screen
  local noGameRestart = {_noGameRestartInfo = {gamepath = "game"}}
  assert(RendererSetting.excludedRenderers(noGameRestart) == nil)
  assert(not RendererSetting.isFallbackLaunch(noGameRestart))
end

-- reads conf.json holding the given renderer value into a config defaulting to auto
local function readRendererFromConfFile(savedRenderer)
  local previousConf = love.filesystem.read("conf.json")
  love.filesystem.write("conf.json", json.encode({renderer = savedRenderer}))
  local configTable = deepcpy(config)
  configTable.renderer = RendererSetting.AUTO
  readConfigFile(configTable)
  if previousConf then
    love.filesystem.write("conf.json", previousConf)
  else
    love.filesystem.remove("conf.json")
  end
  return configTable.renderer
end

local function savedRendererIsRead()
  assert(readRendererFromConfFile(RendererSetting.OPENGL) == RendererSetting.OPENGL)
end

local function unknownSavedRendererIsIgnored()
  assert(readRendererFromConfFile("directx") == RendererSetting.AUTO)
end

-- runs testFunction on a fallback prompt without touching the saved config or the navigation stack
---@param testFunction fun(scene: RendererFallbackSetup, getWriteCount: (fun(): integer), getPopCount: (fun(): integer))
local function withFallbackPrompt(testFunction)
  local originalRenderer = config.renderer
  local originalWriteConfFile = write_conf_file
  local originalPop = GAME.navigationStack.pop
  local writeCount = 0
  local popCount = 0
  write_conf_file = function() writeCount = writeCount + 1 end
  -- same parameters as NavigationStack:pop so the language server does not infer a different signature for every caller
  GAME.navigationStack.pop = function(_navigationStack, _transition, _callback) popCount = popCount + 1 end
  config.renderer = RendererSetting.AUTO

  local success, err = pcall(testFunction, RendererFallbackSetup({rendererName = "OpenGL"}),
    function() return writeCount end, function() return popCount end)

  write_conf_file = originalWriteConfFile
  GAME.navigationStack.pop = originalPop
  config.renderer = originalRenderer
  if not success then
    error(err, 0)
  end
end

local function keepingTheFallbackSavesOpenGL()
  withFallbackPrompt(function(scene, getWriteCount, getPopCount)
    scene:keepFallbackRenderer()
    assert(config.renderer == RendererSetting.OPENGL)
    assert(getWriteCount() == 1 and getPopCount() == 1)
  end)
end

local function tryingAgainKeepsAutomatic()
  withFallbackPrompt(function(scene, getWriteCount, getPopCount)
    scene:tryDefaultRendererAgain()
    assert(config.renderer == RendererSetting.AUTO)
    assert(getWriteCount() == 0 and getPopCount() == 1)
  end)
end

automaticLeavesLoveRenderersAlone()
openGLIsTheOnlyRendererLoveMayPick()
vulkanFailureRestartsWithoutVulkan()
otherErrorsDoNotRestart()
vulkanMessagesOnOtherRenderersDoNotRestart()
fallbackLaunchDoesNotRestartAgain()
ordinaryLaunchExcludesNothing()
savedRendererIsRead()
unknownSavedRendererIsIgnored()
keepingTheFallbackSavesOpenGL()
tryingAgainKeepsAutomatic()
