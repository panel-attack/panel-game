local Character = require("client.src.mods.Character")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")

local CharacterLoader = {}

-- Adds all the characters recursively in a folder to the characters table
function CharacterLoader.addCharactersFromDirectoryRecursively(path, characters)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for _, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      CharacterLoader.addCharactersFromDirectoryRecursively(current_path, characters)

      -- init stage: 'real' folder
      local character = Character(current_path, v)
      local success = character:json_init()

      if success then
        if characters[character.id] ~= nil then
          logger.trace(current_path .. " has been ignored since a character with this id has already been found")
        else
          -- logger.trace(current_path.." has been added to the character list!")
          characters[character.id] = character
        end
      end
    end
  end
end

-- Iterates through the characters table and adds the ids of all valid mods to a new characterIds table
-- returns: 
--   characterIds table
--   table of invalid character bundles
function CharacterLoader.fillCharacterIds(characters)
  local invalid = {}
  local characterIds = {}

  for characterId, character in pairs(characters) do
    -- bundle character (needs to be filtered if invalid)
    if character:is_bundle() then
      if CharacterLoader.validateBundle(character) then
        characterIds[#characterIds + 1] = characterId
        logger.debug(character.id .. " (bundle) has been added to the character list!")
      else
        invalid[#invalid + 1] = characterId -- character is invalid
        logger.warn(character.id .. " (bundle) is being ignored since it's invalid!")
      end
    else
      -- normal character
      characterIds[#characterIds + 1] = characterId
      logger.debug(character.id .. " has been added to the character list!")
    end
  end

  -- for consistency while manual sorting is not possible
  table.sort(characterIds, function(a, b)
    return characters[a].path < characters[b].path
  end)

  return characterIds, invalid
end

function CharacterLoader.validateBundle(character)
  for i = #character.sub_characters, 1, -1 do
    local subCharacter = allCharacters[character.sub_characters[i]]
    if subCharacter and #subCharacter.sub_characters == 0 then -- inner bundles are prohibited
      logger.trace(character.id .. " has " .. subCharacter.id .. " as part of its subcharacters.")
    else
      logger.warn(character.sub_characters[i] .. " is not a valid sub character of " .. character.id .. " because it does not  exist or has own sub characters.")
      table.remove(character.sub_characters, i)
    end
  end

  return #character.sub_characters >= 2
end

-- all characters are default enabled until they're actively disabled upon which they are added to this blacklist
function CharacterLoader.loadBlacklist()
  local blacklist = {}
  if love.filesystem.getInfo("characters/blacklist.txt", "file") then
    for line in love.filesystem.lines("characters/blacklist.txt") do
      blacklist[#blacklist+1] = line
    end
  end
  return blacklist
end

function CharacterLoader.enable(character, enable)
  if enable and not characters[character.id] then
    local i = tableUtils.indexOf(CharacterLoader.blacklist, character.id)
    table.remove(CharacterLoader.blacklist, i)
    characters[character.id] = character
    characters_ids_for_current_theme[#characters_ids_for_current_theme+1] = character.id
  elseif not enable and characters[character.id] then
    local i = tableUtils.indexOf(characters_ids_for_current_theme, character.id)
    table.remove(characters_ids_for_current_theme, i)
    CharacterLoader.blacklist[#CharacterLoader.blacklist+1] = character.id
    characters[character.id] = nil
  end
  love.filesystem.write("characters/blacklist.txt", table.concat(CharacterLoader.blacklist, "\n"))
end

-- (re)Initializes the characters globals with data
function CharacterLoader.initCharacters()
  allCharacters = {}
  characters_ids_for_current_theme = {} -- holds characters ids for the current theme, those characters will appear in the lobby

  -- load bundled assets first so they are not ignored in favor of user mods
  CharacterLoader.addCharactersFromDirectoryRecursively("client/assets/default_data/characters", allCharacters)
  -- load user mods
  CharacterLoader.addCharactersFromDirectoryRecursively("characters", allCharacters)
  -- holds all characters ids
  characterIds = CharacterLoader.fillCharacterIds(allCharacters)
  characters = shallowcpy(allCharacters)
  CharacterLoader.blacklist = CharacterLoader.loadBlacklist()
  for i, characterId in ipairs(CharacterLoader.blacklist) do
    -- blacklisted characters are removed from characters
    -- but we keep them in allCharacters/characterIds for reference
    characters[characterId] = nil
  end

  if tableUtils.length(characters) == 0 then
    -- fallback for configurations in which all characters have been disabled
    characters = shallowcpy(allCharacters)
  end

  if love.filesystem.getInfo(themes[config.theme].path .. "/characters.txt") then
    for line in love.filesystem.lines(themes[config.theme].path .. "/characters.txt") do
      line = trim(line) -- remove whitespace
      if characters[line] then
        -- found at least a valid character in a characters.txt file
        characters_ids_for_current_theme[#characters_ids_for_current_theme + 1] = line
      end
    end
  else
    for _, character_id in ipairs(characterIds) do
      if characters[character_id] and characters[character_id].is_visible then
        characters_ids_for_current_theme[#characters_ids_for_current_theme + 1] = character_id
      end
    end
  end

  if #characters_ids_for_current_theme == 0 then
    -- fallback in case there were no characters left
    characters_ids_for_current_theme = shallowcpy(characterIds)
  end

  -- fix config character if it's missing
  if not config.character or (config.character ~= consts.RANDOM_CHARACTER_SPECIAL_VALUE and not characters[config.character]) then
    config.character = tableUtils.getRandomElement(characters_ids_for_current_theme)
  end

  -- actual init for all characters, starting with the default one
  Character.loadDefaultCharacter()
  -- add the random character as a character that acts as a bundle for all theme characters
  local randomCharacter = Character.getRandomCharacter()
  characterIds[#characterIds + 1] = randomCharacter.id
  characters[randomCharacter.id] = randomCharacter

  for _, character in pairs(allCharacters) do
    character:preload()
  end

  CharacterLoader.loadBundleIcons()
end

function CharacterLoader.loadBundleIcons()
  -- bundles without character icon display up to 4 icons of their subcharacters
  -- there is no guarantee the subcharacters had been loaded previously so do it after everything got preloaded
  for _, character in pairs(allCharacters) do
    if not character.images.icon then
      if character:is_bundle() then
        character.images.icon = character:createBundleIcon()
      else
        error("Can't find a icon for character " .. character.id)
      end
    end
  end
end

function CharacterLoader.resolveCharacterSelection(characterId)
  if not characterId or not characters[characterId] then
    -- resolve via random selection
    characterId = tableUtils.getRandomElement(characters_ids_for_current_theme)
  end

  return characterId
end

function CharacterLoader.resolveBundle(characterId)
  while characters[characterId]:is_bundle() do
    characterId = tableUtils.getRandomElement(characters[characterId].sub_characters)
  end

  return characterId
end

function CharacterLoader.fullyResolveCharacterSelection(characterId)
  characterId = CharacterLoader.resolveCharacterSelection(characterId)
  return CharacterLoader.resolveBundle(characterId)
end

return CharacterLoader