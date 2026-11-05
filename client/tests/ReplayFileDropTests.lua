local handleReplayFileDrop = require("client.src.ReplayFileDrop")
local ReplayBrowser = require("client.src.scenes.ReplayBrowser")
local NavigationStack = require("client.src.NavigationStack")
local Scene = require("client.src.scenes.Scene")
local NetClient = require("client.src.network.NetClient")
local Match = require("common.engine.Match")
local GeneratorSource = require("common.engine.GeneratorSource")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local InputCompression = require("common.data.InputCompression")
local KeyDataEncoding = require("common.data.KeyDataEncoding")
local TouchDataEncoding = require("common.data.TouchDataEncoding")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local input = require("client.src.inputManager")

local originalNavigation = GAME.navigationStack
local originalRoom = GAME.battleRoom
local originalNetState = GAME.netClient.state
local originalMessageBox = love.window.showMessageBox
local originalPrint = GraphicsUtil.print
local originalInputDown = input.isDown
local messages = {}
local displayed = {}
local liveMatches = {}

---@return table
local function makeReplayData()
  local mode = GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS)
  local match = Match(GeneratorSource(1, false), mode.matchRules)
  match:createStackWithSettings(LevelPresets.getModern(5), false, "controller")
  local replay = json.decode(json.encode(match:createNewReplay()))
  replay.metadata.gameModeName = "endless"
  replay.metadata.stacks = {{stackIndex = 1, name = "Dropped Replay Player", level = 5, wins = 0}}
  replay.stacks[1].inputs = "A600"
  return replay
end

---@param contents string
---@param filename string?
---@param failure string?
---@return love.File
---@return table
local function droppedFile(contents, filename, failure)
  local calls = {opens = 0, reads = 0, closes = 0}
  ---@class ReplayDropTestFile : love.filesystem.File
  local file = {}
  function file:getFilename()
    return filename or "C:\\external folder\\test-replay.json"
  end
  function file:open(mode)
    assert(mode == "r", "Dropped files must only be opened for reading")
    calls.opens = calls.opens + 1
    return failure ~= "open", "Test open failure"
  end
  function file:read()
    calls.reads = calls.reads + 1
    if failure == "read" then
      return nil, "Test read failure"
    end
    return contents, #contents
  end
  function file:close()
    calls.closes = calls.closes + 1
    return failure ~= "close", "Test close failure"
  end
  return file, calls
end

local function testMenu(name)
  ---@class ReplayDropTestScene : Scene
  local menu = Scene({})
  menu.name = name
  return menu
end

local function resetNavigation()
  GAME.navigationStack = NavigationStack({})
  local menu = testMenu("ReplayDropTestMenu")
  GAME.navigationStack:push(menu)
  GAME.navigationStack:updateSelf(1 / 60)
  GAME.battleRoom = nil
  GAME.netClient.state = NetClient.STATES.OFFLINE
  input.isDown = {}
  messages = {}
  displayed = {}
  return menu
end

local function finishTransition()
  GAME.navigationStack:updateSelf(1 / 60)
  return GAME.navigationStack:getActiveScene()
end

local function assertDisplayed(text)
  assert(displayed[text], "Expected replay details to display: " .. text)
end

local function confirmReplay(browser)
  input.isDown.MenuSelect = 1
  browser:update()
  input.isDown.MenuSelect = nil
  local scene = finishTransition()
  assert(scene.name == "ReplayGame", "Confirm should start replay playback")
  liveMatches[scene.match] = true
  return scene
end

local function testDropShowsDetailsBeforePlaying()
  local menu = resetNavigation()
  local file, calls = droppedFile(json.encode(makeReplayData()))
  assert(handleReplayFileDrop(file))
  assert(calls.opens == 1 and calls.reads == 1 and calls.closes == 1)
  local browser = finishTransition()
  assert(browser.name == "ReplayBrowser", "A drop should show details, not immediately play")
  assert(#GAME.navigationStack.scenes == 2 and GAME.navigationStack.scenes[1] == menu)
  browser:draw()
  assertDisplayed(loc("rp_browser_info_header"))
  assertDisplayed("test-replay.json")
  assert(#messages == 0)

  local scene = confirmReplay(browser)
  assert(scene.match.supportsPause and scene.match.renderDuringPause)
  local clock = scene.match.engine.clock
  scene:update(1 / 60)
  assert(scene.match.engine.clock > clock, "The dropped replay should actually advance")
  assert(scene.saveReplay == false, "Watching should not save or overwrite the replay")
end

local function testReplacingPlaybackReusesBrowserAndCleansUp()
  resetNavigation()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()))))
  local browser = finishTransition()
  local scene = confirmReplay(browser)
  local oldMatch = scene.match
  local originalDeinit = oldMatch.deinit
  local deinitializations = 0
  oldMatch.deinit = function(self)
    deinitializations = deinitializations + 1
    liveMatches[self] = nil
    originalDeinit(self)
  end

  assert(not handleReplayFileDrop(droppedFile("{}", "invalid.json")))
  assert(GAME.navigationStack:getActiveScene() == scene and not oldMatch.ended,
    "An invalid drop must not stop the current replay")
  assert(deinitializations == 0)
  local malformed = makeReplayData()
  malformed.panelSource.sourceType = 999
  assert(not handleReplayFileDrop(droppedFile(json.encode(malformed))))
  assert(GAME.navigationStack:getActiveScene() == scene and not oldMatch.ended,
    "Invalid engine settings must not stop the current replay")

  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()), "replacement.JSON")))
  assert(oldMatch.engine.aborted)
  assert(finishTransition() == browser, "Replacing a replay should reuse its browser")
  assert(deinitializations == 1)
  assert(#GAME.navigationStack.scenes == 2, "Replacing should not accumulate scenes")
  browser:draw()
  assertDisplayed("replacement.JSON")
  confirmReplay(browser)
end

local function testDropIntoBrowserAndBackNavigation()
  local menu = resetNavigation()
  local browser = ReplayBrowser({})
  GAME.navigationStack:push(browser)
  finishTransition()
  for i = 1, 3 do
    assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()), "replay" .. i .. ".json")))
    assert(GAME.navigationStack:getActiveScene() == browser)
    assert(#GAME.navigationStack.scenes == 2)
  end
  input.isDown.MenuBack = 1
  browser:update()
  input.isDown.MenuBack = nil
  browser:draw()
  assertDisplayed(loc("rp_browser_header"))
  input.isDown.MenuEsc = 1
  browser:update()
  input.isDown.MenuEsc = nil
  assert(finishTransition() == menu)
end

local function testRejectedFilesKeepTheCurrentScene()
  local invalidContents = {"", "{broken json", "null", "true", "42", "[]", "{}", '{"puzzles":[]}', "{} {}"}
  local malformed = makeReplayData()
  malformed.metadata.stacks[1].stackIndex = 2
  invalidContents[#invalidContents + 1] = json.encode(malformed)
  malformed = makeReplayData()
  malformed.replayVersion = 99
  invalidContents[#invalidContents + 1] = json.encode(malformed)
  malformed = makeReplayData()
  malformed.stacks[1].levelData = {}
  invalidContents[#invalidContents + 1] = json.encode(malformed)
  for _, contents in ipairs(invalidContents) do
    local menu = resetNavigation()
    local file, calls = droppedFile(contents)
    assert(not handleReplayFileDrop(file))
    assert(GAME.navigationStack:getActiveScene() == menu)
    assert(#messages == 1 and messages[1] == loc("rp_drop_invalid"))
    assert(calls.closes == 1, "Invalid JSON must not leave the dropped file open")
  end

  for _, filename in ipairs({"replay.txt", "replay.json.bak", "replay"}) do
    resetNavigation()
    local file, calls = droppedFile("{}", filename)
    assert(not handleReplayFileDrop(file))
    assert(calls.opens == 0 and messages[1] == loc("rp_drop_json_only"))
  end

  for _, failure in ipairs({"open", "read", "close"}) do
    local menu = resetNavigation()
    local file, calls = droppedFile("{}", nil, failure)
    assert(not handleReplayFileDrop(file))
    assert(GAME.navigationStack:getActiveScene() == menu and messages[1] == loc("rp_drop_read_error"))
    assert(calls.closes == (failure == "open" and 0 or 1))
  end
end

---@param replay table
---@param scene Scene
local function assertRejectedReplay(replay, scene)
  local messageCount = #messages
  local file, calls = droppedFile(json.encode(replay))
  assert(not handleReplayFileDrop(file), "Malformed replay should be rejected before changing scenes")
  assert(calls.closes == 1)
  assert(#messages == messageCount + 1 and messages[#messages] == loc("rp_drop_invalid"))
  assert(GAME.navigationStack:getActiveScene() == scene, "Invalid replay should keep the current scene")
  if scene.name == "ReplayGame" then
    assert(not scene.match.ended and not scene.match.engine.aborted, "Invalid replay should not stop existing playback")
    local clock = scene.match.engine.clock
    scene:update(1 / 60)
    assert(scene.match.engine.clock > clock, "Existing playback should still advance after an invalid drop")
  end
end

local function testRejectsMalformedDisplayMetadata()
  local menu = resetNavigation()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()))))
  local scene = confirmReplay(finishTransition())
  for _, field in ipairs({"name", "characterId", "level", "difficulty", "challengeModeDifficulty", "stageIndex"}) do
    for _, value in ipairs({true, {}}) do
      local replay = makeReplayData()
      replay.metadata.stacks[1][field] = value
      assertRejectedReplay(replay, scene)
      replay.engineVersion = "999"
      GAME.navigationStack = NavigationStack({})
      GAME.navigationStack:push(menu)
      finishTransition()
      assertRejectedReplay(replay, menu)
      GAME.navigationStack:push(scene)
      finishTransition()
    end
  end
end

local function testRejectsInvalidInputSymbols()
  resetNavigation()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()))))
  local scene = confirmReplay(finishTransition())
  local touchIdle = TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6)
  local outOfBounds = TouchDataEncoding.touchDataToLatinString(false, 13, 1, 6)
  local invalidInputs = {
    {inputMethod = "controller", inputs = "~1"},
    {inputMethod = "controller", inputs = "A300~1"},
    {inputMethod = "touch", inputs = "A1"},
    {inputMethod = "touch", inputs = touchIdle .. "300" .. outOfBounds .. "1"},
    {inputMethod = "invalid", inputs = "A300"}
  }
  for _, inputs in ipairs(invalidInputs) do
    local replay = makeReplayData()
    replay.stacks[1].inputMethod = inputs.inputMethod
    replay.stacks[1].inputs = inputs.inputs
    assertRejectedReplay(replay, scene)
  end
end

local function testValidControllerAndTouchInputStreams()
  local touchInputs = {
    TouchDataEncoding.touchDataToLatinString(false, 0, 0, 6),
    TouchDataEncoding.touchDataToLatinString(true, 0, 0, 6),
    TouchDataEncoding.touchDataToLatinString(false, 1, 1, 6),
    TouchDataEncoding.touchDataToLatinString(true, 12, 6, 6)
  }
  for _, example in ipairs({
    {inputMethod = "controller", inputs = KeyDataEncoding.base64encode},
    {inputMethod = "touch", inputs = touchInputs}
  }) do
    resetNavigation()
    local replay = makeReplayData()
    replay.stacks[1].inputMethod = example.inputMethod
    replay.stacks[1].inputs = InputCompression.compressInputTable(example.inputs)
    assert(handleReplayFileDrop(droppedFile(json.encode(replay))))
    local browser = finishTransition()
    browser:draw()
    local scene = confirmReplay(browser)
    for _ = 1, #example.inputs do
      scene.match:run()
    end
    assert(scene.match.engine.clock == #example.inputs, "Every input should be playable")
  end
end

local function testUnavailableStatesDoNotReadTheFile()
  for _, state in pairs(NetClient.STATES) do
    if state ~= NetClient.STATES.OFFLINE then
      resetNavigation()
      GAME.netClient.state = state
      local file, calls = droppedFile(json.encode(makeReplayData()))
      assert(not handleReplayFileDrop(file))
      assert(calls.opens == 0 and messages[1] == loc("rp_drop_unavailable"))
    end
  end
  local blockers = {
    function()
      GAME.battleRoom = BattleRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_ENDLESS))
    end,
    function()
      GAME.navigationStack:getActiveScene().match = {}
    end,
    function()
      GAME.navigationStack:getActiveScene().name = "BootScene"
    end,
    function()
      GAME.navigationStack:push(testMenu("TransitionTestScene"))
    end
  }
  for _, block in ipairs(blockers) do
    resetNavigation()
    block()
    local file, calls = droppedFile(json.encode(makeReplayData()))
    assert(not handleReplayFileDrop(file))
    assert(calls.opens == 0 and messages[1] == loc("rp_drop_unavailable"))
    if GAME.battleRoom then
      GAME.battleRoom:shutdown()
    end
  end
end

local function testIncompatibleVersionUsesExistingWarning()
  resetNavigation()
  local data = makeReplayData()
  data.engineVersion = "999"
  assert(handleReplayFileDrop(droppedFile(json.encode(data))))
  local browser = finishTransition()
  browser:draw()
  assertDisplayed(loc("rp_browser_wrong_version"))
  assert(not browser:playReplay())
  assert(GAME.navigationStack:getActiveScene() == browser)
end

local function testLegacyReplayFiles()
  local path = "common/tests/engine/replays/"
  for _, filename in ipairs(love.filesystem.getDirectoryItems(path)) do
    if filename:match("%.json$") then
      resetNavigation()
      local contents = assert(love.filesystem.read(path .. filename))
      assert(handleReplayFileDrop(droppedFile(contents, filename)), "Could not open fixture " .. filename)
      finishTransition():draw()
      assertDisplayed(loc("rp_browser_info_header"))
    end
  end
end

local function testBrowserReportsPlaybackFailure()
  resetNavigation()
  local data = makeReplayData()
  data.panelSource.sourceType = 999
  local browser = ReplayBrowser({replay = data, filename = "invalid-settings.json"})
  GAME.navigationStack:push(browser)
  finishTransition()
  assert(not browser:playReplay())
  assert(GAME.navigationStack:getActiveScene() == browser)
  assert(messages[1] == loc("rp_drop_invalid"))
end

local function runTests()
  love.window.showMessageBox = function(title, message, boxType)
    assert(title == loc("rp_drop_error") and boxType == "warning")
    messages[#messages + 1] = message
    return true
  end
  GraphicsUtil.print = function(text)
    displayed[text] = true
  end
  testDropShowsDetailsBeforePlaying()
  testReplacingPlaybackReusesBrowserAndCleansUp()
  testDropIntoBrowserAndBackNavigation()
  testRejectedFilesKeepTheCurrentScene()
  testRejectsMalformedDisplayMetadata()
  testRejectsInvalidInputSymbols()
  testValidControllerAndTouchInputStreams()
  testUnavailableStatesDoNotReadTheFile()
  testIncompatibleVersionUsesExistingWarning()
  testLegacyReplayFiles()
  testBrowserReportsPlaybackFailure()
end

local success, err = xpcall(runTests, debug.traceback)
for match in pairs(liveMatches) do
  match:deinit()
end
if GAME.battleRoom and GAME.battleRoom ~= originalRoom then
  GAME.battleRoom:shutdown()
end
GAME.navigationStack = originalNavigation
GAME.battleRoom = originalRoom
GAME.netClient.state = originalNetState
love.window.showMessageBox = originalMessageBox
GraphicsUtil.print = originalPrint
input.isDown = originalInputDown
assert(success, err)
