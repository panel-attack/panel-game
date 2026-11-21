local save = require("client.src.save")
local json = require("common.lib.dkjson")

local ATTACK_FILE = json.encode({attackPatterns = {{width = 6, height = 1, startTime = 0}}, delayBeforeRepeat = 91})

-- attack files are found in subfolders of the training folder too, the ones starting with __ are skipped
local function attackFilesInSubfoldersAreRead()
  local folder = "saveTestsTraining"
  love.filesystem.createDirectory(folder .. "/sub")
  love.filesystem.createDirectory(folder .. "/__ignored")
  love.filesystem.write(folder .. "/top.json", ATTACK_FILE)
  love.filesystem.write(folder .. "/sub/nested.json", ATTACK_FILE)
  love.filesystem.write(folder .. "/__ignored/skipped.json", ATTACK_FILE)

  local names = {}
  for _, attackFile in ipairs(save.readAttackFiles(folder)) do
    names[#names + 1] = attackFile.name
  end
  table.sort(names)

  love.filesystem.remove(folder .. "/__ignored/skipped.json")
  love.filesystem.remove(folder .. "/__ignored")
  love.filesystem.remove(folder .. "/sub/nested.json")
  love.filesystem.remove(folder .. "/sub")
  love.filesystem.remove(folder .. "/top.json")
  love.filesystem.remove(folder)
  assert(#names == 2 and names[1] == "nested" and names[2] == "top", "read " .. table.concat(names, ", "))
end

attackFilesInSubfoldersAreRead()
