local Player = require("server.Player")
local ServerGame = require("server.Game")
local Leaderboard = require("server.Leaderboard")
local MockConnection = require("server.tests.MockConnection")
local LevelPresets = require("common.data.LevelPresets")

local leaderboard = Leaderboard("mock")
-- we don't want to test the persistence part
leaderboard:disconnectSignal("placementMatchesProcessed", leaderboard)
leaderboard:disconnectSignal("gameResultProcessed", leaderboard)
leaderboard:disconnectSignal("placementMatchAdded", leaderboard)
leaderboard.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT = 2
leaderboard.consts.RATING_SPREAD_MODIFIER = 400
leaderboard.consts.ALLOWABLE_RATING_SPREAD_MULTIPLIER = .9
leaderboard.consts.K = 10
leaderboard.consts.PLACEMENT_MATCH_K = 50
leaderboard.consts.PLACEMENT_MATCHES_ENABLED = true
leaderboard.consts.MIN_LEVEL_FOR_RANKED = 1
leaderboard.consts.MAX_LEVEL_FOR_RANKED = 10

local p1 = Player(1, MockConnection(), "Bob", 4)
local p2 = Player(2, MockConnection(), "Alice", 5)
local p3 = Player(3, MockConnection(), "Ben", 8)
local p4 = Player(4, MockConnection(), "Jerry", 24)
local p5 = Player(5, MockConnection(), "Berta", 38)
local p6 = Player(6, MockConnection(), "Raccoon", 83)
p1:updateSettings({inputMethod = "controller", level = 10})
p2:updateSettings({inputMethod = "controller", level = 10})
p3:updateSettings({inputMethod = "controller", level = 10})
p4:updateSettings({inputMethod = "controller", level = 10})
p5:updateSettings({inputMethod = "controller", level = 10})
p6:updateSettings({inputMethod = "controller", level = 10})

local defaultRating = 1500

local function addToLeaderboard(lb, player, placementDone, rating)
  lb.players[player.userId] = {user_name = player.name, placement_done = placementDone}
  if not placementDone then
    lb.loadedPlacementMatches.incomplete[player.userId] = {}
    lb.players[player.userId].placement_rating = rating or defaultRating
    lb.players[player.userId].rating = defaultRating
  else
    lb.players[player.userId].rating = rating or defaultRating
  end
end

addToLeaderboard(leaderboard, p1, false, 1500)
addToLeaderboard(leaderboard, p2, true, 1732)
addToLeaderboard(leaderboard, p3, true, 1458)
addToLeaderboard(leaderboard, p4, false, 1300)
addToLeaderboard(leaderboard, p5, true, 1222)
addToLeaderboard(leaderboard, p6, true, 432)

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
  
  -- processing the same game twice should probably be illegal
  -- game ID should ideally get assigned right before the game is processed for the first
  -- and then the leaderboard can save the ID and verify if it has processed the same game already
  -- in realistic terms though, we just discard the game after it was processed so whatever
  ratingChanges = leaderboard:processGameResult(game)

  -- getting more than usually possible in one game due to placement finishing
  assert(ratingChanges[2].difference > 10)
  assert(not ratingChanges[1].placement_match_progress)
end

testRankedApproved()
testSimpleGameProcessing()
testImpossibleGameProcessing()
testPlacementGameProcessing()