local lfs = require("lfs")
local logger = require("common.lib.logger")
local csvfile = require("server.simplecsv")

local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

local FileIO = {}

function FileIO.makeDirectory(path)
  local status, error = pcall(
    function()
      lfs.mkdir(path)
    end
  )
  if not status then
    logger.error("Failed to make directory: " .. path .. " error: " .. error)
  end
end

function FileIO.makeDirectoryRecursive(path)
  -- an absolute path keeps its leading separator so it isn't made relative to the working directory
  local pStr = path:sub(1, 1) == sep and sep or ""
  for dir in path:gmatch("[^" .. sep .. "]+") do
    pStr = pStr .. dir .. sep
    FileIO.makeDirectory(pStr)
  end
end

function FileIO.fileExists(name)
  local f=io.open(name,"r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function FileIO.writeAsJson(data, filePath)
  local status, error = pcall(
    function()
      local f = assert(io.open(filePath, "w"))
      io.output(f)
      io.write(json.encode(data))
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to write file " .. filePath .. " with error: " .. error)
  end
end

function FileIO.readJson(filename)
  local success, json =
  pcall(
    function()
      local f = io.open(filename, "r")
      if f then
        io.input(f)
        local data = io.read("*all")
        io.close(f)
        return json.decode(data)
      end
    end
  )

  return json
end


function FileIO.logGameResult(player1ID, player2ID, player1Won, rankedValue)
  local status, error = pcall(
    function()
      local f = assert(io.open("GameResults.csv", "a"))
      io.output(f)
      io.write(player1ID .. "," .. player2ID .. "," .. player1Won .. "," .. rankedValue .. "," .. os.time() .. "\n")
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to log game result: " .. error)
  end
end

-- The path for a new report file named nameStem; reports arriving in the same second get "-2", "-3"... so none overwrites another
---@param directory string
---@param nameStem string the file name without its extension
---@return string
function FileIO.unusedErrorReportPath(directory, nameStem)
  local path = directory .. sep .. nameStem .. ".json"
  local copyNumber = 1
  while FileIO.fileExists(path) do
    copyNumber = copyNumber + 1
    path = directory .. sep .. nameStem .. "-" .. copyNumber .. ".json"
  end
  return path
end

local REPORT_FILE_NAME_FIELD_LENGTH_LIMIT = 16

-- A field the client sent, made safe for a report's file name: only letters, digits and "_", the characters player names
-- and engine versions use. Anything else, such as a separator, ".." or a NUL that would end the path early, becomes "_".
---@param value any
---@param default string used when the field is missing or isn't text
---@return string
function FileIO.errorReportFileNameField(value, default)
  if type(value) ~= "string" and type(value) ~= "number" then
    return default
  end
  local field = tostring(value):sub(1, REPORT_FILE_NAME_FIELD_LENGTH_LIMIT):gsub("[^%w_]", "_")
  if field == "" then
    return default
  end
  return field
end

---@param error_report_json table the report the client sent
---@param directory string the folder the report file goes in
---@param timestamp integer when the report arrived, which names the file
---@return boolean # false if the report was too large or couldn't be written
function FileIO.write_error_report(error_report_json, directory, timestamp)
  local json_string = json.encode(error_report_json)
  if json_string:len() >= 5000 --[[5kB]] then
    return false
  end
  local now = os.date("*t", to_UTC(timestamp))
  local engineVersion = FileIO.errorReportFileNameField(error_report_json.engine_version, "000")
  local playerName = FileIO.errorReportFileNameField(error_report_json.name, "Unknown")
  local nameStem = "v" .. engineVersion .. "-" .. string.format("%04d-%02d-%02d-%02d-%02d-%02d", now.year, now.month, now.day, now.hour, now.min, now.sec) .. "_" .. playerName .. "-ErrorReport"
  return pcall(
    function()
      FileIO.makeDirectoryRecursive(directory)
      local f = assert(io.open(FileIO.unusedErrorReportPath(directory, nameStem), "w"))
      io.output(f)
      io.write(json_string)
      io.close(f)
    end
  )
end

---@param leaderboard Leaderboard
function FileIO.write_leaderboard_file(leaderboard, path)
  local leaderboard_table, public_leaderboard_table = leaderboard:toSheetData()

  local status, error = pcall(
    function()
      csvfile.write("." .. sep .. path, leaderboard_table)
      FileIO.makeDirectoryRecursive("." .. sep .. "ftp")
      csvfile.write("." .. sep .. "ftp" .. sep .. "PA_public_" .. path, public_leaderboard_table)
    end
  )
  if not status then
    logger.error("Failed to write leaderboard file with error: " .. error)
  end
end

function FileIO.readCsvFile(filePath)
  if FileIO.fileExists(filePath) == false then
    return nil
  end
  local csv_table = {}
  local status, error = pcall(
    function()
      csv_table = csvfile.read("." .. sep .. filePath)
    end
  )

  if not status then
    logger.error("Failed reading file " .. filePath .. " with the csv reader:\n" .. tostring(error))
    return nil, error
  else
    return csv_table
  end
end

function FileIO.read_user_placement_match_file(user_id)
  return pcall(
    function()
      local sep = package.config:sub(1, 1)
      local csv_table = csvfile.read("./placement_matches/incomplete/" .. user_id .. ".csv")
      if not csv_table or #csv_table < 2 then
        logger.debug("csv_table from read_user_placement_match_file was nil or <2 length")
        return nil
      else
        logger.debug("csv_table from read_user_placement_match_file :")
        logger.debug(json.encode(csv_table))
      end
      local ret = {}
      for row = 2, #csv_table do
        csv_table[row][1] = tostring(csv_table[row][1]) --change the op_user_id to a string
        ret[#ret + 1] = {}
        for col = 1, #csv_table[1] do
          --Note csv_table[row][1] will be the player's user_id
          --csv_table[1][col] will be a property name such as "rating"
          if csv_table[row][col] == "" then
            csv_table[row][col] = nil
          end
          --player with this user_id gets this property equal to the csv_table cell's value
          if csv_table[1][col] == "op_name" then
            ret[#ret][csv_table[1][col]] = tostring(csv_table[row][col])
          elseif csv_table[1][col] == "op_rating" then
            ret[#ret][csv_table[1][col]] = tonumber(csv_table[row][col])
          elseif csv_table[1][col] == "op_user_id" then
            ret[#ret][csv_table[1][col]] = tostring(csv_table[row][col])
          elseif csv_table[1][col] == "outcome" then
            ret[#ret][csv_table[1][col]] = tonumber(csv_table[row][col])
          else
            ret[#ret][csv_table[1][col]] = csv_table[row][col]
          end
        end
      end
      logger.debug("read_user_placement_match_file ret: ")
      logger.debug(tostring(ret))
      logger.debug(json.encode(ret))
      return ret
    end
  )
end

function FileIO.move_user_placement_file_to_complete(user_id)
  local status, error = pcall(
    function()
      local sep = package.config:sub(1, 1)
      FileIO.makeDirectoryRecursive("./placement_matches/complete")
      local moved, err = os.rename("./placement_matches/incomplete/" .. user_id .. ".csv", "./placement_matches/complete/" .. user_id .. ".csv")
    end
  )
  if not status then
    logger.error("Failed to move user placement file to complete: " .. error)
  end
end

function FileIO.write_user_placement_match_file(user_id, placement_matches)
  local sep = package.config:sub(1, 1)
  local pm_table = {}
  pm_table[#pm_table + 1] = {"op_user_id", "op_name", "op_rating", "outcome"}
  for k, v in ipairs(placement_matches) do
    pm_table[#pm_table + 1] = {v.op_user_id, v.op_name, v.op_rating, v.outcome}
  end
  FileIO.makeDirectoryRecursive("placement_matches" .. sep .. "incomplete")
  local fullFileName = "placement_matches" .. sep .. "incomplete" .. sep .. user_id .. ".csv"
  local status, error = pcall(
    function()
      csvfile.write(fullFileName, pm_table)
    end
  )
  if not status then
    logger.error("Failed to write user placement match file: " .. fullFileName .. " with error: " .. error)
  end
end

function FileIO.write_replay_file(replay, path, filename)
  local sep = package.config:sub(1, 1)
  local status, error = pcall(
    function()
      FileIO.makeDirectoryRecursive(path)
      local f = assert(io.open(path .. sep .. filename, "w"))
      io.output(f)
      io.write(json.encode(replay))
      io.close(f)
    end
  )
  if not status then
    logger.error("Failed to write replay file: " .. path .. sep .. filename .. " with error: " .. error)
  end
end

---@return number seed
function FileIO.read_csprng_seed_file()
  local csprng_seed
  pcall(
    function()
      local f = io.open("csprng_seed.txt", "r")
      if f then
        io.input(f)
        csprng_seed = io.read("*all")
        io.close(f)
      else
        csprng_seed = math.random(1,99999)
        print("csprng_seed.txt could not be read.  Writing a new csprng_seed.txt")
        local new_file = io.open("csprng_seed.txt", "w")
        if new_file then
          io.output(new_file)
          io.write(csprng_seed)
          io.close(new_file)
        end
      end
      if tonumber(csprng_seed) then
        local tempvar = tonumber(csprng_seed)
        csprng_seed = tempvar
      else
        error("ERROR: csprng_seed.txt content is not numeric.")
      end
    end
  )
  return csprng_seed
end

---@param game ServerGame
function FileIO.saveReplay(game)
  for i, player in ipairs(game.players) do
    if player.save_replays_publicly == "not at all" then
      logger.debug("replay not saved because a player didn't want it saved")
      return
    end
  end

  local path = "ftp" .. sep .. game.replay:generatePath(sep)
  local filename = game.replay:generateFileName() .. ".json"

  logger.debug("saving replay as " .. path .. sep .. filename)
  FileIO.write_replay_file(game.replay, path, filename)
end

return FileIO