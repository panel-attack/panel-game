local Game = require("client.src.Game")

-- Returns a stand-in updater running versionString of a release stream that has installedVersionStrings on disk
-- and lists availableVersionStrings on the server, recording every version it is asked to remove
---@param versionString string the running version
---@param installedVersionStrings string[]
---@param availableVersionStrings string[]
local function createUpdater(versionString, installedVersionStrings, availableVersionStrings)
  local releaseStream = {name = "beta", installedVersions = {}, availableVersions = {}}
  for _, installedVersionString in ipairs(installedVersionStrings) do
    releaseStream.installedVersions[installedVersionString] = {
      version = installedVersionString,
      releaseStream = releaseStream,
      path = "updater/beta/" .. installedVersionString .. "/game.love",
    }
  end
  for _, availableVersionString in ipairs(availableVersionStrings) do
    releaseStream.availableVersions[#releaseStream.availableVersions + 1] = {version = availableVersionString, releaseStream = releaseStream}
  end

  return {
    state = 0,
    activeReleaseStream = releaseStream,
    activeVersion = releaseStream.installedVersions[versionString],
    removedVersionStrings = {},
    getAvailableVersions = function() end,
    update = function() end,
    removeInstalledVersion = function(updater, versionInfo)
      updater.removedVersionStrings[#updater.removedVersionStrings + 1] = versionInfo.version
      return true
    end,
  }
end

-- Runs Game:cleanupOldVersions for a game using updater to its end, with the updater states the updater defines
local function cleanupOldVersions(updater)
  local updaterStates = GAME_UPDATER_STATES
  GAME_UPDATER_STATES = {idle = 0, checkingForUpdates = 1, downloading = 2}
  local cleanup = coroutine.create(Game.cleanupOldVersions)
  local ok, err = coroutine.resume(cleanup, {updater = updater})
  while ok and coroutine.status(cleanup) ~= "dead" do
    ok, err = coroutine.resume(cleanup)
  end
  GAME_UPDATER_STATES = updaterStates
  assert(ok, err)
end

local function testCleanupKeepsTheRunningVersionTheServerNoLongerLists()
  local updater = createUpdater("2025-07-15_00-00-00", {"2025-07-01_00-00-00", "2025-07-15_00-00-00"}, {"2025-08-01_00-00-00"})

  cleanupOldVersions(updater)

  assert(#updater.removedVersionStrings == 1, "only the version that isn't running should be removed, but "
    .. #updater.removedVersionStrings .. " were: " .. table.concat(updater.removedVersionStrings, ", "))
  assert(updater.removedVersionStrings[1] == "2025-07-01_00-00-00", "the version that isn't running should be removed")
end

testCleanupKeepsTheRunningVersionTheServerNoLongerLists()

local function testCleanupKeepsVersionsTheServerStillLists()
  local updater = createUpdater("2025-08-01_00-00-00", {"2025-07-01_00-00-00", "2025-08-01_00-00-00"}, {"2025-07-01_00-00-00", "2025-08-01_00-00-00"})

  cleanupOldVersions(updater)

  assert(#updater.removedVersionStrings == 0, "no listed version should be removed, but "
    .. table.concat(updater.removedVersionStrings, ", ") .. " were")
end

testCleanupKeepsVersionsTheServerStillLists()
