local Character = require("client.src.mods.Character")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local consts = require("common.engine.consts")
local ModLoader = require("client.src.mods.ModLoader")

local CharacterLoader = {}

---(re)Initializes the characters globals with data
---@return nil
function CharacterLoader.initCharacters()
  local all, ids, filtered, visible = ModLoader.initMods(Character)
  ---@type table<string, Character>
  ---@diagnostic disable-next-line: assign-type-mismatch
  allCharacters = all
  ---@type string[]
  characterIds = ids
  ---@type table<string, Character>
  ---@diagnostic disable-next-line: assign-type-mismatch
  characters = filtered
  ---@type string[]
  visibleCharacters = visible

  CharacterLoader.loadBundleIcons()
end

---Ensures all characters have an icon, generating bundle icons when required
---@return nil
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

---Resolves a requested character selection, falling back to a random visible character
---@param characterId string|nil
---@return string
function CharacterLoader.resolveCharacterSelection(characterId)
  if not characterId or not characters[characterId] then
    -- resolve via random selection
    characterId = tableUtils.getRandomElement(visibleCharacters)
  end

  return characterId
end

---Resolves bundle selections until a concrete character is chosen
---@param characterId string
---@return string
function CharacterLoader.resolveBundle(characterId)
  while characters[characterId]:isBundle() do
    local subMods = characters[characterId]:getSubMods()
    characterId = tableUtils.getRandomElement(subMods).id
  end

  return characterId
end

---Fully resolves a potentially missing or bundled character selection
---@param characterId string|nil
---@return string
function CharacterLoader.fullyResolveCharacterSelection(characterId)
  characterId = CharacterLoader.resolveCharacterSelection(characterId)
  return CharacterLoader.resolveBundle(characterId)
end

return CharacterLoader
