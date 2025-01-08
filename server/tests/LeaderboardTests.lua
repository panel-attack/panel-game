local ServerGame = require("server.Game")
local Leaderboard = require("server.Leaderboard")
local LevelPresets = require("common.data.LevelPresets")
local GameModes = require("common.engine.GameModes")
-- we don't want to test the persistence part here, do that explicitly elsewhere instead
local MockPersistence = require("server.tests.MockPersistence")
local ServerTesting = require("server.tests.ServerTesting")

local leaderboard = Leaderboard(GameModes.getPreset("TWO_PLAYER_VS"), MockPersistence)
leaderboard.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT = 2
leaderboard.consts.RATING_SPREAD_MODIFIER = 400
leaderboard.consts.ALLOWABLE_RATING_SPREAD_MULTIPLIER = .9
leaderboard.consts.K = 10
leaderboard.consts.PLACEMENT_MATCH_K = 50
leaderboard.consts.PLACEMENT_MATCHES_ENABLED = true
leaderboard.consts.MIN_LEVEL_FOR_RANKED = 1
leaderboard.consts.MAX_LEVEL_FOR_RANKED = 10

for i, player in ipairs(ServerTesting.players) do
  ServerTesting.addToLeaderboard(leaderboard, player)
end

local p1 = ServerTesting.players[1]
local p2 = ServerTesting.players[2]
local p3 = ServerTesting.players[3]
local p4 = ServerTesting.players[4]
local p5 = ServerTesting.players[5]
local p6 = ServerTesting.players[6]

assert(leaderboard.players[p2.userId].rating == 1732)
assert(leaderboard.players[p2.userId].placement_done)
assert(leaderboard.players[p4.userId].rating == 1500)
assert(not leaderboard.players[p4.userId].placement_done)
assert(leaderboard.players[p4.userId].placement_rating == 1300)

local function testRankedApproved()
  -- two unrated players cannot play ranked
  assert(not leaderboard:rating_adjustment_approved({p1, p4}))
  -- same unmodified legal level, both rated, both controller, in ranked range
  assert(leaderboard:rating_adjustment_approved({p2, p3}))
  -- rating too far apart
  assert(not leaderboard:rating_adjustment_approved({p2, p6}))
  -- rating too far apart even though p1 is unranked
  assert(not leaderboard:rating_adjustment_approved({p1, p6}))

  p4:updateSettings({inputMethod = "touch"})
  -- touch is illegal
  assert(not leaderboard:rating_adjustment_approved({p3, p4}))
  p4:updateSettings({inputMethod = "controller"})

  -- illegal level
  p5:updateSettings({level = 11})
  assert(not leaderboard:rating_adjustment_approved({p3, p5}))
  -- different levels
  p5:updateSettings({level = 8})
  assert(not leaderboard:rating_adjustment_approved({p3, p5}))

  -- modified level data
  p5:updateSettings({level = 10, levelData = LevelPresets.getModern(8)})
  assert(not leaderboard:rating_adjustment_approved({p3, p5}))
  p5:updateSettings({level = 10, levelData = LevelPresets.getModern(10)})

  -- same unmodified legal level, both rated, both controller, in ranked range even though p1 is unranked
  assert(leaderboard:rating_adjustment_approved({p1, p2}))

  -- same unmodified legal level, both rated, both controller, but not in hidden ranked range
  assert(not leaderboard:rating_adjustment_approved({p4, p2}))
end

local function testSimpleGameProcessing()
  local game = ServerGame({p2, p3})
  p2.opponent = p3
  p3.opponent = p2
  game.winnerId = p2.publicPlayerID

  local ratingChanges = leaderboard:processGameResult(game)
  assert(ratingChanges[1].userId == p2.userId)
  assert(ratingChanges[1].old == 1732)
  assert(ratingChanges[2].old == 1458)
  assert(math.round(ratingChanges[1].new, 8) == 1733.71182352)
  assert(ratingChanges[1].difference == - ratingChanges[2].difference)
  -- Check if the rating update also has been applied on the leaderboard
  assert(leaderboard:getRating(p2) == ratingChanges[1].new)
  assert(leaderboard:getRating(p3) == ratingChanges[2].new)

  p2.opponent = nil
  p3.opponent = nil
end

local function testImpossibleGameProcessing()
  local game = ServerGame({p1, p4})
  game.winnerId = p1.publicPlayerID
  p1.opponent = p4
  p4.opponent = p1

  local ratingChanges = leaderboard:processGameResult(game)

  assert(#ratingChanges == 0)

  game = ServerGame({p1})
  game.winnerId = p1.publicPlayerID
  p1.opponent = p1

  ratingChanges = leaderboard:processGameResult(game)

  assert(#ratingChanges == 0)
end

local function testPlacementGameProcessing()
  local game = ServerGame({p4, p5})
  game.winnerId = p5.publicPlayerID
  p4.opponent = p5
  p5.opponent = p4

  local ratingChanges = leaderboard:processGameResult(game)

  assert(ratingChanges[2].difference == 0)
  assert(not ratingChanges[2].placement_match_progress)
  assert(ratingChanges[1].difference < -30)
  assert(ratingChanges[1].placement_match_progress)
  -- the official rating has not changed
  assert(leaderboard.players[p4.userId].rating == leaderboard.consts.DEFAULT_RATING)
  -- only the placement rating
  assert(leaderboard:getRating(p4) ~= leaderboard.consts.DEFAULT_RATING)
  assert(ratingChanges[1].ranked_games_played == 1)
  assert(ratingChanges[1].ranked_games_won == 0)
  -- games played against unranked players don't exist until placement is finished (lol wat)
  assert(ratingChanges[2].ranked_games_played == 0)
  assert(ratingChanges[2].ranked_games_won == 0)

  -- processing the same game twice should probably be illegal
  -- game ID should ideally get assigned right before the game is processed for the first
  -- and then the leaderboard can save the ID and verify if it has processed the same game already
  -- in realistic terms though, we just discard the game after it was processed so whatever
  ratingChanges = leaderboard:processGameResult(game)

  -- getting more than usually possible in one game due to placement finishing
  assert(ratingChanges[2].difference > 10)
  assert(not ratingChanges[1].placement_match_progress)

  assert(ratingChanges[1].ranked_games_played == 2)
  assert(ratingChanges[1].ranked_games_won == 0)
  assert(ratingChanges[2].ranked_games_played == 2)
  assert(ratingChanges[2].ranked_games_won == 2)
end

testRankedApproved()
testSimpleGameProcessing()
testImpossibleGameProcessing()
testPlacementGameProcessing()