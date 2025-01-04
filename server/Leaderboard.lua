local class = require("common.lib.class")
local logger = require("common.lib.logger")
local database = require("server.PADatabase")
local Signal = require("common.lib.signal")

local leagues = { {league="Newcomer",     min_rating = -1000},
            {league="Copper",       min_rating = 1},
            {league="Bronze",       min_rating = 1125},
            {league="Silver",       min_rating = 1275},
            {league="Gold",         min_rating = 1425},
            {league="Platinum",     min_rating = 1575},
            {league="Diamond",      min_rating = 1725},
            {league="Master",       min_rating = 1875},
            {league="Grandmaster",  min_rating = 2025}
          }

logger.debug("Leagues")
for k, v in ipairs(leagues) do
  logger.debug(v.league .. ":  " .. v.min_rating)
end

---@class LeaderboardPlayer 
---@field user_name string?
---@field rating number
---@field placement_done boolean?
---@field placement_rating number?
---@field ranked_games_played integer?
---@field ranked_games_won integer?
---@field last_login_time integer?

-- Object that represents players rankings and placement matches, along with login times
---@class Leaderboard : Signal
---@field name string doubles as the filename without extension
---@field players table<string, LeaderboardPlayer>
---@field loadedPlacementMatches {incomplete: table, complete: table}
---@field playersPerGame integer
---@field consts table
---@overload fun(name: string): Leaderboard
local Leaderboard =
  class(
  function(self, name)
    self.name = name
    self.players = {}
    self.loadedPlacementMatches = {
      incomplete = {},
      complete = {}
    }
    self.playersPerGame = 2

    self.consts = {
      DEFAULT_RATING = 1500,
      RATING_SPREAD_MODIFIER = 400,
      PLACEMENT_MATCH_COUNT_REQUIREMENT = 30,
      ALLOWABLE_RATING_SPREAD_MULTIPLIER = .9,
      K = 10,
      PLACEMENT_MATCHES_ENABLED = true,
      PLACEMENT_MATCH_K = 50,
      MIN_LEVEL_FOR_RANKED = 1,
      MAX_LEVEL_FOR_RANKED = 10,
    }

    logger.debug("RATING_SPREAD_MODIFIER: " .. (self.consts.RATING_SPREAD_MODIFIER or "nil"))

    Signal.turnIntoEmitter(self)
    self:createSignal("placementMatchesProcessed")
    self:createSignal("gameResultProcessed")
    self:createSignal("placementMatchAdded")
    -- seems silly but by separating the persistence from the logic we can test the logic much more easily
    self:connectSignal("placementMatchesProcessed", self, self.completePlacement)
    self:connectSignal("gameResultProcessed", self, self.persistRatingChanges)
    self:connectSignal("placementMatchAdded", self, self.persistPlacementMatches)
  end
)

-- tries to create a new leaderboard object
---@param leaderboardName string the name of the leaderboard without file extension
---@return Leaderboard
function Leaderboard.createFromCsvData(leaderboardName)
  local leaderboard = Leaderboard(leaderboardName)

  local data = FileIO.readCsvFile(leaderboardName .. ".csv")
  if data then
    leaderboard:importData(data)
  end

  return leaderboard
end

---@param data { [1]: privateUserId, [2]: string, [3]: number, [4]: string, [5]: number?, [6]: integer, [7]: integer?, [8]: integer?}[]
--- user_id, user_name, rating, placement_done, placement_rating, ranked_games_played, ranked_games_won, last_login_time
function Leaderboard:importData(data)
  for row = 2, #data do
    data[row][1] = tostring(data[row][1])
    self.players[data[row][1]] = {}
    for col = 1, #data[1] do
      --Note csv_table[row][1] will be the player's user_id
      --csv_table[1][col] will be a property name such as "rating"
      if data[row][col] == "" then
        data[row][col] = nil
      end
      --player with this user_id gets this property equal to the csv_table cell's value
      if data[1][col] == "user_name" then
        self.players[data[row][1]][data[1][col]] = tostring(data[row][col])
      elseif data[1][col] == "rating" then
        self.players[data[row][1]][data[1][col]] = tonumber(data[row][col])
      elseif data[1][col] == "placement_done" then
        self.players[data[row][1]][data[1][col]] = data[row][col] and string.lower(data[row][col]) ~= "false"
      else
        self.players[data[row][1]][data[1][col]] = data[row][col]
      end
    end
  end
end

function Leaderboard:update(user_id, new_rating)
  logger.debug("in Leaderboard.update")
  if self.players[user_id] then
    self.players[user_id].rating = new_rating
  else
    self.players[user_id] = {rating = new_rating}
  end

  logger.debug("new_rating = " .. new_rating)
  logger.debug("about to write_leaderboard_file")
  FileIO.write_leaderboard_file(self)
  logger.debug("done with Leaderboard.update")
end

---@param server Server
---@param user_id_of_requester privateUserId?
---@return table
function Leaderboard:get_report(server, user_id_of_requester)
  --returns the leaderboard as an array sorted from highest rating to lowest,
  --with usernames from playerbase.players instead of user_ids
  --ie report[1] will give the highest rating player's user_name and how many points they have. Like this:
  --report[1] might return {user_name="Alice",rating=2250}
  --report[2] might return {user_name="Bob",rating=2100,is_you=true} if Bob requested the leaderboard
  local report = {}
  local leaderboard_player_count = 0
  --count how many entries there are in self.players since #self.players will not give us an accurate answer for sparse tables
  for k, v in pairs(self.players) do
    leaderboard_player_count = leaderboard_player_count + 1
  end
  for k, v in pairs(self.players) do
    for insert_index = 1, leaderboard_player_count do
      local player_is_leaderboard_requester = nil
      if server.playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.placement_done then --don't include players who haven't finished placement
          if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
            if k == user_id_of_requester then
              player_is_leaderboard_requester = true
            end
            if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
              table.insert(report, insert_index, {user_name = server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester})
              break
            elseif insert_index == leaderboard_player_count or #report == 0 then
              table.insert(report, {user_name = server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester}) -- at the end of the table.
              break
            end
          end
        end
      end
    end
  end
  for k, v in pairs(report) do
    v.rating = math.round(v.rating)
  end
  return report
end

function Leaderboard:update_timestamp(user_id)
  if self.players[user_id] then
    local timestamp = os.time()
    self.players[user_id].last_login_time = timestamp
    FileIO.write_leaderboard_file(self)
    logger.debug(user_id .. "'s login timestamp has been updated to " .. timestamp)
  else
    logger.debug(user_id .. " is not on the leaderboard, so no timestamp will be assigned at this time.")
  end
end

---@param userId privateUserId
---@return boolean processPlacementMatches if the player's placement matches should get processed
---@return string? reason why they should not get processed
function Leaderboard:qualifies_for_placement(userId)
  --local placement_match_win_ratio_requirement = .2
  self:loadPlacementMatches(userId)
  local placement_matches_played = #self.loadedPlacementMatches.incomplete[userId]
  if not self.consts.PLACEMENT_MATCHES_ENABLED then
    return false, ""
  elseif (self.players[userId] and self.players[userId].placement_done) then
    return false, "user is already placed"
  elseif placement_matches_played < self.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT then
    return false, placement_matches_played .. "/" .. self.consts.PLACEMENT_MATCH_COUNT_REQUIREMENT .. " placement matches played."
  -- else
  -- local win_ratio
  -- local win_count
  -- for i=1,placement_matches_played do
  -- win_count = win_count + self.loadedPlacementMatches.incomplete[user_id][i].outcome
  -- end
  -- win_ratio = win_count / placement_matches_played
  -- if win_ratio < placement_match_win_ratio_requirement then
  -- return false, "placement win ratio is currently "..math.round(win_ratio*100).."%.  "..math.round(placement_match_win_ratio_requirement*100).."% is required for placement."
  -- end
  end
  return true
end

---@param userId privateUserId
function Leaderboard:loadPlacementMatches(userId)
  logger.debug("Requested loading placement matches for user_id:  " .. (userId or "nil"))
  if not self.loadedPlacementMatches.incomplete[userId] then
    local read_success, matches = FileIO.read_user_placement_match_file(userId)
    if read_success then
      self.loadedPlacementMatches.incomplete[userId] = matches or {}
      logger.debug("loaded placement matches from file:")
    else
      self.loadedPlacementMatches.incomplete[userId] = {}
      logger.debug("no pre-existing placement matches file, starting fresh")
    end
    logger.debug(tostring(self.loadedPlacementMatches.incomplete[userId]))
    logger.debug(json.encode(self.loadedPlacementMatches.incomplete[userId]))
  else
    logger.debug("Didn't load placement matches from file. It is already loaded")
  end

  return self.loadedPlacementMatches.incomplete[userId]
end

---@param player ServerPlayer
---@return number rating 0 if no rating has been set yet
function Leaderboard:getRating(player)
  if self.players[player.userId] then
    local lp = self.players[player.userId]
    if lp.placement_done then
      return lp.rating or 0
    else
      -- the leaderboard is a backend processing component and should not have any opinions on display matters
      -- as long as it communicates someone is still in their placement matches, the client can choose to hide it
      return lp.placement_rating or 0
    end
  else
    return 0
  end
end

---@param player ServerPlayer
---@return string?
function Leaderboard:getPlacementProgress(player)
  local qualifies, progress = self:qualifies_for_placement(player.userId)
  if not (self.players[player.userId] and self.players[player.userId].placement_done) and not qualifies then
    return progress
  end
end

---@param player ServerPlayer
function Leaderboard:addToLeaderboard(player)
  if not self.players[player.userId] or not self.players[player.userId].rating then
    self.players[player.userId] = {user_name = player.name, rating = self.consts.DEFAULT_RATING}
    logger.debug("Gave " .. self.players[player.userId].user_name .. " a new rating of " .. self.consts.DEFAULT_RATING)
    if not self.consts.PLACEMENT_MATCHES_ENABLED then
      self.players[player.userId].placement_done = true
    end
    FileIO.write_leaderboard_file(self)
  end
end

---@param rating number
---@return string
function Leaderboard:get_league(rating)
  if not rating then
    return leagues[1].league --("Newcomer")
  end
  for i = 1, #leagues do
    if i == #leagues or leagues[i + 1].min_rating > rating then
      return leagues[i].league
    end
  end
  return "LeagueNotFound"
end

function Leaderboard:calculate_rating_adjustment(Rc, Ro, Oa, k) -- -- print("calculating expected outcome for") -- print(players[player_number].name.." Ranking: "..self.players[players[player_number].user_id].rating)
  --[[ --Algorithm we are implementing, per community member Bbforky:
      Formula for Calculating expected outcome:
      RATING_SPREAD_MODIFIER = 400
      Oe=1/(1+10^((Ro-Rc)/RATING_SPREAD_MODIFIER)))

      Oe= Expected Outcome
      Ro= Current rating of opponent
      Rc= Current rating

      Formula for Calculating new rating:

      Rn=Rc+k(Oa-Oe)

      Rn=New Rating
      Oa=Actual Outcome (0 for loss, 1 for win)
      k= Constant (Probably will use 10)
  ]] -- print("vs")
  -- print(players[player_number].opponent.name.." Ranking: "..self.players[players[player_number].opponent.user_id].rating)
  Oe = 1 / (1 + 10 ^ ((Ro - Rc) / self.consts.RATING_SPREAD_MODIFIER))
  -- print("expected outcome: "..Oe)
  Rn = Rc + k * (Oa - Oe)
  return Rn
end

---@param player ServerPlayer
---@return integer
function Leaderboard:getK(player)
  local k
  if self.players[player.userId].placement_done then
    k = self.consts.K
  else
    k = self.consts.PLACEMENT_MATCH_K
  end
  return k
end

---@param player ServerPlayer
---@param opponent ServerPlayer
---@param result (0 | 1)
function Leaderboard:addPlacementResult(player, opponent, result)
  local placementMatches = self:loadPlacementMatches(player.userId)
  placementMatches[#placementMatches+1] = {
    op_user_id = opponent.userId,
    op_name = opponent.name,
    op_rating = self.players[opponent.userId].rating,
    outcome = result
  }

  logger.debug("PRINTING PLACEMENT MATCHES FOR USER")
  logger.debug(json.encode(self.loadedPlacementMatches.incomplete[player.userId]))
  self:emitSignal("placementMatchAdded", player.userId)

  local leaderboardPlayer = self.players[player.userId]
  --adjust newcomer's placement_rating
  leaderboardPlayer.placement_rating = self:calculate_rating_adjustment(leaderboardPlayer.placement_rating or self.consts.DEFAULT_RATING, self.players[player.opponent.userId].rating, result, self:getK(player))
  logger.debug("New newcomer rating: " .. leaderboardPlayer.placement_rating)
end

function Leaderboard:persistPlacementMatches(userId)
  FileIO.write_user_placement_match_file(userId, self.loadedPlacementMatches.incomplete[userId])
end

---@param game ServerGame
---@return boolean # if the game is a placement game
---@return ServerPlayer?
function Leaderboard:isPlacementGame(game)
  for _, player in ipairs(game.players) do
    if not self.players[player.userId].placement_done then
      return true, player
    end
  end
  return false
end

---@alias RatingUpdate {old: number, new: number, difference: number, ranked_games_played: integer, ranked_games_won: integer, userId: privateUserId, placement_match_progress: string}

---@param game ServerGame
---@return RatingUpdate[] # The rating changes for each player in the game
function Leaderboard:processGameResult(game)
  if not game.winnerId then
    -- the current approach is to ignore ties
    return {}
  end

  if #game.players ~= self.playersPerGame then
    logger.error("This leaderboard is only made to process results from games between two players")
    return {}
  end

  if not self:rating_adjustment_approved(game.players) then
    return {}
  end

  for _, player in ipairs(game.players) do
    --if they aren't on the leaderboard yet, give them the default rating
    self:addToLeaderboard(player)
  end

  local ratings = {}

  local isPlacementGame, placementPlayer = self:isPlacementGame(game)
  for i, player in ipairs(game.players) do
    local rating = {}
    rating.old = self:getRating(player)
    ratings[i] = rating
  end

  if isPlacementGame then
    ---@cast placementPlayer -nil
    -- if it is a placement match we only need to calculate the placement player and possible finalize placement if the game finished their placements
    -- for the other player there is either no calculation or the calculation is done in the placement finalization

    local placementIndex
    local rankedIndex
    local rankedPlayer
    if game.players[1] == placementPlayer then
      placementIndex = 1
      rankedIndex = 2
    else
      placementIndex = 2
      rankedIndex = 1
    end
    rankedPlayer = game.players[rankedIndex]

    local Oa = (game.winnerId == placementPlayer.publicPlayerID) and 1 or 0
    self:addPlacementResult(placementPlayer, rankedPlayer, Oa)
    local processPlacementMatches, reason = self:qualifies_for_placement(placementPlayer.userId)
    if processPlacementMatches then
      self:process_placement_matches(placementPlayer.userId)
    else
      ratings[placementIndex].placement_match_progress = reason
    end
    for i, player in ipairs(game.players) do
      ratings[i].new = self:getRating(player)
      ratings[i].difference = ratings[i].new - ratings[i].old
    end
  else
    local Oa = (game.winnerId == game.players[1].publicPlayerID) and 1 or 0
    ratings[1].new = self:calculate_rating_adjustment(ratings[1].old, ratings[2].old, Oa, self:getK(game.players[1]))
    ratings[1].difference = ratings[1].new - ratings[1].old

    Oa = (Oa == 1 and 0 or 1)
    ratings[2].new = self:calculate_rating_adjustment(ratings[2].old, ratings[1].old, Oa, self:getK(game.players[2]))
    ratings[2].difference = ratings[2].new - ratings[2].old
  end

  for i, player in ipairs(game.players) do
    local leaderboardPlayer = self.players[player.userId]
    if not isPlacementGame or player == placementPlayer then
      -- placement games don't count as games for ranked players until they are done at which point these stats are updated from the placement match data
      leaderboardPlayer.ranked_games_played = (leaderboardPlayer.ranked_games_played or 0) + 1
      if player.publicPlayerID == game.winnerId then
        leaderboardPlayer.ranked_games_won = (leaderboardPlayer.ranked_games_won or 0) + 1
      end
    end
    if leaderboardPlayer.placement_done then
      leaderboardPlayer.rating = ratings[i].new
    end
    ratings[i].ranked_games_played = leaderboardPlayer.ranked_games_played or 0
    ratings[i].ranked_games_won = leaderboardPlayer.ranked_games_won or 0
    ratings[i].userId = player.userId
    ratings[i].league = self:get_league(ratings[i].new)
  end

  logger.debug("done with Leaderboard.processGameResult")
  self:emitSignal("gameResultProcessed", ratings, game.id)

  return ratings
end

---@param ratingUpdate RatingUpdate[]
---@param gameId integer
function Leaderboard:persistRatingChanges(ratingUpdate, gameId)
  logger.debug("about to write_leaderboard_file")
  FileIO.write_leaderboard_file(self)
  for i, rating in ipairs(ratingUpdate) do
    if not rating.placement_match_progress then
      database:insertPlayerELOChange(rating.userId, rating.new, gameId)
    end
  end
end

---@param userId privateUserId
function Leaderboard:process_placement_matches(userId)
  self:loadPlacementMatches(userId)
  local placement_matches = self.loadedPlacementMatches.incomplete[userId]
  if #placement_matches < 1 then
    logger.error("Failed to process placement matches because we couldn't find any")
    return
  end

  --assign the current placement_rating as the newcomer's official rating.
  self.players[userId].rating = self.players[userId].placement_rating
  self.players[userId].placement_done = true
  logger.debug("FINAL PLACEMENT RATING for " .. (self.players[userId].user_name or "nil") .. ": " .. (self.players[userId].rating or "nil"))

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.debug("adjusting opponent rating(s) for these placement matches")
  for i = 1, #placement_matches do
    if placement_matches[i].outcome == 0 then
      op_outcome = 1
    else
      op_outcome = 0
    end
    local op_rating_change = self:calculate_rating_adjustment(placement_matches[i].op_rating, self.players[userId].placement_rating, op_outcome, 10) - placement_matches[i].op_rating
    self.players[placement_matches[i].op_user_id].rating = self.players[placement_matches[i].op_user_id].rating + op_rating_change
    self.players[placement_matches[i].op_user_id].ranked_games_played = (self.players[placement_matches[i].op_user_id].ranked_games_played or 0) + 1
    self.players[placement_matches[i].op_user_id].ranked_games_won = (self.players[placement_matches[i].op_user_id].ranked_games_won or 0) + op_outcome
  end
  self.players[userId].placement_done = true

  self:emitSignal("placementMatchesProcessed", userId)
end

function Leaderboard:completePlacement(userId)
  FileIO.move_user_placement_file_to_complete(userId)
  FileIO.write_leaderboard_file(self)
  -- what is not being done is that rating changes are not persisted into the DB
  -- the game IDs are old but the rating is applied on the PRESENT rating
  -- so putting them into the DB does not make any sense
  -- in fact the current implementation of placement matches really makes it so that persisting a rating history barely makes sense
  --  because there will be illogical jumps induced by placement matches the moment the rating gets saved for the next time
end

---@param players ServerPlayer[]
---@return boolean # if the players can play ranked with their current settings
---@return string[] reasons why the players cannot play ranked with each other
function Leaderboard:rating_adjustment_approved(players)
  --returns whether both players in the room have game states such that rating adjustment should be approved
  local reasons = {}
  local caveats = {}
  local both_players_are_placed = nil

  if self.consts.PLACEMENT_MATCHES_ENABLED then
    if self.players[players[1].userId] and self.players[players[1].userId].placement_done and self.players[players[2].userId] and self.players[players[2].userId].placement_done then
      --both players are placed on the leaderboard.
      both_players_are_placed = true
    elseif not (self.players[players[1].userId] and self.players[players[1].userId].placement_done) and not (self.players[players[2].userId] and self.players[players[2].userId].placement_done) then
      reasons[#reasons + 1] = "Neither player has finished enough placement matches against already ranked players"
    end
  else
    both_players_are_placed = true
  end
  -- don't let players use the same account
  if players[1].userId == players[2].userId then
    reasons[#reasons + 1] = "Players cannot use the same account"
  end

  --don't let players too far apart in rating play ranked
  local ratings = {}
  for k, v in ipairs(players) do
    if self.players[v.userId] then
      if not self.players[v.userId].placement_done and self.players[v.userId].placement_rating then
        ratings[k] = self.players[v.userId].placement_rating
      elseif self.players[v.userId].rating and self.players[v.userId].rating ~= 0 then
        ratings[k] = self.players[v.userId].rating
      else
        ratings[k] = self.consts.DEFAULT_RATING
      end
    else
      ratings[k] = self.consts.DEFAULT_RATING
    end
  end
  if math.abs(ratings[1] - ratings[2]) > self.consts.RATING_SPREAD_MODIFIER * self.consts.ALLOWABLE_RATING_SPREAD_MULTIPLIER then
    reasons[#reasons + 1] = "Players' ratings are too far apart"
  end

  local player_level_out_of_bounds_for_ranked = false
  for i = 1, 2 do --we'll change 2 here when more players are allowed.
    if (players[i].level < self.consts.MIN_LEVEL_FOR_RANKED or players[i].level > self.consts.MAX_LEVEL_FOR_RANKED) then
      player_level_out_of_bounds_for_ranked = true
    end
  end
  if player_level_out_of_bounds_for_ranked then
    reasons[#reasons + 1] = "Only levels between " .. self.consts.MIN_LEVEL_FOR_RANKED .. " and " .. self.consts.MAX_LEVEL_FOR_RANKED .. " are allowed for ranked play."
  end
  -- local playerColorsOutOfBoundsForRanked = false
  -- for i, player in ipairs(players) do
  --   if player.levelData.colorCount < MIN_COLORS_FOR_RANKED or player.levelData.colorCount > MAX_COLORS_FOR_RANKED then
  --     playerColorsOutOfBoundsForRanked = true
  --   end
  -- end
  -- if playerColorsOutOfBoundsForRanked then
  --   reasons[#reasons + 1] = "Only color counts between " .. MIN_COLORS_FOR_RANKED .. " and " .. MAX_COLORS_FOR_RANKED .. " are allowed for ranked play."
  -- end
  if players[1].level ~= players[2].level then
    reasons[#reasons + 1] = "Levels don't match"
  -- elseif not deep_content_equal(players[1].levelData or LevelPresets.getModern(players[1].level), players[2].levelData or LevelPresets.getModern(players[2].level)) then
  --  reasons[#reasons + 1] = "Level data doesn't match"
  end

  for i, player in ipairs(players) do
    if player:usesModifiedLevelData() then
      reasons[#reasons + 1] = player.name .. " uses modified level data"
    end
  end

  if players[1].inputMethod == "touch" or players[2].inputMethod == "touch" then
    reasons[#reasons + 1] = "Touch input is not currently allowed in ranked matches."
  end

  if reasons[1] then
    return false, reasons
  else
    if self.consts.PLACEMENT_MATCHES_ENABLED and not both_players_are_placed and ((self.players[players[1].userId] and self.players[players[1].userId].placement_done) or (self.players[players[2].userId] and self.players[players[2].userId].placement_done)) then
      caveats[#caveats + 1] = "Note: Rating adjustments for these matches will be processed when the newcomer finishes placement."
    end
    return true, caveats
  end
end

return Leaderboard