local class = require("common.lib.class")
local logger = require("common.lib.logger")
local ChallengeRun = require("client.src.ChallengeRun")

local CURRENT_VERSION = 1

-- The unfinished Challenge Mode run of each difficulty, the runs that beat it and the difficulty played last,
-- saved as compressed JSON
---@class ChallengeModeSave
---@field name string the save file's name without extension
---@field runs table<string, ChallengeRun> the unfinished run of each difficulty, keyed by the difficulty as a string
---@field completedRuns table<string, ChallengeRun[]> the runs that beat each difficulty, oldest first, keyed by the difficulty as a string
---@field lastDifficulty integer? the difficulty of the run saved last
---@overload fun(name: string): ChallengeModeSave
local ChallengeModeSave = class(
  function(self, name)
    self.name = name
    self.runs = {}
    self.completedRuns = {}
  end
)

-- Returns the path of the file the save named name is written to
---@param name string
---@return string
function ChallengeModeSave.path(name)
  return name .. ".sav"
end

-- Fills the save from the compressed contents of its file, raising an error if they are damaged
---@param contents string
function ChallengeModeSave:readContents(contents)
  local data = json.decode(love.data.decompress("string", "zlib", contents))
  self.lastDifficulty = data.lastDifficulty
  for difficulty, runData in pairs(data.runs or {}) do
    self.runs[difficulty] = ChallengeRun.fromSaveData(runData)
  end
  for difficulty, runsData in pairs(data.completedRuns or {}) do
    local completedRuns = {}
    for i, runData in ipairs(runsData) do
      completedRuns[i] = ChallengeRun.fromSaveData(runData)
    end
    self.completedRuns[difficulty] = completedRuns
  end
end

-- Loads the save named name, or an empty save if there is none or it is damaged
---@param name string
---@return ChallengeModeSave
function ChallengeModeSave.load(name)
  local save = ChallengeModeSave(name)
  local contents = love.filesystem.read(ChallengeModeSave.path(name))
  -- love.data.decompress never returns for empty input, so an empty file is skipped before it
  if contents and #contents > 0 then
    local ok, err = pcall(save.readContents, save, contents)
    if not ok then
      logger.error("Could not read the challenge mode save, starting from an empty one: " .. tostring(err))
      save = ChallengeModeSave(name)
    end
  end
  return save
end

-- Returns the difficulty's unfinished run, nil if it has none
---@param difficulty integer
---@return ChallengeRun?
function ChallengeModeSave:getRun(difficulty)
  return self.runs[tostring(difficulty)]
end

-- Returns the fewest continues any completed run of the difficulty used, nil if it was never beaten
---@param difficulty integer
---@return integer?
function ChallengeModeSave:getBestContinues(difficulty)
  local best
  for _, run in ipairs(self:getCompletedRuns(difficulty)) do
    local continues = run:getContinues()
    if best == nil or continues < best then
      best = continues
    end
  end
  return best
end

-- Returns the fewest frames any completed run of the difficulty took, nil if it was never beaten
---@param difficulty integer
---@return integer?
function ChallengeModeSave:getBestTime(difficulty)
  local best
  for _, run in ipairs(self:getCompletedRuns(difficulty)) do
    local frames = run:getTime()
    if best == nil or frames < best then
      best = frames
    end
  end
  return best
end

-- Returns the difficulty of the run saved last, nil if no run was saved yet
---@return integer?
function ChallengeModeSave:getLastDifficulty()
  return self.lastDifficulty
end

-- Returns every run that beat the difficulty, oldest first
---@param difficulty integer
---@return ChallengeRun[]
function ChallengeModeSave:getCompletedRuns(difficulty)
  return self.completedRuns[tostring(difficulty)] or {}
end

-- Writes the run to disk; a completed run is moved to its difficulty's completed runs
---@param run ChallengeRun
function ChallengeModeSave:saveRun(run)
  local key = tostring(run.difficulty)
  self.lastDifficulty = run.difficulty
  if run.complete then
    self.runs[key] = nil
    local completedRuns = self.completedRuns[key] or {}
    completedRuns[#completedRuns + 1] = run
    self.completedRuns[key] = completedRuns
  else
    self.runs[key] = run
  end
  self:write()
end

-- Removes the difficulty's unfinished run from disk
---@param difficulty integer
function ChallengeModeSave:discardRun(difficulty)
  self.runs[tostring(difficulty)] = nil
  self:write()
end

-- Writes the unfinished runs, the completed runs and the last played difficulty to the save file
function ChallengeModeSave:write()
  local runs = {}
  for key, run in pairs(self.runs) do
    runs[key] = run:toSaveData()
  end
  local completedRuns = {}
  for key, difficultyRuns in pairs(self.completedRuns) do
    completedRuns[key] = {}
    for i, run in ipairs(difficultyRuns) do
      completedRuns[key][i] = run:toSaveData()
    end
  end
  local data = {version = CURRENT_VERSION, runs = runs, completedRuns = completedRuns, lastDifficulty = self.lastDifficulty}
  local compressed = love.data.compress("string", "zlib", json.encode(data))
  ---@cast compressed string
  local ok, err = love.filesystem.write(ChallengeModeSave.path(self.name), compressed)
  if not ok then
    logger.error("Could not write the challenge mode save: " .. tostring(err))
  end
end

return ChallengeModeSave
