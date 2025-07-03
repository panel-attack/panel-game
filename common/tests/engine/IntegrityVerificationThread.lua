require("love.math")
require("love.timer")
local verification = require("common.tests.engine.IntegrityVerificationSingle")
local fileUtils = require("client.src.FileUtils")

-- to speed up the test a bit, turn logger functions into empty functions so that stdout doesn't have to happen
-- with some luck, luajit will correct identify all args to these functions as unused and optimize them out, saving a huge load of string concatenation
local logger = require("common.lib.logger")
local f = function() end
logger.trace = f
logger.debug = f
logger.info = f

local stopChannel = love.thread.getChannel("stop")

local filePaths, versionOverride = ...

for _, filePath in ipairs(filePaths) do
  local jsonTable = fileUtils.readJsonFile(filePath)
  if not jsonTable then
    love.thread.getChannel("verificationResult"):push({filePath = filePath, message = "Failed to read json"})
  else
    local replay = verification.loadReplay(jsonTable, versionOverride)
    if not replay then
      love.thread.getChannel("verificationResult"):push({filePath = filePath, message = "Failed to create replay"})
    else
      local verified, winnerIndex, clock, expectedDuration = verification.verifyReplay(replay)
      love.thread.getChannel("verificationResult"):push({verified = verified,
                                                winnerIndex = winnerIndex,
                                                expectedWinnerIndex = (replay.metadata.winnerIndex or "unknown"),
                                                clock = clock,
                                                expectedDuration = expectedDuration,
                                                filePath = filePath})
    end
  end
  if stopChannel:peek() then
    break
  end
end