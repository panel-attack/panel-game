local ModLoader = require("client.src.mods.ModLoader")
local ModController = require("client.src.mods.ModController")
local Player = require("client.src.Player")
local StageLoader = require("client.src.mods.StageLoader")
local CharacterLoader = require("client.src.mods.CharacterLoader")
local consts = require("common.engine.consts")
local Stage = require("client.src.mods.Stage")

-- caveat: this test is not as effective if you have no character bundles installed
local function testModBundleSelection()
  local p1 = Player("P1", -1, false)

  for i = 1, 1000 do
    p1:setCharacter(consts.RANDOM_CHARACTER_SPECIAL_VALUE)
    assert(p1.settings.characterId ~= consts.RANDOM_CHARACTER_SPECIAL_VALUE,
    "the actual stage coming out of the random bundle should never be the random bundle itself")
    assert(not characters[p1.settings.characterId]:is_bundle(),
    "the actual stage coming out of the random bundle should never be another bundle")
  end

  -- all those setCharacter queued up a load so clean up the ModLoader
  ModLoader.loading_queue = Queue() -- mods to load
  ModLoader.cancellationList = {}
  ModLoader.loading_mod = nil -- currently loading mod
  ModLoader.wait()
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