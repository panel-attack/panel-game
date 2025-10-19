local Player = require("client.src.Player")
local GameModes = require("common.data.GameModes")
local LevelPresets = require("common.data.LevelPresets")
local CharacterSelect = require("client.src.scenes.CharacterSelect")
local BattleRoom = require("client.src.BattleRoom")

local function testDifficultyCarouselShouldNotMutatePlayerOnCreation()

  local player = Player("TestPlayer", 1, true)
  player:setStyle(GameModes.Styles.MODERN)
  player:setDifficulty(1)
  player:setLevel(10)
  player:setLevelData(LevelPresets.getModern(10))

  local originalLevel = player.settings.level
  local originalDifficulty = player.settings.difficulty
  local originalStyle = player.settings.style
  local originalGarbageHover = player.settings.levelData.frameConstants.GARBAGE_HOVER
  local originalColorCount = player.settings.levelData.colors

  assert(originalLevel == 10, "Initial level should be 10")
  assert(originalStyle == GameModes.Styles.MODERN, "Initial style should be MODERN")
  assert(originalGarbageHover == 4, "Initial GARBAGE_HOVER should be 4")
  assert(originalColorCount == 6, "Initial color count should be 6")

  local gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  local battleRoom = BattleRoom(gameMode)
  battleRoom:addPlayer(player)

  local characterSelect = CharacterSelect({battleRoom = battleRoom})

  local _ = characterSelect:createDifficultyCarousel(player, 100)

  assert(player.settings.level == originalLevel, "createDifficultyCarousel should not change level, but changed from " .. originalLevel .. " to " .. player.settings.level)
  assert(player.settings.difficulty == originalDifficulty, "createDifficultyCarousel should not change difficulty, but changed from " .. tostring(originalDifficulty) .. " to " .. tostring(player.settings.difficulty))
  assert(player.settings.style == originalStyle, "createDifficultyCarousel should not change style, but changed from " .. originalStyle .. " to " .. player.settings.style)
  assert(player.settings.levelData.frameConstants.GARBAGE_HOVER == originalGarbageHover, "createDifficultyCarousel should not change GARBAGE_HOVER, but changed from " .. tostring(originalGarbageHover) .. " to " .. tostring(player.settings.levelData.frameConstants.GARBAGE_HOVER))
  assert(player.settings.levelData.colors == originalColorCount, "createDifficultyCarousel should not change color count, but changed from " .. originalColorCount .. " to " .. player.settings.levelData.colors)

  battleRoom:shutdown()
end

testDifficultyCarouselShouldNotMutatePlayerOnCreation()

local function testAllModernLevelsHaveGarbageHover()
  for level = 1, 11 do
    local levelData = LevelPresets.getModern(level)
    assert(levelData.frameConstants.GARBAGE_HOVER ~= nil, "Modern level " .. level .. " should have GARBAGE_HOVER")
    assert(levelData.frameConstants.GARBAGE_HOVER ~= nil,
      "Modern level " .. level .. " GARBAGE_HOVER should not be nil")
  end
end

testAllModernLevelsHaveGarbageHover()

local function testAllClassicLevelsLackGarbageHover()
  for difficulty = 1, 4 do
    local levelData = LevelPresets.getClassic(difficulty)
    assert(levelData.frameConstants.GARBAGE_HOVER == nil,
      "Classic difficulty " .. difficulty .. " should not have GARBAGE_HOVER but got " ..
      tostring(levelData.frameConstants.GARBAGE_HOVER))
  end
end

testAllClassicLevelsLackGarbageHover()

local function testEndlessModeClassicDifficulty1SetsCorrectSettings()

  local gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  local battleRoom = BattleRoom.createLocalFromGameMode(gameMode, nil, false)

  assert(battleRoom ~= nil, "BattleRoom should be created successfully")
  assert(#battleRoom.players == 1, "BattleRoom should have exactly 1 player")

  local battleRoomPlayer = battleRoom.players[1]

  battleRoomPlayer:setPreferredStyle(GameModes.Styles.CLASSIC)
  battleRoomPlayer:setDifficulty(1)

  assert(battleRoomPlayer.settings.levelData.colors == 5,
    "Endless mode with classic difficulty 1 should have 5 colors, but got " ..
    tostring(battleRoomPlayer.settings.levelData.colors))

  assert(battleRoomPlayer.settings.levelData.adjacentDenialFrequency == 0,
    "Endless mode with classic difficulty 1 should have adjacent denial frequency of 0, but got " ..
    tostring(battleRoomPlayer.settings.levelData.adjacentDenialFrequency))

  battleRoom:shutdown()
end

testEndlessModeClassicDifficulty1SetsCorrectSettings()

local function testVsSelfChangesEndlessClassicSettingsToModern()
  -- First create an endless battle room with classic difficulty 1
  local gameMode = GameModes.getPreset("ONE_PLAYER_ENDLESS")
  local endlessBattleRoom = BattleRoom.createLocalFromGameMode(gameMode, nil, false)

  assert(endlessBattleRoom ~= nil, "Endless BattleRoom should be created successfully")

  local endlessPlayer = endlessBattleRoom.players[1]

  -- Set to classic difficulty 1 (simulating what happens in endless mode)
  endlessPlayer:setPreferredStyle(GameModes.Styles.CLASSIC)
  endlessPlayer:setDifficulty(1)

  -- Verify endless settings
  assert(endlessPlayer.settings.style == GameModes.Styles.CLASSIC,
    "Player should have classic style before vs self")
  assert(endlessPlayer.settings.levelData.colors == 5,
    "Player should have 5 colors before vs self")
  assert(endlessPlayer.settings.levelData.adjacentDenialFrequency == 0,
    "Player should have adjacent denial frequency of 0 before vs self")

  endlessBattleRoom:shutdown()

  -- Now create a vs self battle room which should change settings to modern
  local vsSelfGameMode = GameModes.getPreset("ONE_PLAYER_VS_SELF")
  local vsSelfBattleRoom = BattleRoom.createLocalFromGameMode(vsSelfGameMode, nil, false)

  assert(vsSelfBattleRoom ~= nil, "Vs self BattleRoom should be created successfully")

  local vsSelfPlayer = vsSelfBattleRoom.players[1]
  vsSelfPlayer:setLevel(10)

  assert(vsSelfPlayer.settings.levelData.frameConstants.GARBAGE_HOVER ~= nil,
    "Modern style should have GARBAGE_HOVER set")

  -- Modern levels have 6 colors (not 5 like endless classic difficulty 1)
  assert(vsSelfPlayer.settings.levelData.colors == 6,
    "Vs self should change color count to 6 (modern default), but got " ..
    tostring(vsSelfPlayer.settings.levelData.colors))

  -- Modern levels have non-zero adjacent denial frequency
  assert(vsSelfPlayer.settings.levelData.adjacentDenialFrequency > 0,
    "Vs self should have adjacent denial frequency > 0 (modern default), but got " ..
    tostring(vsSelfPlayer.settings.levelData.adjacentDenialFrequency))

  vsSelfBattleRoom:shutdown()
end

testVsSelfChangesEndlessClassicSettingsToModern()
