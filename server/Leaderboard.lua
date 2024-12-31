local class = require("common.lib.class")
local logger = require("common.lib.logger")
local database = require("server.PADatabase")

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

---@alias LeaderboardPlayer {user_id: privateUserId, user_name: string, rating: number, placement_done:boolean, placement_rating: number, ranked_games_played: integer, ranked_games_won: integer, last_login_time: integer}

-- Object that represents players rankings and placement matches, along with login times
---@class Leaderboard
---@field name string
---@field server Server
---@field players table<string, LeaderboardPlayer>
---@field loadedPlacementMatches {incomplete: table, complete: table}
---@overload fun(name: string, server: Server): Leaderboard
Leaderboard =
  class(
  function(s, name, server)
    s.name = name
    s.server = server
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

function Leaderboard.get_report(self, user_id_of_requester)
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
      if self.server.playerbase.players[k] then --only include in the report players who are still listed in the playerbase
        if v.placement_done then --don't include players who haven't finished placement
          if v.rating then -- don't include entries who's rating is nil (which shouldn't happen anyway)
            if k == user_id_of_requester then
              player_is_leaderboard_requester = true
            end
            if report[insert_index] and report[insert_index].rating and v.rating >= report[insert_index].rating then
              table.insert(report, insert_index, {user_name = self.server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester})
              break
            elseif insert_index == leaderboard_player_count or #report == 0 then
              table.insert(report, {user_name = self.server.playerbase.players[k], rating = v.rating, is_you = player_is_leaderboard_requester}) -- at the end of the table.
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