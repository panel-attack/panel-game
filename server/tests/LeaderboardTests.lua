local Player = require("server.Player")
local ServerGame = require("server.Game")
local Leaderboard = require("server.Leaderboard")
local MockConnection = require("server.tests.MockConnection")
local LevelPresets = require("common.data.LevelPresets")

local leaderboard = Leaderboard("mock")
-- we don't want to test the persistence part
leaderboard:disconnectSignal("placementMatchesProcessed", leaderboard)
leaderboard:disconnectSignal("gameResultProcessed", leaderboard)

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
  if not rating then
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

local function testGameProcessing()
  
end

testRankedApproved()
--testGameProcessing()

