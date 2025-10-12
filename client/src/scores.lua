local levelPresets = require("common.data.LevelPresets")
local fileUtils = require("client.src.FileUtils")
local PuzzleLibrary = require("client.src.PuzzleLibrary")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local logger = require("common.lib.logger")

-- 1 had only vs scores in an incompatible format
-- 2 has vs self, time attack, endless
-- 3 has vs self, time attack, endless, puzzles
-- 4 has vs self, time attack, endless, puzzles UUIDv2 (original)
-- 5 has vs self, time attack, endless, puzzles UUIDv2 (with cursor/buffers)
local currentVersion = 5

-- Holds on the current scores and records for game modes
---@class Scores
---@field version number
---@field vsSelf table
---@field timeAttack1P table
---@field endless table
---@field puzzleRecords table
Scores =
    class(
      function(self)
        -- The lastly used version
        self.version = currentVersion

        self.vsSelf = {}
        for i = 1, levelPresets.modernPresetCount do
          self.vsSelf[i] = {}
          self.vsSelf[i]["record"] = 0
          self.vsSelf[i]["last"] = 0
        end

        self.timeAttack1P = {}
        for i = 1, levelPresets.classicPresetCount do
          self.timeAttack1P[i] = {}
          self.timeAttack1P[i]["record"] = 0
          self.timeAttack1P[i]["last"] = 0
        end

        self.endless = {}
        for i = 1, levelPresets.classicPresetCount do
          self.endless[i] = {}
          self.endless[i]["record"] = 0
          self.endless[i]["last"] = 0
        end

        self.puzzleRecords = {}
      end
    )

-- Saves the given puzzle record to the scores file
function Scores:savePuzzleRecord(puzzle, inputs, timestamp, success)
  assert(puzzle.UUID ~= nil)
  local puzzleRecord = {}
  puzzleRecord.inputs = inputs
  puzzleRecord.timestamp = timestamp
  puzzleRecord.success = success

  if self.puzzleRecords[puzzle.UUID] == nil then
    self.puzzleRecords[puzzle.UUID] = {}
  end
  self.puzzleRecords[puzzle.UUID][#self.puzzleRecords[puzzle.UUID] + 1] = puzzleRecord

  self:saveToFile()
end

-- Returns all records for the given puzzle UUID
function Scores:getRecordsForPuzzleUUID(puzzleUUID)
  return self.puzzleRecords[puzzleUUID] or {}
end

-- Returns up to the given number of records for a given puzzle UUID, only counting using the filter if one is given.
---@param n integer the number of records to return
---@param filter function? an optional filter function run on a record, return true if the record should be included
---@param puzzleUUID string the puzzle UUID to search
function Scores:getNRecordsMatchingFilterForPuzzleUUID(n, filter, puzzleUUID)
  local filteredTable = {}
  local records = self:getRecordsForPuzzleUUID(puzzleUUID)
  for i = #records, 1, -1 do
    local value = records[i]
    if filter(value) then
      filteredTable[#filteredTable + 1] = value
      if #filteredTable >= n then
        break
      end
    end
  end

  return filteredTable
end

-- Returns the latest record that succeed at this puzzle or nil if none
function Scores:getLatestSuccessForPuzzleUUID(puzzleUUID)
  local records = self:getNRecordsMatchingFilterForPuzzleUUID(1, function(record) return record.success == true end,
    puzzleUUID)
  if #records == 0 then
    return nil
  end
  return records[#records]
end

-- Returns the number of times this puzzle has been won in a row
function Scores:puzzleUUIDWinStreak(puzzleUUID)
  local records = self:getRecordsForPuzzleUUID(puzzleUUID)

  local winStreak = 0
  for i = #records, 1, -1 do
    local currentRecord = records[i]
    if currentRecord.success == false then
      break
    end
    winStreak = winStreak + 1
  end

  return winStreak
end

-- returns true if the puzzle has ever been beaten
function Scores:puzzleEverBeaten(puzzleUUID)
  return self:getLatestSuccessForPuzzleUUID(puzzleUUID) ~= nil
end

-- Returns 0 if the puzzle has never been played, otherwise, the percentage of wins
function Scores:puzzleSuccessRateForUUID(puzzleUUID)
  local records = self:getNRecordsMatchingFilterForPuzzleUUID(5, function(record) return true end, puzzleUUID)

  if #records == 0 then
    return 0
  end

  local winRecords = tableUtils.filter(records, function(record) return record.success end)

  local result = #winRecords / #records
  return result
end

function Scores.saveVsSelfScoreForLevel(self, score, level)
  self.vsSelf[level]["last"] = score
  if self.vsSelf[level]["record"] < score then
    self.vsSelf[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastVsScoreForLevel(self, level)
  if #self.vsSelf < level then
    return 0
  end
  return self.vsSelf[level]["last"]
end

function Scores.recordVsScoreForLevel(self, level)
  if #self.vsSelf < level then
    return 0
  end
  return self.vsSelf[level]["record"]
end

function Scores.saveTimeAttack1PScoreForLevel(self, score, level)
  self.timeAttack1P[level]["last"] = score
  if self.timeAttack1P[level]["record"] < score then
    self.timeAttack1P[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastTimeAttack1PForLevel(self, level)
  if #self.timeAttack1P < level then
    return 0
  end
  return self.timeAttack1P[level]["last"]
end

function Scores.recordTimeAttack1PForLevel(self, level)
  if #self.timeAttack1P < level then
    return 0
  end
  return self.timeAttack1P[level]["record"]
end

function Scores.saveEndlessScoreForLevel(self, score, level)
  self.endless[level]["last"] = score
  if self.endless[level]["record"] < score then
    self.endless[level]["record"] = score
  end
  self:saveToFile()
end

function Scores.lastEndlessForLevel(self, level)
  if #self.endless < level then
    return 0
  end
  return self.endless[level]["last"]
end

function Scores.recordEndlessForLevel(self, level)
  if #self.endless < level then
    return 0
  end
  return self.endless[level]["record"]
end

function Scores.createFromScoreFile()
  local scores = Scores()
  local scoreData = nil
  pcall(
    function()
      scoreData = fileUtils.readJsonFile("scores.json")
    end
  )
  if scoreData then
    if scoreData.version and type(scoreData.version) == "number" then
      scores.version = scoreData.version
    elseif scoreData.vsSelf["last"] then
      scores.version = 1
    end

    -- Ignore the scores save file if its the original incompatible format
    if scores.version > 1 then
      if scoreData.vsSelf then
        scores.vsSelf = scoreData.vsSelf
      end
      if scoreData.timeAttack1P then
        scores.timeAttack1P = scoreData.timeAttack1P
      end
      if scoreData.endless then
        scores.endless = scoreData.endless
      end
      if scoreData.puzzleRecords then
        local puzzleRecords = scoreData.puzzleRecords
        scores.puzzleRecords = puzzleRecords
        if scores.version == 3 then
          scores:upgradeFromScoreData(scoreData)
        elseif scores.version == 4 then
          scores:upgradeFromV4ToV5(scoreData)
        end
      end

      if scores.version < currentVersion then
        scores.version = currentVersion
        scores:saveToFile()
      end
    end
  end

  return scores
end

function Scores:upgradeFromScoreData(scoreData)
  local puzzleLibrary = PuzzleLibrary(Scores())
  local defaultPuzzleSet = puzzleLibrary:getDefaultPuzzleSet()
  local flattenedPuzzleSet = puzzleLibrary:flattenedPuzzleSetForPuzzleSet(defaultPuzzleSet)
  for _, puzzle in ipairs(flattenedPuzzleSet.puzzles) do
    local oldUUID = puzzle:getV1UUID()
    local newUUID = puzzle:getV2UUID()
    if self.puzzleRecords[oldUUID] then
      local oldRecords = self.puzzleRecords[oldUUID]
      for _, record in ipairs(oldRecords) do
        record.UUID = nil
      end
      self.puzzleRecords[newUUID] = oldRecords
      self.puzzleRecords[oldUUID] = nil
    end
  end
end

function Scores:upgradeFromV4ToV5(scoreData)
  local puzzleLibrary = PuzzleLibrary(Scores())
  local defaultPuzzleSet = puzzleLibrary:getDefaultPuzzleSet()
  local flattenedPuzzleSet = puzzleLibrary:flattenedPuzzleSetForPuzzleSet(defaultPuzzleSet)
  for _, puzzle in ipairs(flattenedPuzzleSet.puzzles) do
    local oldUUID = puzzle:getV2UUIDOld()
    local newUUID = puzzle:getV2UUID()
    if self.puzzleRecords[oldUUID] then
      local oldRecords = self.puzzleRecords[oldUUID]
      for _, record in ipairs(oldRecords) do
        record.UUID = nil
      end
      self.puzzleRecords[newUUID] = oldRecords
      self.puzzleRecords[oldUUID] = nil
    end
  end
end

function Scores.saveToFile(self)
  if self.version == currentVersion then
    local encodedScores = json.encode(self)
    ---@cast encodedScores string
    love.filesystem.write("scores.json", encodedScores)
  end
end

return Scores
