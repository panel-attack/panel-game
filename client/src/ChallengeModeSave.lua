local class = require("common.lib.class")
local logger = require("common.lib.logger")
local ChallengeRun = require("client.src.ChallengeRun")

local CURRENT_VERSION = 1

-- The unfinished Challenge Mode run of each difficulty, the runs that beat it and the difficulty played last,
-- saved as compressed JSON
---@class ChallengeModeSave
---@field name string the save file's name without extension
---@field runs table<string, ChallengeRun> the unfinished run of each difficulty, keyed by the difficulty as a string
---@field records table<string, {bestContinues: integer, bestTime: integer, completedRuns: table[]}> keyed by the difficulty as a string
---@field lastDifficulty integer? the difficulty of the run saved last
---@overload fun(name: string): ChallengeModeSave
local ChallengeModeSave = class(
  function(self, name)
    self.name = name
    self.runs = {}
    self.records = {}
  end
)

-- Returns the path of the file the save named name is written to
---@param name string
---@return string
function ChallengeModeSave.path(name)
  return name .. ".sav"
end

-- Loads the save named name, or an empty save if there is none
---@param name string
---@return ChallengeModeSave
function ChallengeModeSave.load(name)
  local save = ChallengeModeSave(name)
  local contents = love.filesystem.read(ChallengeModeSave.path(name))
  if contents then
    local data = json.decode(love.data.decompress("string", "zlib", contents))
    save.records = data.records or {}
    save.lastDifficulty = data.lastDifficulty
    for difficulty, runData in pairs(data.runs or {}) do
      save.runs[difficulty] = ChallengeRun.fromSaveData(runData)
    end
  end
  return save
end

---@param difficulty integer
---@return ChallengeRun?
function ChallengeModeSave:getRun(difficulty)
  return self.runs[tostring(difficulty)]
end

-- Returns the fewest continues any completed run of the difficulty used, nil if it was never beaten
---@param difficulty integer
---@return integer?
function ChallengeModeSave:getBestContinues(difficulty)
  local record = self.records[tostring(difficulty)]
  return record and record.bestContinues
end

-- Returns the fewest frames any completed run of the difficulty took, nil if it was never beaten
---@param difficulty integer
---@return integer?
function ChallengeModeSave:getBestTime(difficulty)
  local record = self.records[tostring(difficulty)]
  return record and record.bestTime
end

---@return integer?
function ChallengeModeSave:getLastDifficulty()
  return self.lastDifficulty
end

-- Returns the save data of every completed run of the difficulty, oldest first
---@param difficulty integer
---@return table[]
function ChallengeModeSave:getCompletedRuns(difficulty)
  local record = self.records[tostring(difficulty)]
  return record and record.completedRuns or {}
end

-- Writes the run to disk; a completed run is moved into its difficulty's records
---@param run ChallengeRun
function ChallengeModeSave:saveRun(run)
  local key = tostring(run.difficulty)
  self.lastDifficulty = run.difficulty
  if run.complete then
    self.runs[key] = nil
    self:addRecord(key, run)
  else
    self.runs[key] = run
  end
  self:write()
end

---@param key string
---@param run ChallengeRun
function ChallengeModeSave:addRecord(key, run)
  local record = self.records[key] or {completedRuns = {}}
  record.completedRuns[#record.completedRuns + 1] = run:toSaveData()
  if record.bestContinues == nil or run.continues < record.bestContinues then
    record.bestContinues = run.continues
  end
  if record.bestTime == nil or run.expendedTime < record.bestTime then
    record.bestTime = run.expendedTime
  end
  self.records[key] = record
end

-- Removes the difficulty's unfinished run from disk
---@param difficulty integer
function ChallengeModeSave:discardRun(difficulty)
  self.runs[tostring(difficulty)] = nil
  self:write()
end

function ChallengeModeSave:write()
  local runs = {}
  for key, run in pairs(self.runs) do
    runs[key] = run:toSaveData()
  end
  local data = {version = CURRENT_VERSION, runs = runs, records = self.records, lastDifficulty = self.lastDifficulty}
  local compressed = love.data.compress("string", "zlib", json.encode(data))
  ---@cast compressed string
  local ok, err = love.filesystem.write(ChallengeModeSave.path(self.name), compressed)
  if not ok then
    logger.error("Could not write the challenge mode save: " .. tostring(err))
  end
end

return ChallengeModeSave
