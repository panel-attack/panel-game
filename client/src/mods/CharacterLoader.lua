local Character = require("client.src.mods.Character")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local ModLoader = require("client.src.mods.ModLoader")

local CharacterLoader = {}

-- (re)Initializes the characters globals with data
function CharacterLoader.initCharacters()
  allCharacters, characterIds, characters, visibleCharacters = ModLoader.initMods(Character)

  CharacterLoader.loadBundleIcons()
end

function CharacterLoader.loadBundleIcons()
  -- bundles without character icon display up to 4 icons of their subcharacters
  -- there is no guarantee the subcharacters had been loaded previously so do it after everything got preloaded
  for _, character in pairs(allCharacters) do
    if not character.images.icon then
      if character:isBundle() then
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
    characterId = tableUtils.getRandomElement(visibleCharacters)
  end

  return characterId
end

function CharacterLoader.resolveBundle(characterId)
  while characters[characterId]:isBundle() do
    local subMods = characters[characterId]:getSubMods()
    characterId = tableUtils.getRandomElement(subMods).id
  end

  return characterId
end

function CharacterLoader.fullyResolveCharacterSelection(characterId)
  characterId = CharacterLoader.resolveCharacterSelection(characterId)
  return CharacterLoader.resolveBundle(characterId)
end

return CharacterLoader