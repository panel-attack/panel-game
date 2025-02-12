local inputManager = require("client.src.inputManager")
local FileUtils = require("client.src.FileUtils")
local logger = require("common.lib.logger")
local PuzzleSet = require("client.src.PuzzleSet")

-- the save.lua file contains the read/write functions

local save = {}

-- writes to the "keys.txt" file
function save.write_key_file()
  FileUtils.writeJson("", "keysV3.json", inputManager:getSaveKeyMap())
end

-- reads the "keys.txt" file
function save.read_key_file()
  local filename
  local migrateInputs = false

  if love.filesystem.getInfo("keysV3.json", "file") then
    filename = "keysV3.json"
  else
    filename = "keysV2.txt"
    migrateInputs = true
  end

  if not love.filesystem.getInfo(filename, "file") then
    return inputManager.inputConfigurations
  else
    local inputConfigs = FileUtils.readJsonFile(filename)

    if migrateInputs then
      -- migrate old input configs
      inputConfigs = inputManager:migrateInputConfigs(inputConfigs)
    end

    return inputConfigs
  end
end

-- reads the .txt file of the given path and filename
function save.read_txt_file(path_and_filename)
  local s
  s = love.filesystem.read(path_and_filename)
  if not s then
    s = "Failed to read file " .. path_and_filename
  else
    s = s:gsub("\r\n?", "\n")
  end
  return s or "Failed to read file"
end

-- writes to the "user_id.txt" file of the directory of the connected ip
---@param userID string
---@param serverIP string
function save.write_user_id_file(userID, serverIP)
  FileUtils.write("servers/" .. serverIP, "user_id.txt", tostring(userID))
end

-- reads the "user_id.txt" file of the directory of the connected ip
function save.read_user_id_file(serverIP)
  local userID
  pcall(
    function()
      userID = love.filesystem.read("servers/" .. serverIP .. "/user_id.txt")
      userID = userID:match("^%s*(.-)%s*$")
    end
  )
  return userID
end

-- writes the stock puzzles
function save.write_puzzles()
  love.filesystem.createDirectory("puzzles")
  pcall(
    function()
      FileUtils.recursiveCopy("client/assets/default_data/puzzles", "puzzles")
    end
  )
end

-- reads the selected puzzle file
function save.read_puzzles(path)
  pcall(
    function()
      local puzzleFiles = FileUtils.getFilteredDirectoryItems(path) or {}
      local count = 0
      logger.debug("loading custom puzzles...")
      for _, filename in pairs(puzzleFiles) do
        logger.trace(filename)
        if love.filesystem.getInfo(path .. "/" .. filename) and filename ~= "README.txt" then
          local puzzleSets = PuzzleSet.loadFromFile(path .. "/" .. filename)
          for _, puzzleSet in ipairs(puzzleSets) do
            GAME.puzzleSets[puzzleSet.setName] = puzzleSet
            count = count + 1
          end
        end
      end
      logger.debug("loaded " .. count .. " puzzle sets")
    end
  )
end

-- I think this is unnecessary as we use the path with love.filesystem.read which assumes / as the separator
-- But testing attack file generation seemed a bit out of scope for the intended changes, so leaving it for another time
local sep = package.config:sub(1, 1) --determines os directory separator (i.e. "/" or "\")

function save.readAttackFile(path)
  if love.filesystem.getInfo(path, "file") then
    local jsonData = love.filesystem.read(path)
    local trainingConf, position, errorMsg = json.decode(jsonData)
    if trainingConf then
      if not trainingConf.name or type(trainingConf.name) ~= "string" then
        local filenameOnly = path:match('%' .. sep .. '?(.*)$')
        if filenameOnly ~= nil then
          trainingConf.name = FileUtils.getFileNameWithoutExtension(filenameOnly)
        end
      end
      return trainingConf
    else
      error("Error deserializing " .. path .. ": " .. errorMsg .. " at position " .. position)
    end
  end
end

function save.readAttackFiles(path)
  local results = {}
  local lfs = love.filesystem
  local raw_dir_list = FileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) then
      if lfs.getInfo(current_path).type == "directory" then
        save.readAttackFiles(current_path)
      else
        local training_conf = save.readAttackFile(current_path)
        if training_conf ~= nil then
          results[#results+1] = training_conf
        end
      end
    end
  end

  return results
end

return save