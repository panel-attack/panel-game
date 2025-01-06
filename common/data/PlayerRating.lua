local Glicko2 = require("common.data.Glicko")
local class = require("common.lib.class")

-- Represents the rating for a player
PlayerRating =
  class(
  function(self, rating, ratingDeviation, maxRatingDeviation, volatility, maxVolatility)
    rating = rating or self.STARTING_RATING
    ratingDeviation = ratingDeviation or self.STARTING_RATING_DEVIATION
    self.maxRatingDeviation = maxRatingDeviation or PlayerRating.MAX_RATING_DEVIATION
    volatility = volatility or self.STARTING_VOLATILITY
    self.maxVolatility = maxVolatility or PlayerRating.MAX_VOLATILITY
    self.glicko = Glicko2.g1(rating, ratingDeviation, volatility)
    self.lastRatingPeriodCalculated = nil
  end
)

PlayerRating.RATING_PERIOD_IN_SECONDS = 60 * 60 * 16
PlayerRating.ALLOWABLE_RATING_SPREAD = 400

PlayerRating.STARTING_RATING = 1500

PlayerRating.STARTING_RATING_DEVIATION = 200
PlayerRating.MAX_RATING_DEVIATION = PlayerRating.STARTING_RATING_DEVIATION
PlayerRating.PROVISIONAL_RATING_DEVIATION = 125

PlayerRating.STARTING_VOLATILITY = 0.06
PlayerRating.MAX_VOLATILITY = 0.3

-- Returns the rating period number for the given timestamp
function PlayerRating.ratingPeriodForTimeStamp(timestamp)
  local ratingPeriod = timestamp / (PlayerRating.RATING_PERIOD_IN_SECONDS)
  return ratingPeriod
end

function PlayerRating.timestampForRatingPeriod(ratingPeriod)
  local timestamp = ratingPeriod * PlayerRating.RATING_PERIOD_IN_SECONDS
  return timestamp
end

function PlayerRating:copy()
  local result = deepcpy(self)
  return result
end

function PlayerRating:getRating()
  return self.glicko.Rating
end

-- Returns a percentage value (0-1) of how likely the rating thinks the player is to win
function PlayerRating:expectedOutcome(opponent)
  return self.glicko:expectedOutcome(opponent.glicko)
end

-- Returns if the player is still "provisional"
-- Provisional is only used to change how the UI looks to help the player know this rating is not accurate yet.
function PlayerRating:isProvisional()
  return self.glicko.RD >= PlayerRating.PROVISIONAL_RATING_DEVIATION
end

-- Returns an array of wins vs total games
-- The wins / losses will be distributed by the ratio to try to balance it out.
-- Really only meant for testing.
function PlayerRating.createTestSetResults(player1WinCount, gameCount)
  
  assert(gameCount >= player1WinCount)

  local matchSet = {}
  for i = 1, gameCount - player1WinCount, 1 do
    matchSet[#matchSet+1] = 0
  end

  local step = gameCount / player1WinCount
  local position = 1
  for i = 1, player1WinCount, 1 do
    matchSet[math.round(position)] = 1
    position = position + step
  end

  return matchSet
end

-- Helper function to create one game result with the given outcome if the players are allowed to rank.
function PlayerRating:createGameResult(opponent, matchOutcome)
  local result = nil

  if math.abs(self:getRating() - opponent:getRating()) <= PlayerRating.ALLOWABLE_RATING_SPREAD then
    result = opponent.glicko:score(matchOutcome)
  end

  return result
end

function PlayerRating.invertedGameResult(gameResult)
  if gameResult == 0 then
    return 1
  end
  if gameResult == 1 then
    return 0
  end
  -- Ties stay 0.5
  return gameResult
end

function PlayerRating:newRatingForResultsAndLatestRatingPeriod(gameResult, latestRatingPeriodFound)
  local updatedPlayer = self
  if updatedPlayer.lastRatingPeriodCalculated == nil then
    updatedPlayer = self:copy()
    updatedPlayer.lastRatingPeriodCalculated = latestRatingPeriodFound
  end
  local elapsedRatingPeriods = latestRatingPeriodFound - updatedPlayer.lastRatingPeriodCalculated
  if elapsedRatingPeriods > 0 then
    updatedPlayer = updatedPlayer:newRatingForResultsAndElapsedRatingPeriod(gameResult, elapsedRatingPeriods)
  end

  return updatedPlayer
end

-- Runs the given results for the player with the given elapsedRatingPeriod
function PlayerRating:newRatingForResultsAndElapsedRatingPeriod(gameResult, elapsedRatingPeriods)
  local updatedPlayer = self

  if elapsedRatingPeriods > 0 then
    updatedPlayer = updatedPlayer:privateNewRatingForResultWithElapsedRatingPeriod(nil, elapsedRatingPeriods)
    if updatedPlayer.lastRatingPeriodCalculated then
      updatedPlayer.lastRatingPeriodCalculated = self.lastRatingPeriodCalculated + elapsedRatingPeriods
    end
  end

  updatedPlayer = updatedPlayer:privateNewRatingForResultWithElapsedRatingPeriod(gameResult, 0)

  return updatedPlayer
end

function PlayerRating:privateNewRatingForResultWithElapsedRatingPeriod(gameResult, elapsedRatingPeriods)
  local gameResults = {}
  if gameResult then
    gameResults[#gameResults+1] = gameResult
  end
  local updatedGlicko = self.glicko:update(gameResults, elapsedRatingPeriods)
  if updatedGlicko.RD > self.maxRatingDeviation then
    updatedGlicko.RD = self.maxRatingDeviation
  end
  if updatedGlicko.Vol > self.maxVolatility then
    updatedGlicko.Vol = self.maxVolatility
  end
  local updatedPlayer = self:copy()
  updatedPlayer.glicko = updatedGlicko
  return updatedPlayer
end

return PlayerRating
