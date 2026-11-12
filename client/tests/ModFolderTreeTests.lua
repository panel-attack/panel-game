local ModFolderTree = require("client.src.mods.ModFolderTree")
local ModSettings = require("client.src.mods.ModSettings")

local function fakeMod(id, path, isVisible)
  return {id = id, path = path, isVisible = isVisible ~= false, subIds = {}}
end

-- the installed characters, in the order today's path sort lists them
local function installedCharacters()
  return {
    fakeMod("ash", "characters/PPL/Ash"),
    fakeMod("brock", "characters/PPL/Gym Leaders/Brock"),
    fakeMod("misty", "characters/PPL/Gym Leaders/Misty"),
    fakeMod("chocola", "characters/chocola"),
    fakeMod("esme", "client/assets/default_data/characters/esme"),
    fakeMod("madamq", "client/assets/default_data/characters/madamq", false),
  }
end

-- builds the tree the way the loaders do, from mods in default order and the settings' entries
local function buildFolderTree(mods, settings)
  return ModFolderTree.fromMods(mods, "characters", settings or ModSettings("unused"))
end

local function modIds(tree)
  local ids = {}
  for _, node in ipairs(tree:getModNodesInOrder()) do
    ids[#ids + 1] = node.mod.id
  end
  return table.concat(ids, ",")
end

local function assertEqual(actual, expected, what)
  assert(actual == expected, "expected " .. what .. " to be " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function testUserModKeyIsRelativeToTheSaveDirectory()
  assertEqual(ModFolderTree.settingsKeyForPath("characters/PPL/Ash", "characters"), "PPL/Ash", "the key")
end

local function testBundledModKeyIsUnderBuiltin()
  local key = ModFolderTree.settingsKeyForPath("client/assets/default_data/stages/Magellan Day", "stages")
  assertEqual(key, "@builtin/Magellan Day", "the key")
end

local function testDefaultPanelSetKeyIsUnderBuiltin()
  assertEqual(ModFolderTree.settingsKeyForPath("client/assets/panels/__default", "panels"), "@builtin/__default", "the key")
end

local function testDefaultOrderIsTheOrderTheModsCameIn()
  assertEqual(modIds(buildFolderTree(installedCharacters())), "ash,brock,misty,chocola,esme,madamq", "the mod order")
end

local function testModWithoutEntryShowsUnlessItsConfigHidesIt()
  local tree = buildFolderTree(installedCharacters())

  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("chocola")), "shown", "chocola's status")
  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("@builtin/madamq")), "hidden", "madamq's status")
end

local function testFolderCapsWhatIsInside()
  local settings = ModSettings("unused")
  settings:setStatus("characters", "PPL/Gym Leaders", "hidden")
  settings:setStatus("characters", "PPL/Gym Leaders/Misty", "shown")
  local tree = buildFolderTree(installedCharacters(), settings)

  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("PPL/Gym Leaders/Misty")), "hidden", "misty's status in a hidden folder")
  assertEqual(tree:getOwnStatus(tree:getNodeByKey("PPL/Gym Leaders/Misty")), "shown", "misty's own status")
end

local function testLowerOwnStatusWinsOverItsFolder()
  local settings = ModSettings("unused")
  settings:setStatus("characters", "PPL/Gym Leaders", "hidden")
  settings:setStatus("characters", "PPL/Gym Leaders/Brock", "off")
  local tree = buildFolderTree(installedCharacters(), settings)

  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("PPL/Gym Leaders/Brock")), "off", "brock's status")
end

local function testFolderStatusCapsEveryDepth()
  local settings = ModSettings("unused")
  settings:setStatus("characters", "PPL", "off")
  local tree = buildFolderTree(installedCharacters(), settings)

  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("PPL/Gym Leaders/Misty")), "off", "misty's status two folders down")
end

local function testChangesToTheSettingsApplyWithoutRebuilding()
  local settings = ModSettings("unused")
  local tree = buildFolderTree(installedCharacters(), settings)

  settings:setStatus("characters", "chocola", "off")

  assertEqual(tree:getEffectiveStatus(tree:getNodeByKey("chocola")), "off", "chocola's status")
end

local function testOrderListsNamedChildrenFirst()
  local settings = ModSettings("unused")
  settings:setOrder("characters", "", {"@builtin", "chocola", "PPL"}, "shown")

  assertEqual(modIds(buildFolderTree(installedCharacters(), settings)), "esme,madamq,chocola,ash,brock,misty", "the mod order")
end

local function testModMissingFromTheOrderGoesLast()
  local settings = ModSettings("unused")
  settings:setOrder("characters", "PPL/Gym Leaders", {"Misty"}, "shown")

  assertEqual(modIds(buildFolderTree(installedCharacters(), settings)), "ash,misty,brock,chocola,esme,madamq", "the mod order")
end

local function testOrderNamingMissingModsIsIgnored()
  local settings = ModSettings("unused")
  settings:setOrder("characters", "PPL/Gym Leaders", {"Lance", "Misty", "Brock"}, "shown")
  local tree = buildFolderTree(installedCharacters(), settings)

  local names = {}
  for _, child in ipairs(tree:getOrderedChildren(tree:getNodeByKey("PPL/Gym Leaders"))) do
    names[#names + 1] = child.name
  end
  assertEqual(table.concat(names, ","), "Misty,Brock", "the children")
end

local function testModInsideAModFolderComesAfterIt()
  local mods = {fakeMod("bundle", "characters/bundle"), fakeMod("sub", "characters/bundle/sub")}
  local tree = buildFolderTree(mods)

  assertEqual(modIds(tree), "bundle,sub", "the mod order")
  assertEqual(tree:getNodeByKey("bundle/sub").parent, tree:getNodeByKey("bundle"), "the sub mod's folder")
end

local function testNodeIsFoundByItsMod()
  local mods = installedCharacters()
  local tree = buildFolderTree(mods)

  assertEqual(tree:getNodeOfMod(mods[3]).key, "PPL/Gym Leaders/Misty", "misty's key")
end

local function rowKeys(rows)
  local keys = {}
  for _, row in ipairs(rows) do
    keys[#keys + 1] = row.node.key .. ":" .. row.depth .. (row.linkedFrom and ">" or "")
  end
  return table.concat(keys, ",")
end

local function testRowsListEveryFolderAndModWithItsDepth()
  local tree = buildFolderTree(installedCharacters())

  assertEqual(rowKeys(tree:getDisplayRows({})),
    "PPL:0,PPL/Ash:1,PPL/Gym Leaders:1,PPL/Gym Leaders/Brock:2,PPL/Gym Leaders/Misty:2,chocola:0,"
      .. "@builtin:0,@builtin/esme:1,@builtin/madamq:1",
    "the rows")
end

local function testCollapsedFolderHidesWhatIsInside()
  local tree = buildFolderTree(installedCharacters())

  assertEqual(rowKeys(tree:getDisplayRows({["PPL/Gym Leaders"] = true, ["@builtin"] = true})),
    "PPL:0,PPL/Ash:1,PPL/Gym Leaders:1,chocola:0,@builtin:0", "the rows")
end

local function testFolderCountsTheModsAtAnyDepthInside()
  local tree = buildFolderTree(installedCharacters())

  assertEqual(tree:countModsInsideEachFolder()[tree:getNodeByKey("PPL")], 3, "the mods in PPL")
end

local function testRowPositionIsAmongTheOrderedSiblings()
  local settings = ModSettings("unused")
  settings:setOrder("characters", "PPL/Gym Leaders", {"Misty"}, "shown")
  local tree = buildFolderTree(installedCharacters(), settings)

  local rows = tree:getDisplayRows({})
  local brock = rows[5]

  assertEqual(brock.node.key, "PPL/Gym Leaders/Brock", "the fifth row")
  assertEqual(tostring(brock.position) .. "/" .. tostring(brock.siblingCount), "2/2", "brock's position")
end

local function testStatusLimitIsTheFoldersEffectiveStatus()
  local settings = ModSettings("unused")
  settings:setStatus("characters", "PPL", "hidden")
  local tree = buildFolderTree(installedCharacters(), settings)

  assertEqual(tree:getHighestAllowedStatus(tree:getNodeByKey("PPL/Gym Leaders/Misty")), "hidden", "misty's limit")
  assertEqual(tree:getHighestAllowedStatus(tree:getNodeByKey("chocola")), "shown", "chocola's limit at the top level")
end

-- the installed characters with a bundle holding one of its sub mods and naming others installed elsewhere
local function charactersWithBundle()
  local mods = installedCharacters()
  local bundle = fakeMod("team", "characters/Bundles/Team")
  bundle.subIds = {"misty", "inside", "ash", "missing"}
  table.insert(mods, 1, bundle)
  table.insert(mods, 2, fakeMod("inside", "characters/Bundles/Team/Inside"))
  return mods
end

local function testBundleListsItsSubModsFromOtherFoldersAfterItsChildren()
  local tree = buildFolderTree(charactersWithBundle())

  local rows = tree:getDisplayRows({PPL = true, ["@builtin"] = true})

  assertEqual(rowKeys(rows),
    "Bundles:0,Bundles/Team:1,Bundles/Team/Inside:2,PPL/Gym Leaders/Misty:2>,PPL/Ash:2>,PPL:0,chocola:0,@builtin:0",
    "the rows")
  assertEqual(rows[4].linkedFrom, tree:getNodeByKey("Bundles/Team"), "the bundle misty is listed under")
end

local function testCollapsedBundleHidesItsSubMods()
  local tree = buildFolderTree(charactersWithBundle())

  assertEqual(rowKeys(tree:getDisplayRows({["Bundles/Team"] = true, PPL = true, ["@builtin"] = true})),
    "Bundles:0,Bundles/Team:1,PPL:0,chocola:0,@builtin:0", "the rows")
end

local function testLinkedNodesAreTheInstalledSubModsOutsideTheBundle()
  local tree = buildFolderTree(charactersWithBundle())

  local linkedKeys = {}
  for _, node in ipairs(tree:getSubModNodesOutsideFolder(tree:getNodeByKey("Bundles/Team"))) do
    linkedKeys[#linkedKeys + 1] = node.key
  end

  assertEqual(table.concat(linkedKeys, ","), "PPL/Gym Leaders/Misty,PPL/Ash", "the linked sub mods")
end

local function testRowCountsTheModsListedUnderIt()
  local tree = buildFolderTree(charactersWithBundle())

  local counts = {}
  for _, row in ipairs(tree:getDisplayRows({PPL = true, ["@builtin"] = true})) do
    counts[#counts + 1] = row.modCount
  end

  -- a folder does not count the sub mods listed under a bundle inside it, they are counted in their own folder
  assertEqual(table.concat(counts, ","), "2,3,0,0,0,3,0,2", "the mod counts")
end

testUserModKeyIsRelativeToTheSaveDirectory()
testBundledModKeyIsUnderBuiltin()
testDefaultPanelSetKeyIsUnderBuiltin()
testDefaultOrderIsTheOrderTheModsCameIn()
testModWithoutEntryShowsUnlessItsConfigHidesIt()
testFolderCapsWhatIsInside()
testLowerOwnStatusWinsOverItsFolder()
testFolderStatusCapsEveryDepth()
testChangesToTheSettingsApplyWithoutRebuilding()
testOrderListsNamedChildrenFirst()
testModMissingFromTheOrderGoesLast()
testOrderNamingMissingModsIsIgnored()
testModInsideAModFolderComesAfterIt()
testNodeIsFoundByItsMod()
testRowsListEveryFolderAndModWithItsDepth()
testCollapsedFolderHidesWhatIsInside()
testFolderCountsTheModsAtAnyDepthInside()
testRowPositionIsAmongTheOrderedSiblings()
testStatusLimitIsTheFoldersEffectiveStatus()
testBundleListsItsSubModsFromOtherFoldersAfterItsChildren()
testCollapsedBundleHidesItsSubMods()
testLinkedNodesAreTheInstalledSubModsOutsideTheBundle()
testRowCountsTheModsListedUnderIt()
