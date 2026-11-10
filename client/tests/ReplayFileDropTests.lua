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
local fileUtils = require("client.src.FileUtils")
local ClientMatch = require("client.src.ClientMatch")
local ReplayV3 = require("common.data.ReplayV3")

local originalNavigation = GAME.navigationStack
local originalRoom = GAME.battleRoom
local originalNetState = GAME.netClient.state
local originalMessageBox = love.window.showMessageBox
local originalPrint = GraphicsUtil.print
local originalInputDown = input.isDown
local originalLastReplayPath = GAME.lastReplayPath
local replayTestDirectory
local cancelSounds = 0
local originalCancelSfx = GAME.theme.playCancelSfx
local displayed = {}
local liveMatches = {}

---@param file love.File
---@return boolean
local function handleReplayFileDrop(file)
  return GAME:onFileDropped(file)
end

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
  cancelSounds = 0
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
  assert(cancelSounds == 0)

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

local function testDropReturnsToBrowserFromOtherMenus()
  local menu = resetNavigation()
  GAME.navigationStack:push(testMenu("NestedOfflineMenu"))
  finishTransition()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()))))
  local browser = finishTransition()
  if not browser then
    browser = finishTransition()
  end
  assert(browser.name == "ReplayBrowser")
  assert(#GAME.navigationStack.scenes == 2 and GAME.navigationStack.scenes[1] == menu,
    "Opening a replay from another menu should return to the main menu before pushing the browser")

  local scene = confirmReplay(browser)
  local match = scene.match
  local deinit = match.deinit
  local deinitializations = 0
  match.deinit = function(self)
    deinitializations = deinitializations + 1
    liveMatches[self] = nil
    deinit(self)
  end
  GAME.navigationStack:push(testMenu("OfflineOverlayMenu"))
  finishTransition()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()), "from-overlay.txt")))
  assert(match.engine.aborted)
  assert(deinitializations == 0, "Replay cleanup must wait for the transition")
  assert(finishTransition() == browser)
  assert(deinitializations == 1)
  assert(#GAME.navigationStack.scenes == 2, "Returning to the browser must remove intervening menus and playback")
  browser:draw()
  assertDisplayed("from-overlay.txt")
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
    assert(cancelSounds == 1)
    assert(calls.closes == 1, "Invalid JSON must not leave the dropped file open")
  end

  for _, filename in ipairs({"replay.txt", "replay.json.bak", "replay"}) do
    resetNavigation()
    local file, calls = droppedFile(json.encode(makeReplayData()), filename)
    assert(handleReplayFileDrop(file), "Valid replay contents must not require a .json extension")
    assert(calls.opens == 1 and calls.closes == 1 and cancelSounds == 0)
    finishTransition():draw()
    assertDisplayed(filename)
  end

  for _, failure in ipairs({"open", "read", "close"}) do
    local menu = resetNavigation()
    local file, calls = droppedFile("{}", nil, failure)
    assert(not handleReplayFileDrop(file))
    assert(GAME.navigationStack:getActiveScene() == menu and cancelSounds == 1)
    assert(calls.closes == (failure == "open" and 0 or 1))
  end
end

---@param replay table
---@param scene Scene
local function assertRejectedReplay(replay, scene)
  local priorCancels = cancelSounds
  local file, calls = droppedFile(json.encode(replay))
  assert(not handleReplayFileDrop(file), "Malformed replay should be rejected before changing scenes")
  assert(calls.closes == 1)
  assert(cancelSounds == priorCancels + 1)
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
    "A",
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
      assert(calls.opens == 0 and cancelSounds == 1)
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
    assert(calls.opens == 0 and cancelSounds == 1)
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
      assert(ReplayBrowser.createFromReplayFile(love.filesystem.newFile(path .. filename)),
        "Could not read browser fixture " .. filename)
      assert(handleReplayFileDrop(droppedFile(contents, filename)), "Could not open fixture " .. filename)
      finishTransition():draw()
      assertDisplayed(loc("rp_browser_info_header"))
    end
  end
end

local function testBrowserUsesSharedLoading()
  local directory = "replays/__ReplayFileDropTests"
  assert(not love.filesystem.getInfo(directory), "Replay test directory must not overwrite existing files")
  assert(love.filesystem.createDirectory(directory))
  replayTestDirectory = directory
  GAME.lastReplayPath = directory
  local path = directory .. "/test.json"

  local function selectReplayFile(contents)
    resetNavigation()
    assert(love.filesystem.write(path, contents))
    local browser = ReplayBrowser({})
    GAME.navigationStack:push(browser)
    finishTransition()
    input.isDown.MenuDown = 1
    browser:update()
    input.isDown.MenuDown = nil
    input.isDown.MenuSelect = 1
    browser:update()
    input.isDown.MenuSelect = nil
    browser:draw()
    return browser
  end

  local browser = selectReplayFile(json.encode(makeReplayData()))
  assertDisplayed(loc("rp_browser_info_header"))
  assertDisplayed(path)
  assert(cancelSounds == 0)
  local scene = confirmReplay(browser)
  scene:update(1 / 60)
  assert(scene.match.engine.clock > 0, "A browser-selected replay should still play")

  local invalidContents = {"{}", "{broken json", json.encode(makeReplayData()) .. " {}"}
  local malformed = makeReplayData()
  malformed.metadata.stacks[1].level = true
  invalidContents[#invalidContents + 1] = json.encode(malformed)
  malformed = makeReplayData()
  malformed.stacks[1].inputs = "A300~1"
  invalidContents[#invalidContents + 1] = json.encode(malformed)
  for _, contents in ipairs(invalidContents) do
    browser = selectReplayFile(contents)
    assertDisplayed(loc("rp_browser_header"))
    assert(not displayed[loc("rp_browser_info_header")], "Invalid browser selections should not show replay details")
    assert(GAME.navigationStack:getActiveScene() == browser)
    assert(cancelSounds == 1)
  end

  assert(love.filesystem.write(path, "{} {}"))
  assert(fileUtils.readJsonFile(path), "Other JSON callers should retain their existing trailing-data behavior")
  local value, failure = fileUtils.readJsonFile(path, true)
  assert(value == nil and failure == "decode", "Replay files must not accept trailing JSON values")
end

local function testLoadingDoesNotCreateMatch()
  resetNavigation()
  local data = makeReplayData()
  local originalCreate = Match.createFromReplay
  local creations = 0
  Match.createFromReplay = function()
    creations = creations + 1
    error("Loading replay data must not construct a match")
  end
  local success, err = pcall(function()
    assert(ReplayV3.validate(data))
    assert(ReplayBrowser.createFromReplayFile(droppedFile(json.encode(data))))
    assert(handleReplayFileDrop(droppedFile(json.encode(data))))
  end)
  Match.createFromReplay = originalCreate
  assert(success, err)
  assert(creations == 0)
end

local function testBrowserPropagatesPlaybackFailure()
  resetNavigation()
  assert(handleReplayFileDrop(droppedFile(json.encode(makeReplayData()))))
  local browser = finishTransition()
  local originalCreate = ClientMatch.createFromReplay
  ClientMatch.createFromReplay = function()
    error("Unexpected replay setup bug")
  end
  local success, err = pcall(browser.playReplay, browser)
  ClientMatch.createFromReplay = originalCreate
  assert(not success and tostring(err):find("Unexpected replay setup bug", 1, true),
    "Unexpected playback errors must propagate instead of being reported as invalid files")
  assert(GAME.navigationStack:getActiveScene() == browser)
  assert(cancelSounds == 0)
end

local function runTests()
  love.window.showMessageBox = function()
    error("Replay loading must not open a modal dialog")
  end
  GAME.theme.playCancelSfx = function()
    cancelSounds = cancelSounds + 1
  end
  GraphicsUtil.print = function(text)
    displayed[text] = true
  end
  testDropShowsDetailsBeforePlaying()
  testReplacingPlaybackReusesBrowserAndCleansUp()
  testDropIntoBrowserAndBackNavigation()
  testDropReturnsToBrowserFromOtherMenus()
  testRejectedFilesKeepTheCurrentScene()
  testRejectsMalformedDisplayMetadata()
  testRejectsInvalidInputSymbols()
  testValidControllerAndTouchInputStreams()
  testUnavailableStatesDoNotReadTheFile()
  testIncompatibleVersionUsesExistingWarning()
  testLegacyReplayFiles()
  testBrowserUsesSharedLoading()
  testLoadingDoesNotCreateMatch()
  testBrowserPropagatesPlaybackFailure()
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
GAME.theme.playCancelSfx = originalCancelSfx
GraphicsUtil.print = originalPrint
input.isDown = originalInputDown
if replayTestDirectory then
  assert(love.filesystem.remove(replayTestDirectory .. "/test.json"))
  assert(love.filesystem.remove(replayTestDirectory))
  GAME.lastReplayPath = originalLastReplayPath or "replays"
  ReplayBrowser({})
end
GAME.lastReplayPath = originalLastReplayPath
assert(success, err)
