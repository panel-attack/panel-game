local ModSettings = require("client.src.mods.ModSettings")
local fileUtils = require("client.src.FileUtils")
local json = require("common.lib.dkjson")

-- every test works in this folder of the save directory so it never touches the player's settings
local DIRECTORY = "modSettingsTests"
local FILE = DIRECTORY .. "/" .. ModSettings.FILE_NAME
local BROKEN_FILE = DIRECTORY .. "/" .. ModSettings.BROKEN_FILE_NAME

local function removeTestFiles()
  love.filesystem.remove(FILE)
  love.filesystem.remove(BROKEN_FILE)
  love.filesystem.remove(DIRECTORY .. "/characters/blacklist.txt")
  love.filesystem.remove(DIRECTORY .. "/stages/blacklist.txt")
  love.filesystem.remove(DIRECTORY .. "/characters")
  love.filesystem.remove(DIRECTORY .. "/stages")
  love.filesystem.remove(DIRECTORY)
end

local function writeFile(path, content)
  local folder = path:match("^(.*)/[^/]*$")
  love.filesystem.createDirectory(folder)
  love.filesystem.write(path, content)
end

local function writeSettingsFile(data)
  writeFile(FILE, json.encode(data))
end

local function readSettingsFile()
  local content = love.filesystem.read(FILE)
  local data = json.decode(content)
  assert(type(data) == "table", "the saved file is not valid json:\n" .. tostring(content))
  return data
end

local function loadedSettings()
  local settings = ModSettings(DIRECTORY)
  settings:load()
  return settings
end

-- runs a test in an empty folder and cleans up after it, also when it fails
local function run(test)
  removeTestFiles()
  local success, err = pcall(test)
  removeTestFiles()
  assert(success, err)
end

local function testMissingFileHasNoEntries()
  local settings = loadedSettings()

  assert(next(settings:getEntries("characters")) == nil, "a missing file customizes nothing")
  assert(settings:getStatus("characters", "Chocola") == nil)
end

local function testEntriesAreReadFromTheFile()
  writeSettingsFile({version = 1, characters = {["PPL/Gym Leaders"] = {status = "hidden", order = {"Misty", "Brock"}}}})

  local entry = loadedSettings():getEntries("characters")["PPL/Gym Leaders"]

  assert(entry.status == "hidden", "expected hidden, got " .. tostring(entry.status))
  assert(entry.order[1] == "Misty" and entry.order[2] == "Brock", "the order is kept as written")
end

local function testUnknownStatusIsDroppedButTheOrderStays()
  writeSettingsFile({version = 1, characters = {Chocola = {status = "visible", order = {"a"}}}})

  local entry = loadedSettings():getEntries("characters").Chocola

  assert(entry.status == nil, "a status outside the enum is ignored")
  assert(entry.order[1] == "a")
end

local function testOrderKeepsOnlyNames()
  writeSettingsFile({version = 1, stages = {[""] = {status = "shown", order = {"a", 3, {}, "b"}}}})

  local order = loadedSettings():getEntries("stages")[""].order

  assert(#order == 2 and order[1] == "a" and order[2] == "b", "values that are not names are dropped from an order")
end

local function testEntryThatIsNotAnObjectIsDropped()
  writeSettingsFile({version = 1, characters = {Chocola = "off", Brock = {status = "off"}}})

  local entries = loadedSettings():getEntries("characters")

  assert(entries.Chocola == nil, "an entry that is not an object is ignored")
  assert(entries.Brock.status == "off", "the other entries are still read")
end

local function testNewerVersionIsIgnored()
  writeSettingsFile({version = ModSettings.VERSION + 1, characters = {Chocola = {status = "off", order = {"a"}}}})

  local settings = loadedSettings()

  assert(next(settings:getEntries("characters")) == nil, "nothing is read from a file from a newer build")
end

local function testNewerVersionWritesNoBlacklist()
  writeSettingsFile({version = ModSettings.VERSION + 1, characters = {}})
  writeFile(DIRECTORY .. "/characters/blacklist.txt", "telegraph")

  local settings = loadedSettings()
  settings:writeBlacklist("characters", {"brock"}, {telegraph = true, brock = true})

  assert(love.filesystem.read(DIRECTORY .. "/characters/blacklist.txt") == "telegraph", "blacklist.txt is left as it is")
end

local function testBlacklistIsIgnoredWhenTheFileIsFromANewerVersion()
  writeSettingsFile({version = ModSettings.VERSION + 1, characters = {}})
  writeFile(DIRECTORY .. "/characters/blacklist.txt", "telegraph")

  local settings = loadedSettings()
  settings:importBlacklist("characters", {telegraph = "blargg/telegraph"})

  assert(settings:getStatus("characters", "blargg/telegraph") == nil, "a newer file is used instead of blacklist.txt")
end

local function testNewerVersionIsNotOverwritten()
  writeSettingsFile({version = ModSettings.VERSION + 1, characters = {Chocola = {status = "off"}}})
  local before = love.filesystem.read(FILE)

  local settings = loadedSettings()
  settings:setStatus("characters", "Brock", "hidden")
  settings:save()

  assert(love.filesystem.read(FILE) == before, "a file from a newer build is left as it is")
end

local function testUnparseableFileIsSetAside()
  writeFile(FILE, "{ this is not json")

  local settings = loadedSettings()

  assert(next(settings:getEntries("characters")) == nil, "nothing is read from a broken file")
  assert(not fileUtils.exists(FILE), "the broken file is moved out of the way")
  assert(love.filesystem.read(BROKEN_FILE) == "{ this is not json", "the broken file is kept under another name")
end

local function testUnparseableFileStaysWhenItsCopyCannotBeWritten()
  writeFile(FILE, "{ this is not json")
  local write = love.filesystem.write
  love.filesystem.write = function()
    return false, "the disk is full"
  end

  local success, err = pcall(loadedSettings)
  love.filesystem.write = write

  assert(success, err)
  assert(love.filesystem.read(FILE) == "{ this is not json", "the only copy of the file is kept")
end

local function testCopyEntryIsIndependentOfTheSettings()
  local settings = loadedSettings()
  settings:setStatus("characters", "Chocola", "hidden")

  local copy = settings:copyEntry("characters", "Chocola")
  settings:setStatus("characters", "Chocola", "off")

  assert(copy and copy.status == "hidden", "the copy keeps the status it was taken with")
  assert(settings:copyEntry("characters", "Vanilla") == nil, "a key without an entry has no copy")
end

local function testFileWithoutVersionIsSetAside()
  writeSettingsFile({characters = {Chocola = {status = "off"}}})

  local settings = loadedSettings()

  assert(settings:getStatus("characters", "Chocola") == nil, "a file without a version is not trusted")
  assert(fileUtils.exists(BROKEN_FILE), "the file without a version is kept under another name")
end

local function testSaveWritesVersionAndEntries()
  local settings = loadedSettings()
  settings:setStatus("characters", "PPL/Gym Leaders/Brock", "off")
  settings:setOrder("stages", "@builtin", {"Magellan Night", "Magellan Day"}, "shown")
  settings:save()

  local saved = readSettingsFile()

  assert(saved.version == ModSettings.VERSION, "the file carries its version")
  assert(saved.characters["PPL/Gym Leaders/Brock"].status == "off")
  assert(saved.stages["@builtin"].status == "shown", "an entry always holds a status")
  assert(saved.stages["@builtin"].order[2] == "Magellan Day")
  assert(type(saved.panels) == "table", "every mod type has a section")
end

local function testSettingStatusKeepsTheOrder()
  local settings = loadedSettings()
  settings:setOrder("characters", "", {"b", "a"}, "shown")

  settings:setStatus("characters", "", "hidden")

  local entry = settings:getEntries("characters")[""]
  assert(entry.status == "hidden" and entry.order[1] == "b", "changing the status leaves the order alone")
end

local function testSettingOrderKeepsTheStatus()
  local settings = loadedSettings()
  settings:setStatus("characters", "PPL", "hidden")

  settings:setOrder("characters", "PPL", {"b", "a"}, "shown")

  assert(settings:getStatus("characters", "PPL") == "hidden", "an existing status wins over the default passed in")
end

local function testEntriesForMissingModsSurviveASave()
  writeSettingsFile({version = 1, characters = {["Uninstalled Pack/Someone"] = {status = "off"}}})

  local settings = loadedSettings()
  settings:setStatus("characters", "Chocola", "hidden")
  settings:save()

  assert(readSettingsFile().characters["Uninstalled Pack/Someone"].status == "off", "entries are kept for mods that come back")
end

local function testBlacklistIsImportedWhenThereIsNoFile()
  writeFile(DIRECTORY .. "/characters/blacklist.txt", "telegraph\nnot installed")

  local settings = loadedSettings()
  settings:importBlacklist("characters", {telegraph = "blargg/telegraph"})

  assert(settings:getStatus("characters", "blargg/telegraph") == "off", "a blacklisted mod starts off")
end

local function testBlacklistIsIgnoredOnceTheFileExists()
  writeSettingsFile({version = 1, characters = {}})
  writeFile(DIRECTORY .. "/characters/blacklist.txt", "telegraph")

  local settings = loadedSettings()
  settings:importBlacklist("characters", {telegraph = "blargg/telegraph"})

  assert(settings:getStatus("characters", "blargg/telegraph") == nil, "the file is the truth once it exists")
end

local function testBlacklistMirrorKeepsIdsOfModsThatAreNotInstalled()
  writeFile(DIRECTORY .. "/characters/blacklist.txt", "not installed\ntelegraph")

  local settings = loadedSettings()
  settings:writeBlacklist("characters", {"brock"}, {telegraph = true, brock = true})

  local lines = {}
  for line in love.filesystem.lines(DIRECTORY .. "/characters/blacklist.txt") do
    lines[#lines + 1] = line
  end
  assert(table.concat(lines, ",") == "not installed,brock", "expected not installed,brock, got " .. table.concat(lines, ","))
end

run(testMissingFileHasNoEntries)
run(testEntriesAreReadFromTheFile)
run(testUnknownStatusIsDroppedButTheOrderStays)
run(testOrderKeepsOnlyNames)
run(testEntryThatIsNotAnObjectIsDropped)
run(testNewerVersionIsIgnored)
run(testNewerVersionWritesNoBlacklist)
run(testBlacklistIsIgnoredWhenTheFileIsFromANewerVersion)
run(testNewerVersionIsNotOverwritten)
run(testUnparseableFileIsSetAside)
run(testUnparseableFileStaysWhenItsCopyCannotBeWritten)
run(testCopyEntryIsIndependentOfTheSettings)
run(testFileWithoutVersionIsSetAside)
run(testSaveWritesVersionAndEntries)
run(testSettingStatusKeepsTheOrder)
run(testSettingOrderKeepsTheStatus)
run(testEntriesForMissingModsSurviveASave)
run(testBlacklistIsImportedWhenThereIsNoFile)
run(testBlacklistIsIgnoredOnceTheFileExists)
run(testBlacklistMirrorKeepsIdsOfModsThatAreNotInstalled)
