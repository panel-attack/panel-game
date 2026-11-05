local logger = require("common.lib.logger")
local ReplayV3 = require("common.data.ReplayV3")
local LevelData = require("common.data.LevelData")
local Match = require("common.engine.Match")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local NetClient = require("client.src.network.NetClient")
local SoundController = require("client.src.music.SoundController")

---@param messageKey string
---@param detail string
---@return false
local function rejectDrop(messageKey, detail)
  logger.warn("Could not open dropped replay: " .. detail)
  love.window.showMessageBox(loc("rp_drop_error"), loc(messageKey), "warning")
  return false
end

-- Conversion supports legacy replays too; validate the fields used by the details screen before changing scenes.
---@param contents string
---@return ReplayV3
local function decodeReplay(contents)
  local data, position, decodeError = json.decode(contents)
  assert(not decodeError, decodeError)
  assert(type(data) == "table" and not contents:sub(position):find("%S"), "Expected one JSON replay object")
  assert(data.replayVersion == nil or tonumber(data.replayVersion) == 2 or data.replayVersion == 3,
    "Unsupported replay format")
  local replay = ReplayV3.createFromTable(data, true)
  assert(replay and type(replay.engineVersion) == "string", "Missing engine version")
  assert(type(replay.rules) == "table" and type(replay.panelSource) == "table", "Missing match settings")
  assert(type(replay.stacks) == "table" and #replay.stacks >= 1 and #replay.stacks <= 2, "Invalid stack count")
  assert(type(replay.garbageFlows) == "table", "Missing garbage flows")
  assert(type(replay.metadata) == "table" and type(replay.metadata.stacks) == "table", "Missing replay metadata")
  assert(#replay.metadata.stacks == #replay.stacks, "Invalid stack metadata")

  local seen = {}
  for _, metadata in ipairs(replay.metadata.stacks) do
    assert(type(metadata) == "table" and type(metadata.stackIndex) == "number", "Invalid stack metadata")
    local stack = replay.stacks[metadata.stackIndex]
    assert(type(stack) == "table" and not seen[metadata.stackIndex], "Invalid stack index")
    seen[metadata.stackIndex] = true
    for _, field in ipairs({"name", "characterId"}) do
      assert(metadata[field] == nil or type(metadata[field]) == "string", "Invalid metadata field: " .. field)
    end
    for _, field in ipairs({"level", "difficulty", "challengeModeDifficulty", "stageIndex"}) do
      assert(metadata[field] == nil or type(metadata[field]) == "number", "Invalid metadata field: " .. field)
    end
    if stack.stackType == ReplayV3.stackTypes.Stack then
      assert(type(stack.levelData) == "table" and LevelData.validate(stack.levelData), "Invalid level settings")
      assert(type(stack.stackBehaviours) == "table" and type(stack.inputs) == "string", "Invalid stack settings")
      assert(stack.inputMethod == "controller" or stack.inputMethod == "touch", "Invalid input method")
    else
      assert(stack.stackType == ReplayV3.stackTypes.SimulatedStack and type(stack.attackSettings) == "table",
        "Invalid simulated stack")
    end
  end

  if ReplayV3.replayCanBeViewed(replay) then
    -- Check engine settings and compressed inputs before a drop can stop the current replay.
    local match = Match.createFromReplay(replay)
    for i, stack in ipairs(match.stacks) do
      if replay.stacks[i].stackType == ReplayV3.stackTypes.Stack then
        ---@cast stack Stack
        for _, input in ipairs(stack.confirmedInput) do
          if stack.inputMethod == "controller" then
            assert(KeyDataEncoding.base64decode[input], "Invalid controller input")
          else
            local raise, row, column = TouchDataEncoding.latinStringToTouchData(input, stack.width)
            assert(row <= stack.height
              and TouchDataEncoding.touchDataToLatinString(raise, row, column, stack.width) == input, "Invalid touch input")
          end
        end
      end
    end
    match:start()
  end
  return replay
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

  local opened, openError = file:open("r")
  if not opened then
    return rejectDrop("rp_drop_read_error", filename .. ": " .. tostring(openError))
  end
  local contents, readError = file:read()
  local closed, closeError = file:close()
  if not contents or not closed then
    return rejectDrop("rp_drop_read_error", filename .. ": " .. tostring(not contents and readError or closeError))
  end

  local success, replay = pcall(decodeReplay, contents)
  if not success then
    return rejectDrop("rp_drop_invalid", filename .. ": " .. tostring(replay))
  end

  local ReplayBrowser = require("client.src.scenes.ReplayBrowser")
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
