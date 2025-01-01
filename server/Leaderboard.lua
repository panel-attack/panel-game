local class = require("common.lib.class")
local logger = require("common.lib.logger")
local database = require("server.PADatabase")

local DEFAULT_RATING = 1500
local RATING_SPREAD_MODIFIER = 400
local PLACEMENT_MATCH_COUNT_REQUIREMENT = 30
local ALLOWABLE_RATING_SPREAD_MULITPLIER = .9 --set this to a huge number like 100 if you want everyone to be able to play with anyone, regardless of rating gap
local PLACEMENT_MATCH_K = 50
local PLACEMENT_MATCHES_ENABLED = true
local MIN_LEVEL_FOR_RANKED = 1
local MAX_LEVEL_FOR_RANKED = 10
local MIN_COLORS_FOR_RANKED = 5
local MAX_COLORS_FOR_RANKED = 6

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

logger.debug("RATING_SPREAD_MODIFIER: " .. (RATING_SPREAD_MODIFIER or "nil"))

---@alias LeaderboardPlayer {user_id: privateUserId, user_name: string, rating: number, placement_done:boolean, placement_rating: number, ranked_games_played: integer, ranked_games_won: integer, last_login_time: integer}

-- Object that represents players rankings and placement matches, along with login times
---@class Leaderboard
---@field name string
---@field players table<string, LeaderboardPlayer>
---@field loadedPlacementMatches {incomplete: table, complete: table}
---@overload fun(name: string): Leaderboard
local Leaderboard =
  class(
  function(s, name)
    s.name = name
    s.players = {}
    s.loadedPlacementMatches = {
      incomplete = {},
      complete = {}
    }
  end
)

function Leaderboard.update(self, user_id, new_rating, match_details)
  logger.debug("in Leaderboard.update")
  if self.players[user_id] then
    self.players[user_id].rating = new_rating
  else
    self.players[user_id] = {rating = new_rating}
  end
  if match_details and match_details ~= "" then
    for k, v in pairs(match_details) do
      self.players[user_id].ranked_games_won = (self.players[user_id].games_won or 0) + v.outcome
      self.players[user_id].ranked_games_played = (self.players[user_id].ranked_games_played or 0) + 1
    end
  end
  logger.debug("new_rating = " .. new_rating)
  logger.debug("about to write_leaderboard_file")
  write_leaderboard_file()
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

function Leaderboard.update_timestamp(self, user_id)
  if self.players[user_id] then
    local timestamp = os.time()
    self.players[user_id].last_login_time = timestamp
    write_leaderboard_file()
    logger.debug(user_id .. "'s login timestamp has been updated to " .. timestamp)
  else
    logger.debug(user_id .. " is not on the leaderboard, so no timestamp will be assigned at this time.")
  end
end

---@param userId privateUserId
function Leaderboard:qualifies_for_placement(userId)
  --local placement_match_win_ratio_requirement = .2
  self:loadPlacementMatches(userId)
  local placement_matches_played = #self.loadedPlacementMatches.incomplete[userId]
  if not PLACEMENT_MATCHES_ENABLED then
    return false, ""
  elseif (leaderboard.players[userId] and leaderboard.players[userId].placement_done) then
    return false, "user is already placed"
  elseif placement_matches_played < PLACEMENT_MATCH_COUNT_REQUIREMENT then
    return false, placement_matches_played .. "/" .. PLACEMENT_MATCH_COUNT_REQUIREMENT .. " placement matches played."
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
    local read_success, matches = read_user_placement_match_file(userId)
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
end

---@param player ServerPlayer
---@return number? rating
function Leaderboard:getRating(player)
  if self.players[player.userId] and self.players[player.userId].rating then
    return math.round(self.players[player.userId].rating or 0)
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
---@param gameID integer
function Leaderboard:addToLeaderboard(player, gameID)
  if not self.players[player.userId] or not self.players[player.userId].rating then
    self.players[player.userId] = {user_name = player.name, rating = DEFAULT_RATING}
    logger.debug("Gave " .. self.players[player.userId].user_name .. " a new rating of " .. DEFAULT_RATING)
    if not PLACEMENT_MATCHES_ENABLED then
      self.players[player.userId].placement_done = true
      database:insertPlayerELOChange(player.userId, DEFAULT_RATING, gameID)
    end
    write_leaderboard_file()
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

function Leaderboard:calculate_rating_adjustment(Rc, Ro, Oa, k) -- -- print("calculating expected outcome for") -- print(players[player_number].name.." Ranking: "..leaderboard.players[players[player_number].user_id].rating)
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
  -- print(players[player_number].opponent.name.." Ranking: "..leaderboard.players[players[player_number].opponent.user_id].rating)
  Oe = 1 / (1 + 10 ^ ((Ro - Rc) / RATING_SPREAD_MODIFIER))
  -- print("expected outcome: "..Oe)
  Rn = Rc + k * (Oa - Oe)
  return Rn
end

---@param room Room
---@param winning_player_number integer
---@param gameID integer
function Leaderboard:adjust_ratings(room, winning_player_number, gameID)
  logger.debug("Adjusting the rating of " .. room.players[1].name .. " and " .. room.players[2].name .. ". Player " .. winning_player_number .. " wins!")
  local players = room.players
  local continue = true
  local placement_match_progress
  room.ratings = {}
  for _, player in ipairs(players) do
    --if they aren't on the leaderboard yet, give them the default rating
    leaderboard:addToLeaderboard(player, gameID)
  end
  local placement_done = {}
  for player_number = 1, 2 do
    placement_done[players[player_number].userId] = leaderboard.players[players[player_number].userId].placement_done
  end
  for player_number = 1, 2 do
    local k, Oa  --max point change per match, actual outcome
    room.ratings[player_number] = {}
    if placement_done[players[player_number].userId] == true then
      k = 10
    else
      k = 50
    end
    if players[player_number].player_number == winning_player_number then
      Oa = 1
    else
      Oa = 0
    end
    if placement_done[players[player_number].userId] then
      if placement_done[players[player_number].opponent.userId] then
        logger.debug("Player " .. player_number .. " played a non-placement ranked match.  Updating his rating now.")
        room.ratings[player_number].new = self:calculate_rating_adjustment(leaderboard.players[players[player_number].userId].rating, leaderboard.players[players[player_number].opponent.userId].rating, Oa, k)
        database:insertPlayerELOChange(players[player_number].userId, room.ratings[player_number].new, gameID)
      else
        logger.debug("Player " .. player_number .. " played ranked against an unranked opponent.  We'll process this match when his opponent has finished placement")
        room.ratings[player_number].placement_matches_played = leaderboard.players[players[player_number].userId].ranked_games_played
        room.ratings[player_number].new = math.round(leaderboard.players[players[player_number].userId].rating)
        room.ratings[player_number].old = math.round(leaderboard.players[players[player_number].userId].rating)
        room.ratings[player_number].difference = 0
      end
    else -- this player has not finished placement
      if placement_done[players[player_number].opponent.userId] then
        logger.debug("Player " .. player_number .. " (unranked) just played a placement match against a ranked player.")
        logger.debug("Adding this match to the list of matches to be processed when player finishes placement")
        leaderboard:loadPlacementMatches(players[player_number].userId)
        local pm_count = #leaderboard.loadedPlacementMatches.incomplete[players[player_number].userId]

        leaderboard.loadedPlacementMatches.incomplete[players[player_number].userId][pm_count + 1] = {
          op_user_id = players[player_number].opponent.userId,
          op_name = players[player_number].opponent.name,
          op_rating = leaderboard.players[players[player_number].opponent.userId].rating,
          outcome = Oa
        }
        logger.debug("PRINTING PLACEMENT MATCHES FOR USER")
        logger.debug(json.encode(leaderboard.loadedPlacementMatches.incomplete[players[player_number].userId]))
        write_user_placement_match_file(players[player_number].userId, leaderboard.loadedPlacementMatches.incomplete[players[player_number].userId])

        --adjust newcomer's placement_rating
        if not leaderboard.players[players[player_number].userId] then
          leaderboard.players[players[player_number].userId] = {}
        end
        leaderboard.players[players[player_number].userId].placement_rating = self:calculate_rating_adjustment(leaderboard.players[players[player_number].userId].placement_rating or DEFAULT_RATING, leaderboard.players[players[player_number].opponent.userId].rating, Oa, PLACEMENT_MATCH_K)
        logger.debug("New newcomer rating: " .. leaderboard.players[players[player_number].userId].placement_rating)
        leaderboard.players[players[player_number].userId].ranked_games_played = (leaderboard.players[players[player_number].userId].ranked_games_played or 0) + 1
        if Oa == 1 then
          leaderboard.players[players[player_number].userId].ranked_games_won = (leaderboard.players[players[player_number].userId].ranked_games_won or 0) + 1
        end

        local process_them, reason = leaderboard:qualifies_for_placement(players[player_number].userId)
        if process_them then
          local op_player_number = players[player_number].opponent.player_number
          logger.debug("op_player_number: " .. op_player_number)
          room.ratings[player_number].old = 0
          if not room.ratings[op_player_number] then
            room.ratings[op_player_number] = {}
          end
          room.ratings[op_player_number].old = math.round(leaderboard.players[players[op_player_number].userId].rating)
          self:process_placement_matches(players[player_number].userId)

          room.ratings[player_number].new = math.round(leaderboard.players[players[player_number].userId].rating)

          room.ratings[player_number].difference = math.round(room.ratings[player_number].new - room.ratings[player_number].old)
          room.ratings[player_number].league = self:get_league(room.ratings[player_number].new)

          room.ratings[op_player_number].new = math.round(leaderboard.players[players[op_player_number].userId].rating)

          room.ratings[op_player_number].difference = math.round(room.ratings[op_player_number].new - room.ratings[op_player_number].old)
          room.ratings[op_player_number].league = self:get_league(room.ratings[player_number].new)
          return
        else
          placement_match_progress = reason
        end
      else
        logger.error("Neither player is done with placement.  We should not have gotten to this line of code")
      end
      room.ratings[player_number].new = 0
      room.ratings[player_number].old = 0
      room.ratings[player_number].difference = 0
    end
    logger.debug("room.ratings[" .. player_number .. "].new = " .. (room.ratings[player_number].new or ""))
  end
  --check that both player's new room.ratings are numeric (and not nil)
  for player_number = 1, 2 do
    if tonumber(room.ratings[player_number].new) then
      continue = true
    else
      logger.warn(players[player_number].name .. "'s new rating wasn't calculated properly.  Not adjusting the rating for this match")
      continue = false
    end
  end
  if continue then
    --now that both new room.ratings have been calculated properly, actually update the leaderboard
    for player_number = 1, 2 do
      logger.debug(players[player_number].name)
      logger.debug("Old rating:" .. leaderboard.players[players[player_number].userId].rating)
      room.ratings[player_number].old = leaderboard.players[players[player_number].userId].rating
      leaderboard.players[players[player_number].userId].ranked_games_played = (leaderboard.players[players[player_number].userId].ranked_games_played or 0) + 1
      leaderboard:update(players[player_number].userId, room.ratings[player_number].new)
      logger.debug("New rating:" .. leaderboard.players[players[player_number].userId].rating)
    end
    for player_number = 1, 2 do
      --round and calculate rating gain or loss (difference) to send to the clients
      if placement_done[players[player_number].userId] then
        room.ratings[player_number].old = math.round(room.ratings[player_number].old or leaderboard.players[players[player_number].userId].rating)
        room.ratings[player_number].new = math.round(room.ratings[player_number].new or leaderboard.players[players[player_number].userId].rating)
        room.ratings[player_number].difference = room.ratings[player_number].new - room.ratings[player_number].old
      else
        room.ratings[player_number].old = 0
        room.ratings[player_number].new = 0
        room.ratings[player_number].difference = 0
        room.ratings[player_number].placement_match_progress = placement_match_progress
      end
      room.ratings[player_number].league = self:get_league(room.ratings[player_number].new)
    end
  -- local message = ServerProtocol.updateRating(room.ratings[1], room.ratings[2])
  -- room:broadcastJson(message)
  end
end

---@param user_id privateUserId
function Leaderboard:process_placement_matches(user_id)
  self:loadPlacementMatches(user_id)
  local placement_matches = self.loadedPlacementMatches.incomplete[user_id]
  if #placement_matches < 1 then
    logger.error("Failed to process placement matches because we couldn't find any")
    return
  end

  --assign the current placement_rating as the newcomer's official rating.
  self.players[user_id].rating = self.players[user_id].placement_rating
  self.players[user_id].placement_done = true
  logger.debug("FINAL PLACEMENT RATING for " .. (self.players[user_id].user_name or "nil") .. ": " .. (self.players[user_id].rating or "nil"))

  --Calculate changes to opponents ratings for placement matches won/lost
  logger.debug("adjusting opponent rating(s) for these placement matches")
  for i = 1, #placement_matches do
    if placement_matches[i].outcome == 0 then
      op_outcome = 1
    else
      op_outcome = 0
    end
    local op_rating_change = self:calculate_rating_adjustment(placement_matches[i].op_rating, self.players[user_id].placement_rating, op_outcome, 10) - placement_matches[i].op_rating
    self.players[placement_matches[i].op_user_id].rating = self.players[placement_matches[i].op_user_id].rating + op_rating_change
    self.players[placement_matches[i].op_user_id].ranked_games_played = (self.players[placement_matches[i].op_user_id].ranked_games_played or 0) + 1
    self.players[placement_matches[i].op_user_id].ranked_games_won = (self.players[placement_matches[i].op_user_id].ranked_games_won or 0) + op_outcome
  end
  self.players[user_id].placement_done = true
  write_leaderboard_file()
  move_user_placement_file_to_complete(user_id)
end

---@param players ServerPlayer[]
---@return boolean # if the players can play ranked with their current settings
---@return string[] reasons why the players cannot play ranked with each other
function Leaderboard:rating_adjustment_approved(players)
  --returns whether both players in the room have game states such that rating adjustment should be approved
  local reasons = {}
  local caveats = {}
  local both_players_are_placed = nil

  if PLACEMENT_MATCHES_ENABLED then
    if leaderboard.players[players[1].userId] and leaderboard.players[players[1].userId].placement_done and leaderboard.players[players[2].userId] and leaderboard.players[players[2].userId].placement_done then
      --both players are placed on the leaderboard.
      both_players_are_placed = true
    elseif not (leaderboard.players[players[1].userId] and leaderboard.players[players[1].userId].placement_done) and not (leaderboard.players[players[2].userId] and leaderboard.players[players[2].userId].placement_done) then
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
    if leaderboard.players[v.userId] then
      if not leaderboard.players[v.userId].placement_done and leaderboard.players[v.userId].placement_rating then
        ratings[k] = leaderboard.players[v.userId].placement_rating
      elseif leaderboard.players[v.userId].rating and leaderboard.players[v.userId].rating ~= 0 then
        ratings[k] = leaderboard.players[v.userId].rating
      else
        ratings[k] = DEFAULT_RATING
      end
    else
      ratings[k] = DEFAULT_RATING
    end
  end
  if math.abs(ratings[1] - ratings[2]) > RATING_SPREAD_MODIFIER * ALLOWABLE_RATING_SPREAD_MULITPLIER then
    reasons[#reasons + 1] = "Players' ratings are too far apart"
  end

  local player_level_out_of_bounds_for_ranked = false
  for i = 1, 2 do --we'll change 2 here when more players are allowed.
    if (players[i].level < MIN_LEVEL_FOR_RANKED or players[i].level > MAX_LEVEL_FOR_RANKED) then
      player_level_out_of_bounds_for_ranked = true
    end
  end
  if player_level_out_of_bounds_for_ranked then
    reasons[#reasons + 1] = "Only levels between " .. MIN_LEVEL_FOR_RANKED .. " and " .. MAX_LEVEL_FOR_RANKED .. " are allowed for ranked play."
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
    if PLACEMENT_MATCHES_ENABLED and not both_players_are_placed and ((leaderboard.players[players[1].userId] and leaderboard.players[players[1].userId].placement_done) or (leaderboard.players[players[2].userId] and leaderboard.players[players[2].userId].placement_done)) then
      caveats[#caveats + 1] = "Note: Rating adjustments for these matches will be processed when the newcomer finishes placement."
    end
    return true, caveats
  end
end

return Leaderboard