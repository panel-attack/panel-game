---@diagnostic disable: invisible
local logger = require("common.lib.logger")
local json = require("common.lib.dkjson")
local ClientProtocol = require("common.network.ClientProtocol")
local FileIO = require("server.FileIO")
local MockConnection = require("server.tests.MockConnection")
local ServerTesting = require("server.tests.ServerTesting")

local sep = package.config:sub(1, 1)
local REPORT_DIRECTORY = "errorReportTests"

local function removeReportDirectory()
  for _, name in ipairs(love.filesystem.getDirectoryItems(REPORT_DIRECTORY)) do
    love.filesystem.remove(REPORT_DIRECTORY .. "/" .. name)
  end
  love.filesystem.remove(REPORT_DIRECTORY)
end

-- empties the save directory's folder for test reports and returns its full path for the server
local function makeReportDirectory()
  removeReportDirectory()
  return love.filesystem.getSaveDirectory() .. sep .. REPORT_DIRECTORY
end

-- the names of the report files written, sorted
local function reportFileNames()
  local names = love.filesystem.getDirectoryItems(REPORT_DIRECTORY)
  table.sort(names)
  return names
end

-- runs fn while collecting every warn and error message logged
local function collectLogs(fn)
  local logged = {}
  local originalWarn, originalError = logger.warn, logger.error
  logger.warn = function(message)
    logged[#logged + 1] = message
  end
  logger.error = logger.warn
  local status, err = pcall(fn)
  logger.warn, logger.error = originalWarn, originalError
  assert(status, err)
  return logged
end

local function countMatching(messages, text)
  local count = 0
  for _, message in ipairs(messages) do
    if message:find(text, 1, true) then
      count = count + 1
    end
  end
  return count
end

-- sends one error report the way the client does: on a new connection, which the server closes afterwards
local function sendErrorReportFrom(server, ipAddress, report)
  local connection = MockConnection()
  connection.socket.getpeername = function()
    return ipAddress, 50000
  end
  server:addConnection(connection)
  connection:receiveMessage(json.encode(ClientProtocol.sendErrorReport(report).messageText))
  server:update()
end

local function reportsInTheSameSecondAreAllKept()
  local directory = makeReportDirectory()
  local timestamp = os.time({year = 2026, month = 11, day = 24, hour = 10, min = 0, sec = 0})

  assert(FileIO.write_error_report({engine_version = "047", name = "Bob", detail = "first"}, directory, timestamp))
  assert(FileIO.write_error_report({engine_version = "047", name = "Bob", detail = "second"}, directory, timestamp))

  local names = reportFileNames()
  assert(#names == 2, "Two reports in the same second should make two files, made " .. #names)
  local details = {}
  for _, name in ipairs(names) do
    assert(name:match("^v047%-%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d_Bob%-ErrorReport.*%.json$"), "Unexpected report file name " .. name)
    details[FileIO.readJson(directory .. sep .. name).detail] = true
  end
  assert(details.first and details.second, "Both reports should keep their own contents")
  removeReportDirectory()
end

-- the report files written, which must all be in the report folder and named in the report format
local function assertReportFilesAreWellNamed(expectedCount)
  local names = reportFileNames()
  assert(#names == expectedCount, "Expected " .. expectedCount .. " report files, found " .. #names)
  for _, name in ipairs(names) do
    assert(name:match("^v[%w_]+%-%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d_[%w_]+%-ErrorReport[%-%d]*%.json$"), "Unexpected report file name " .. name)
  end
  return names
end

local function reportFieldsCannotLeaveTheReportFolder()
  local directory = makeReportDirectory()
  local timestamp = os.time()

  assert(FileIO.write_error_report({engine_version = "/../../escaped", name = "..\\..\\escaped"}, directory, timestamp), "A report with separators in its fields should still be written")

  assertReportFilesAreWellNamed(1)
  removeReportDirectory()
end

-- io.open stops a path at a NUL, so a NUL in a field would give every copy number the same file
local function aNulInAReportFieldDoesNotStopNewNames()
  local directory = makeReportDirectory()
  local timestamp = os.time()

  assert(FileIO.write_error_report({engine_version = "\0", name = "a\0b"}, directory, timestamp))
  assert(FileIO.write_error_report({engine_version = "\0", name = "a\0b"}, directory, timestamp))

  assertReportFilesAreWellNamed(2)
  removeReportDirectory()
end

local function reportFieldsThatAreNotTextAreReplaced()
  local directory = makeReportDirectory()

  assert(FileIO.write_error_report({engine_version = {}, name = {nested = true}}, directory, os.time()))

  local names = assertReportFilesAreWellNamed(1)
  assert(names[1]:match("^v000%-.*_Unknown%-ErrorReport%.json$"), "Fields that aren't text should use the defaults, got " .. names[1])
  removeReportDirectory()
end

local function reportsFromOneAddressStopAtTheLimit()
  local server = ServerTesting.getTestServer()
  local directory = makeReportDirectory()
  server.errorReportDirectory = directory
  local limit = server.ERROR_REPORTS_PER_ADDRESS_PER_WINDOW

  local logged = collectLogs(function()
    for i = 1, limit + 5 do
      sendErrorReportFrom(server, "203.0.113.7", {engine_version = "047", name = "Flooder", detail = i})
    end
  end)

  assert(#reportFileNames() == limit, "Only " .. limit .. " reports from one address should be kept, kept " .. #reportFileNames())
  assert(countMatching(logged, "203.0.113.7") == 1, "Hitting the limit should be logged once, logged " .. countMatching(logged, "203.0.113.7"))
  assert(countMatching(logged, "Received an error report") == limit, "Dropped reports should not each be logged")

  sendErrorReportFrom(server, "198.51.100.2", {engine_version = "047", name = "Other"})
  assert(#reportFileNames() == limit + 1, "Another address should still be able to report")

  server.errorReportWindowsByAddress["203.0.113.7"].startTime = os.time() - server.ERROR_REPORT_WINDOW_SECONDS
  sendErrorReportFrom(server, "203.0.113.7", {engine_version = "047", name = "Flooder", detail = "later"})
  assert(#reportFileNames() == limit + 2, "An address should be able to report again once its window has passed")
  removeReportDirectory()
end

reportsInTheSameSecondAreAllKept()
reportFieldsCannotLeaveTheReportFolder()
aNulInAReportFieldDoesNotStopNewNames()
reportFieldsThatAreNotTextAreReplaced()
reportsFromOneAddressStopAtTheLimit()
