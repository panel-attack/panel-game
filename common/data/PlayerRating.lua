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
  end
)

PlayerRating.RATING_PERIOD_IN_SECONDS = 60 * 60 * 16
PlayerRating.ALLOWABLE_RATING_SPREAD = 400

PlayerRating.STARTING_RATING = 1500

PlayerRating.STARTING_RATING_DEVIATION = 250
PlayerRating.MAX_RATING_DEVIATION = 350
PlayerRating.PROVISIONAL_RATING_DEVIATION = 125

PlayerRating.STARTING_VOLATILITY = 0.06
PlayerRating.MAX_VOLATILITY = PlayerRating.STARTING_VOLATILITY

-- Returns the rating period number for the given timestamp
function PlayerRating.ratingPeriodForTimeStamp(timestamp)
  local ratingPeriod = math.floor(timestamp / (PlayerRating.RATING_PERIOD_IN_SECONDS))
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

-- Returns an array of result objects representing the players wins against the given player
-- Really only meant for testing.
function PlayerRating:createSetResults(opponent, player1WinCount, gameCount)
  
  assert(gameCount >= player1WinCount)

  local matchSet = {}
  for i = 1, player1WinCount, 1 do
    matchSet[#matchSet+1] = 1
  end
  for i = 1, gameCount - player1WinCount, 1 do
    matchSet[#matchSet+1] = 0
  end
    
  local player1Results = {}
  for j = 1, #matchSet do -- play through games
    local matchOutcome = matchSet[j]
    local gameResult = self:createGameResult(opponent, matchOutcome)
    if gameResult then
      player1Results[#player1Results+1] = gameResult
    end
  end

  return player1Results
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

-- Runs one "rating period" with the given results for the player.
-- To get the accurate rating of a player, this must be run on every rating period since the last time they were updated.
function PlayerRating:newRatingForRatingPeriodWithResults(gameResults)
  local updatedGlicko = self.glicko:update(gameResults)
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
