local logger = require("common.lib.logger")
local NetClient = require("client.src.network.NetClient")
local SoundController = require("client.src.music.SoundController")
local ReplayBrowser = require("client.src.scenes.ReplayBrowser")

---@param messageKey string
---@param detail string
---@return false
local function rejectDrop(messageKey, detail)
  logger.warn("Could not open dropped replay: " .. detail)
  love.window.showMessageBox(loc("rp_drop_error"), loc(messageKey), "warning")
  return false
end

--- Opens a dropped JSON replay's details without importing or modifying the source file.
---@param file love.File
---@return boolean accepted
local function handleReplayFileDrop(file)
  local filename = file:getFilename()
  if not filename:lower():match("%.json$") then
    return rejectDrop("rp_drop_json_only", filename)
  end

  local navigation = GAME.navigationStack
  local activeScene = navigation and navigation:getActiveScene()
  if not activeScene or activeScene.name == "BootScene" or not GAME.localPlayer
    or GAME.netClient.state ~= NetClient.STATES.OFFLINE or GAME.battleRoom
    or (activeScene.match and activeScene.name ~= "ReplayGame") then
    return rejectDrop("rp_drop_unavailable", "Game is loading, transitioning, online, or in a battle room")
  end

  local replay = ReplayBrowser.readReplayFile(file)
  if not replay then
    return false
  end

  local displayName = filename:match("[^/\\]+$") or filename
  if activeScene.name == "ReplayGame" then
    activeScene.match:abort()
    SoundController:stopMusic()
    navigation:pop(nil, function()
      activeScene.match:deinit()
      local browser = navigation:getActiveScene()
      if browser and browser.name == "ReplayBrowser" then
        browser:showReplay(replay, displayName)
      else
        navigation:push(ReplayBrowser({replay = replay, filename = displayName}))
      end
    end)
  elseif activeScene.name == "ReplayBrowser" then
    activeScene:showReplay(replay, displayName)
  else
    navigation:push(ReplayBrowser({replay = replay, filename = displayName}))
  end
  return true
end

return handleReplayFileDrop
