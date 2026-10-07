local Scores = require("client.src.scores")

local function record(timestamp)
  return {inputs = "A", timestamp = timestamp, success = true}
end

-- a puzzle whose UUID changed keeps the records it had under the old one
local function recordsUnderAnOldUUIDMoveToThePuzzle()
  local scores = Scores()
  scores.puzzleRecords["old"] = {record(1), record(2)}

  local moved = scores:carryRecordsToPuzzle({UUID = "new", oldUUIDs = {"old"}})

  assert(moved, "a record was moved, so the scores need saving")
  assert(scores.puzzleRecords["old"] == nil, "nothing is left under the old UUID")
  assert(#scores.puzzleRecords["new"] == 2 and scores.puzzleRecords["new"][2].timestamp == 2, "both records are under the new UUID")
end

-- records already made under the new UUID stay, after the older ones carried across
local function carriedRecordsGoBeforeTheNewOnes()
  local scores = Scores()
  scores.puzzleRecords["old"] = {record(1)}
  scores.puzzleRecords["new"] = {record(5)}

  scores:carryRecordsToPuzzle({UUID = "new", oldUUIDs = {"old"}})

  local records = scores.puzzleRecords["new"]
  assert(#records == 2 and records[1].timestamp == 1 and records[2].timestamp == 5, "the carried record comes first")
end

-- a puzzle changed twice lists both old UUIDs, oldest first, and its records keep that order
local function recordsUnderEveryOldUUIDMoveInListOrder()
  local scores = Scores()
  scores.puzzleRecords["first"] = {record(1)}
  scores.puzzleRecords["second"] = {record(2)}

  scores:carryRecordsToPuzzle({UUID = "third", oldUUIDs = {"first", "second"}})

  local records = scores.puzzleRecords["third"]
  assert(scores.puzzleRecords["first"] == nil and scores.puzzleRecords["second"] == nil)
  assert(#records == 2 and records[1].timestamp == 1 and records[2].timestamp == 2, "the records keep their order")
end

-- once carried, loading again moves nothing, so the scores file is not rewritten on every start
local function nothingToCarryMovesNothing()
  local scores = Scores()
  scores.puzzleRecords["new"] = {record(1)}

  assert(not scores:carryRecordsToPuzzle({UUID = "new", oldUUIDs = {"old"}}))
  assert(not scores:carryRecordsToPuzzle({UUID = "new"}), "a puzzle that never changed has nothing to carry")
  assert(#scores.puzzleRecords["new"] == 1)
end

recordsUnderAnOldUUIDMoveToThePuzzle()
carriedRecordsGoBeforeTheNewOnes()
recordsUnderEveryOldUUIDMoveInListOrder()
nothingToCarryMovesNothing()
