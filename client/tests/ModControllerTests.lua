local ModLoader = require("client.src.mods.ModLoader")
local ModController = require("client.src.mods.ModController")
local Player = require("client.src.Player")
local StageLoader = require("client.src.mods.StageLoader")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local consts = require("common.engine.consts")
local Stage = require("client.src.mods.Stage")
local GameModes = require("common.data.GameModes")
local BattleRoom = require("client.src.BattleRoom")

-- setCharacter/setStage queue up mod loads, discard them so they don't leak into later tests
local function clearModLoadQueue()
  ModLoader.loading_queue = Queue() -- mods to load
  ModLoader.cancellationList = {}
  ModLoader.loading_mod = nil -- currently loading mod
  ModLoader.wait()
end

-- caveat: this test is not as effective if you have no character bundles installed
local function testModBundleSelection()
  local p1 = Player("P1", -1, false)

  for i = 1, 1000 do
    p1:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
    assert(p1.settings.characterId ~= consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    "the actual stage coming out of the random bundle should never be the random bundle itself")
    assert(not characters[p1.settings.characterId]:isBundle(),
    "the actual stage coming out of the random bundle should never be another bundle")
  end

  clearModLoadQueue()
end

local function addToStageGlobals(stage)
  allStages[stage.id] = stage
  stageIds[#stageIds+1] = stage.id
  stages[stage.id] = stage
  visibleStages[#visibleStages+1] = stage.id
end

local function addFakeStage(id)
  local stage = Stage("client/assets/stages/__default", id)
  stage:preload()
  addToStageGlobals(stage)
  return stage
end

local function addFakeBundleStage(id, ...)
  local bundleStage = Stage("client/assets/stages/__default", id)
  for i, stage in ipairs({...}) do
    bundleStage.subIds[#bundleStage.subIds+1] = stage.id
  end
  addToStageGlobals(bundleStage)
  return bundleStage
end

-- this test was originally developed to troubleshoot an issue under an assumption that no longer seems to be valid:
-- namely the assumption was that players could hold onto bundle mods and by doing so all sub mods would not get unloaded
-- even if another user using another bundle mod that had an intersect in sub mods deselected theirs
-- the original idea behind this was that bundle users shouldn't have to wait for load/unload every time their bundle is repicked
-- in practical terms things have been changed so that only non-bundles should get loaded by the modcontroller ever
-- the test is going to be kept in case bundle claiming is going to be reintroduced at some time
local function testSubModCrossCheck()
  StageLoader.initStages()
  ModLoader.wait()

  local p1 = Player("P1", -1, true)
  local p2 = Player("P2", -2, false)

  local s1 = addFakeStage("1")
  local s2 = addFakeStage("2")
  local s3 = addFakeStage("3")

  local b1 = addFakeBundleStage("4", s1, s2)
  local b2 = addFakeBundleStage("5", s2, s3)

  while p1.settings.stageId ~= "2" do
    p1:setStage(b1.id)
    ModController:update()
    ModLoader.wait()
  end

  p2:setStage(b2.id)
  ModController:update()
  ModLoader.wait()
  while tonumber(p1.settings.stageId) do
    p1:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)
    ModController:update()
  end

  assert(stages["2"].fullyLoaded, "mod 2 should not be unloaded as it is part of a still claimed bundle")

  -- reinit equals a cleanup
  StageLoader.initStages()
end

-- technically bundles should never be loaded via loadModFor
-- this test exists to increase likelihood that things aren't breaking when a bundle loads/unloads
local function testInadvertentBundleLoading()
  local p1 = Player("P1", -1, true)
  local p2 = Player("P2", -2, false)

  local s1 = addFakeStage("1")
  local s2 = addFakeStage("2")
  local s3 = addFakeStage("3")

  local b1 = addFakeBundleStage("4", s1, s2, s3)

  p1:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)
  ModController:update()
  ModLoader.wait()

  -- this should never happen but let's try it anyway
  p2.settings.stageId = consts.RANDOM_STAGE_SPECIAL_VALUE
  p2.settings.selectedStageId = consts.RANDOM_STAGE_SPECIAL_VALUE
  ModController:loadModFor(stages[consts.RANDOM_STAGE_SPECIAL_VALUE], p2, true)
  ModLoader.wait()
  p2:setStage("4")
  ModController:update()

  assert(stages[consts.RANDOM_STAGE_SPECIAL_VALUE].images.thumbnail)

  StageLoader.initStages()
end

testModBundleSelection()

--testSubModCrossCheck()  -- see comment on function
testInadvertentBundleLoading()

-- mirrors how BattleRoom.createLocalFromGameMode sets up 1P modes, without depending on input configurations
local function createVsSelfRoomWithLocalPlayer()
  local battleRoom = BattleRoom(GameModes.getPreset(GameModes.IDs.ONE_PLAYER_VS_SELF))
  battleRoom:addPlayer(GAME.localPlayer)
  return battleRoom
end

-- https://github.com/panel-attack/panel-game/issues/769
-- With random selected, disabling the character/stage that random resolved to in ModManagement
-- left GAME.localPlayer pointing at a mod that no longer exists, crashing the next BattleRoom:updateLoadingState
local function testDisablingResolvedRandomSelectionsDoesNotCrash()
  local player = GAME.localPlayer
  local originalCharacterId = player.settings.selectedCharacterId
  local originalStageId = player.settings.selectedStageId

  player:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
  player:setStage(consts.RANDOM_STAGE_SPECIAL_VALUE)

  local battleRoom = createVsSelfRoomWithLocalPlayer()
  local resolvedCharacter = characters[player.settings.characterId]
  local resolvedStage = stages[player.settings.stageId]
  assert(resolvedCharacter and not resolvedCharacter:isBundle(), "random should resolve to a concrete character")
  assert(resolvedStage and not resolvedStage:isBundle(), "random should resolve to a concrete stage")
  battleRoom:shutdown()

  -- what ModManagement does when the user toggles both mods off
  resolvedCharacter:enable(false)
  resolvedStage:enable(false)
  player:refreshDisabledSelections()

  local success, err = pcall(function()
    battleRoom = createVsSelfRoomWithLocalPlayer()
    battleRoom:updateLoadingState()
  end)
  local newCharacterId = player.settings.characterId
  local newStageId = player.settings.stageId

  -- restore global state before asserting so a failure doesn't leak into later tests
  if not battleRoom.hasShutdown then
    battleRoom:shutdown()
  end
  resolvedCharacter:enable(true)
  resolvedStage:enable(true)
  player:setCharacter(originalCharacterId)
  player:setStage(originalStageId)
  clearModLoadQueue()

  assert(success, "re-entering a mode after disabling the resolved random mods crashed: " .. tostring(err))
  assert(newCharacterId ~= resolvedCharacter.id, "player still uses disabled character " .. resolvedCharacter.id)
  assert(newStageId ~= resolvedStage.id, "player still uses disabled stage " .. resolvedStage.id)
end

-- disabling the explicitly selected mods should fall back to random rather than a concrete pick
local function testDisablingSelectedModsFallsBackToRandom()
  local player = GAME.localPlayer
  local originalCharacterId = player.settings.selectedCharacterId
  local originalStageId = player.settings.selectedStageId

  local selectedCharacter = characters[CharacterLoader.fullyResolveCharacterSelection(nil)]
  local selectedStage = stages[StageLoader.fullyResolveStageSelection(nil)]
  player:setCharacter(selectedCharacter.id)
  player:setStage(selectedStage.id)
  assert(player.settings.selectedCharacterId == selectedCharacter.id)
  assert(player.settings.selectedStageId == selectedStage.id)

  selectedCharacter:enable(false)
  selectedStage:enable(false)
  player:refreshDisabledSelections()
  local settings = shallowcpy(player.settings)

  selectedCharacter:enable(true)
  selectedStage:enable(true)
  player:setCharacter(originalCharacterId)
  player:setStage(originalStageId)
  clearModLoadQueue()

  assert(settings.selectedCharacterId == consts.RANDOM_CHARACTER_SPECIAL_VALUE,
         "expected random character selection, got " .. tostring(settings.selectedCharacterId))
  assert(settings.selectedStageId == consts.RANDOM_STAGE_SPECIAL_VALUE,
         "expected random stage selection, got " .. tostring(settings.selectedStageId))
  assert(settings.characterId ~= selectedCharacter.id, "player still uses disabled character " .. selectedCharacter.id)
  assert(settings.stageId ~= selectedStage.id, "player still uses disabled stage " .. selectedStage.id)
end

testDisablingResolvedRandomSelectionsDoesNotCrash()
testDisablingSelectedModsFallsBackToRandom()