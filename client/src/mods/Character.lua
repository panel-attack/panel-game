--[[ for readability purposes this file is structured in 3 parts:
General character informating, loading and unloading
Graphics
Sound
]]--
local class = require("common.lib.class")
local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local consts = require("common.engine.consts")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local Music = require("client.src.music.Music")
local StageTrack = require("client.src.music.StageTrack")
local DynamicStageTrack = require("client.src.music.DynamicStageTrack")
local RelayStageTrack = require("client.src.music.RelayStageTrack")
local Mod = require("client.src.mods.Mod")
local FileGroup = require("client.src.FileGroup")
local SfxGroup = require("client.src.music.SfxGroup")

---@type Character
local default_character = nil -- holds default assets fallbacks
---@type Character
local randomCharacter = nil -- acts as the bundle character for all theme characters

---@enum ChainStyle
local chainStyle = {classic = 0, per_chain = 1}
---@enum ComboStyle
local comboStyle = {classic = 0, per_combo = 1}

---@class Character:Mod
---@field display_name string Name for display in selection menus
---@field stage string? Id of a stage for super select
---@field panels string? Id of a panel set for super select
---@field images table<string, love.Image> graphical assets of the character
---@field telegraph_garbage_images userdata[][] graphical assets for telegraph display
---@field sounds table<string, table<integer, SfxGroup> | SfxGroup> sound effect assets of the character
---@field musics table<string, love.Source> music assets of the character
---@field hasMusic boolean? if the character has any music
---@field flag string? flag to be displayed in selection menus
---@field chain_style ChainStyle defines a pattern in which SFX are used for chain events
---@field combo_style ComboStyle defines a pattern in which SFX are used for combo events
---@field popfx_style string defines a style in which attacks and pops are accompanied by select graphic assets
---@field popfx_burstRotate boolean configuration option for the PopFxStyle
---@field popfx_burstScale number scale factor for certain graphic assets displayed for the PopFxStyle
---@field popfx_fadeScale number scale factor for certain graphic assets displayed for the PopFxStyle
---@field music_style string defines the behaviour for music when switching between normal and danger
---@field music_volume number defines a multiplier to apply to the StageTrack
---@field sfx_volume number defines a multiplier to apply to the character's SFX
---@field stageTrack StageTrack? the StageTrack constructed from the character's music assets
---@field files string[] array of files in the mod's directory

---@class Character
---@overload fun(full_path: string, folder_name: string): Character
local Character = class(
---@param self Character
function(self, full_path, folder_name)
  self.path = full_path
  self.id = folder_name
  self.display_name = self.id
  self.stage = nil
  self.panels = nil
  self.images = {}
  self.sounds = {}
  self.musics = {}
  self.flag = nil
  self.chain_style = chainStyle.classic
  self.combo_style = comboStyle.classic
  self.popfx_style = "burst"
  self.popfx_burstRotate = false
  self.popfx_burstScale = 1
  self.popfx_fadeScale = 1
  self.music_style = "normal"
  self.music_volume = 1
  self.sfx_volume = 1
  self.stageTrack = nil
  self.files = tableUtils.map(love.filesystem.getDirectoryItems(self.path), function(file) return fileUtils.getFileNameWithoutExtension(file) end)
end,
Mod
)

Character.TYPE = "character"
-- name of the top level save directory for mods of this type
Character.SAVE_DIR = "characters"

function Character.json_init(self)
  local read_data = fileUtils.readJsonFile(self.path .. "/config.json")

  if read_data then
    if read_data.id and type(read_data.id) == "string" then
      self.id = read_data.id

      -- sub ids for bundles
      if read_data.sub_ids and type(read_data.sub_ids) == "table" then
        self.subIds = read_data.sub_ids
      end
      -- display name
      if read_data.name and type(read_data.name) == "string" then
        self.display_name = read_data.name
      end
      -- is visible
      if read_data.visible ~= nil and type(read_data.visible) == "boolean" then
        self.isVisible = read_data.visible
      elseif read_data.visible and type(read_data.visible) == "string" then
        self.isVisible = read_data.visible == "true"
      end

      -- chain_style
      if read_data.chain_style and type(read_data.chain_style) == "string" then
        self.chain_style = read_data.chain_style == "per_chain" and chainStyle.per_chain or chainStyle.classic
      end

      -- combo_style
      if read_data.combo_style and type(read_data.combo_style) == "string" then
        self.combo_style = read_data.combo_style == "per_combo" and comboStyle.per_combo or comboStyle.classic
      end

      --popfx_burstRotate
      if read_data.popfx_burstRotate and type(read_data.popfx_burstRotate) == "boolean" then
        self.popfx_burstRotate = read_data.popfx_burstRotate
      end

      --popfx_type
      if read_data.popfx_style and type(read_data.popfx_style) == "string" then
        self.popfx_style = read_data.popfx_style
      end

      --popfx_burstScale
      if read_data.popfx_burstScale and type(read_data.popfx_burstScale) == "number" then
        self.popfx_burstScale = read_data.popfx_burstScale
      end

      --popfx_fadeScale
      if read_data.popfx_fadeScale and type(read_data.popfx_fadeScale) == "number" then
        self.popfx_fadeScale = read_data.popfx_fadeScale
      end

      --music style
      if read_data.music_style and type(read_data.music_style) == "string" then
        self.music_style = read_data.music_style
      end

      if read_data.music_volume and type(read_data.music_volume) == "number" then
        self.music_volume = read_data.music_volume
      end

      if read_data.sfx_volume and type(read_data.sfx_volume) == "number" then
        self.sfx_volume = read_data.sfx_volume
      end

      -- associated stage
      if read_data.stage and type(read_data.stage) == "string" and stages[read_data.stage] and not stages[read_data.stage]:isBundle() then
        self.stage = read_data.stage
      end
      -- associated panel
      if read_data.panels and type(read_data.panels) == "string" and panels[read_data.panels] then
        self.panels = read_data.panels
      end

      -- flag
      if read_data.flag and type(read_data.flag) == "string" then
        self.flag = read_data.flag
      end

      return true
    end
  end

  return false
end

function Character.preload(self)
  logger.trace("preloading character " .. self.id)
  self:graphics_init(false, false)
  self:sound_init(false, false)
end

-- Loads all the sounds and graphics
function Character.load(self, instant)
  self:graphics_init(true, (not instant))
  self:sound_init(true, (not instant))
  self.fullyLoaded = true
  logger.debug("loaded character " .. self.id)
end

-- Unloads the sounds and graphics
function Character.unload(self)
  logger.debug("unloading character " .. self.id)
  self:graphics_uninit()
  self:sound_uninit()
  self.fullyLoaded = false
  logger.debug("unloaded character " .. self.id)
end

function Character.loadDefaultMod()
  default_character = Character("client/assets/characters/__default", "__default")
  default_character:preload()
  default_character:load(true)
end

local function loadRandomCharacter(visibleCharacters)
  local randomCharacter = Character("characters/__default", consts.RANDOM_CHARACTER_SPECIAL_VALUE)
  randomCharacter.images["icon"] = themes[config.theme].images.IMG_random_character
  randomCharacter.display_name = "random"
  randomCharacter.subIds = visibleCharacters
  -- we need to shadow some character functions to correct load behaviour for the random character
  randomCharacter.preload = function() end
  randomCharacter.load = function() end
  randomCharacter.unload = function() end
  randomCharacter.graphics_init = function(character, full, yields)
    character.images.icon = themes[config.theme].images.IMG_random_character
  end
  return randomCharacter
end

function Character.getRandom(visibleCharacters)
  if not randomCharacter then
    randomCharacter = loadRandomCharacter(visibleCharacters)
  elseif visibleCharacters then
    randomCharacter.subIds = visibleCharacters
  end

  return randomCharacter
end

function Character:getSubMods()
  local m = {}
  for _, id in ipairs(self.subIds) do
    if characters[id] then
      m[#m + 1] = characters[id]
    end
  end
  return m
end

function Character:enable(enable)
  if enable and not characters[self.id] then
    characters[self.id] = self
    visibleCharacters[#visibleCharacters+1] = self.id
  elseif not enable and characters[self.id] then
    local i = tableUtils.indexOf(visibleCharacters, self.id)
    table.remove(visibleCharacters, i)
    characters[self.id] = nil
  end

  require("client.src.mods.ModLoader").updateBlacklist(self, enable)
end

function Character:canSuperSelect()
  return (self.panels and panels[self.panels]) or (self.stage and stages[self.stage])
end


-- GRAPHICS

local basic_images = {"icon"}
local all_images = {
  "icon",
  "topleft",
  "botleft",
  "topright",
  "botright",
  "top",
  "bot",
  "left",
  "right",
  "face",
  "face2",
  "pop",
  "doubleface",
  "filler1",
  "filler2",
  "flash",
  "portrait",
  "portrait2",
  "burst",
  "fade"
}
local defaulted_images = {
  icon = true,
  topleft = true,
  botleft = true,
  topright = true,
  botright = true,
  top = true,
  bot = true,
  left = true,
  right = true,
  face = true,
  -- used for garbage blocks of odd-numbered widths if available, face otherwise
  face2 = false,
  pop = true,
  doubleface = true,
  filler1 = true,
  filler2 = true,
  flash = true,
  portrait = true,
  portrait2 = false,
  burst = true,
  fade = true
} -- those images will be defaulted if missing

-- for reloading the graphics if the window was resized
function characters_reload_graphics()
  if visibleCharacters then
    local characterIds = shallowcpy(visibleCharacters)
    for i = 1, #characterIds do
      local character = characterIds[i]
      local fullLoad = false
      if character == config.character or GAME.battleRoom and GAME.battleRoom.match and ((GAME.battleRoom.match.stacks[1] and character == GAME.battleRoom.match.stacks[1].character) or (GAME.battleRoom.match.stacks[2] and character == GAME.battleRoom.match.stacks[2].character)) then
        fullLoad = true
      end
      characters[character]:graphics_init(fullLoad, false)
    end
    require("client.src.mods.CharacterLoader").loadBundleIcons()
  end
end

function Character.graphics_init(self, full, yields)
  local character_images = full and all_images or basic_images
  for _, image_name in ipairs(character_images) do
    self.images[image_name] = GraphicsUtil.loadImageFromSupportedExtensions(self.path .. "/" .. image_name)
    if not self.images[image_name] and defaulted_images[image_name] and not self:isBundle() then
      self.images[image_name] = default_character.images[image_name]
      if not self.images[image_name] then
        error("Could not find default character image")
      end
    end
    if yields then
      coroutine.yield()
    end
  end
  if full then
    self.telegraph_garbage_images = {}
    for garbage_h=1,14 do
      self.telegraph_garbage_images[garbage_h] = {}
      logger.trace("telegraph/"..garbage_h.."-tall")
      self.telegraph_garbage_images[garbage_h][6] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/"..garbage_h.."-tall")
      if not self.telegraph_garbage_images[garbage_h][6] and default_character.telegraph_garbage_images[garbage_h][6] then
        self.telegraph_garbage_images[garbage_h][6] = default_character.telegraph_garbage_images[garbage_h][6]
        logger.trace("DEFAULT used for telegraph/"..garbage_h.."-tall")
      elseif not self.telegraph_garbage_images[garbage_h][6] then
        logger.info("FAILED TO LOAD: telegraph/"..garbage_h.."-tall")
      end
    end
    for garbage_w=1,6 do
      logger.trace("telegraph/"..garbage_w.."-wide")
      self.telegraph_garbage_images[1][garbage_w] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/"..garbage_w.."-wide")
      if not self.telegraph_garbage_images[1][garbage_w] and default_character.telegraph_garbage_images[1][garbage_w] then
        self.telegraph_garbage_images[1][garbage_w] = default_character.telegraph_garbage_images[1][garbage_w]
        logger.trace("DEFAULT used for telegraph/"..garbage_w.."-wide")
      elseif not self.telegraph_garbage_images[1][garbage_w] then
        logger.info("FAILED TO LOAD: telegraph/"..garbage_w.."-wide")
      end
    end
    logger.trace("telegraph/6-wide-metal")
    self.telegraph_garbage_images["metal"] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/6-wide-metal")
    if not self.telegraph_garbage_images["metal"] and default_character.telegraph_garbage_images["metal"] then
      self.telegraph_garbage_images["metal"] = default_character.telegraph_garbage_images["metal"]
      logger.trace("DEFAULT used for telegraph/6-wide-metal")
    elseif not self.telegraph_garbage_images["metal"] then
      logger.info("FAILED TO LOAD: telegraph/6-wide-metal")
    end
    logger.trace("telegraph/attack")
    self.telegraph_garbage_images["attack"] = GraphicsUtil.loadImageFromSupportedExtensions(self.path.."/telegraph/attack")
    if not self.telegraph_garbage_images["attack"] and default_character.telegraph_garbage_images["attack"] then
      self.telegraph_garbage_images["attack"] = default_character.telegraph_garbage_images["attack"]
      logger.trace("DEFAULT used for telegraph/attack")
    elseif not self.telegraph_garbage_images["attack"] then
      logger.info("FAILED TO LOAD: telegraph/attack")
    end
  end
end

-- bundles without stage icon display up to 4 icons of their substages
function Character:createBundleIcon()
  local canvas = love.graphics.newCanvas(2 * 168, 2 * 168)
  canvas:renderTo(function()
    for i, subCharacterId in ipairs(self.subIds) do
      -- only draw up to 4 and only draw sub mods that are actually there unless there are none
      if i <= 4 and (characters[subCharacterId] or (allCharacters[subCharacterId] and #self:getSubMods() == 0)) then
        local character = allCharacters[subCharacterId]
        local x = 0
        local y = 0
        if i % 2 == 0 then
          x = 168
        end
        if i > 2 then
          y = 168
        end
        local width, height = character.images.icon:getDimensions()
        love.graphics.draw(character.images.icon, x, y, 0, 168 / width, 168 / height)
      end
    end
  end)
  return canvas
end

function Character.graphics_uninit(self)
  for imageName, _ in pairs(self.images) do
    if not tableUtils.contains(basic_images, imageName) then
      self.images[imageName] = nil
    end
  end
  self.telegraph_garbage_images = {}
end



-- SOUND

local basic_sfx = {"selection"}
local other_sfx = {
  "chain",
  "combo",
  -- legacy +6/+7 shock, to be used if shock is not present
  "combo_echo",
  "shock",
  -- for classic style chains
  "chain_echo",
  "chain2_echo",

  "garbage_match",
  "garbage_land",
  "win",
  "taunt_up",
  "taunt_down"}
local basic_musics = {}
local other_musics = {"normal_music", "danger_music", "normal_music_start", "danger_music_start"}

function Character.sound_init(self, full, yields)
  -- SFX
  local character_sfx = full and other_sfx or basic_sfx
  for _, sfx in ipairs(character_sfx) do
    self.sounds[sfx] = self:loadSfx(sfx)
    if self.sounds[sfx] then
      if yields then
        coroutine.yield()
      end
    end
  end

  if full then
    self:reassignLegacySfx()
  end

  -- music

  self.hasMusic = fileUtils.soundFileExists("normal_music", self.path)
  local character_musics = full and other_musics or basic_musics
  for _, music in ipairs(character_musics) do
    self.musics[music] = fileUtils.loadSoundFromSupportExtensions(self.path .. "/" .. music, true)
    -- Set looping status for music.
    -- Intros won't loop, but other parts should.
    if self.musics[music] then
      if not string.find(music, "start") then
        self.musics[music]:setLooping(true)
      else
        self.musics[music]:setLooping(false)
      end
    end

    if yields then
      coroutine.yield()
    end
  end

  self:applyConfigVolume()

  if full and self.musics.normal_music then
    local normalMusic = Music(self.musics.normal_music, self.musics.normal_music_start)
    local dangerMusic
    if self.musics.danger_music then
      dangerMusic = Music(self.musics.danger_music, self.musics.danger_music_start)
    end
    if self.music_style == "normal" then
      self.stageTrack = StageTrack(normalMusic, dangerMusic, self.music_volume)
    elseif self.music_style == "dynamic" then
      if dangerMusic then
        self.stageTrack = DynamicStageTrack(normalMusic, dangerMusic, self.music_volume)
      else
        -- DynamicStageTrack HAVE to have danger music
        -- default back to a regular stage track if there is none
        self.stageTrack = StageTrack(normalMusic, nil, self.music_volume)
      end
    elseif self.music_style == "relay" then
      self.stageTrack = RelayStageTrack(normalMusic, dangerMusic, self.music_volume)
    end
  end
end

function Character.sound_uninit(self)
  -- SFX
  for _, sound in ipairs(other_sfx) do
    self.sounds[sound] = nil
  end

  -- music
  for _, music in ipairs(other_musics) do
    self.musics[music] = nil
  end
end

function Character:validate()
  -- validate that the mod has both normal and danger music if it is dynamic
  -- do this on initialization so modders get a crash on load and know immediately what to fix
  if self.music_style == "dynamic" then
    if not fileUtils.soundFileExists("normal_music", self.path) or fileUtils.soundFileExists("danger_music", self.path) then
      local err = "Error loading character " .. self.id .. "\n at "
                     .. self.path ..
                  ":\n Characters with dynamic music must have a normal_music and danger_music file"
      return false, err
    end
  end

  return true
end

--- Stack number 1 equals left side, 2 is right side
function Character:portraitImage(stackNumber)
  local portraitImageName = self:portraitName(stackNumber)
  return self.images[portraitImageName]
end

function Character:portraitName(stackNumber)
  local portrait_image = "portrait"
  if stackNumber == 2 and self:portraitIsReversed(stackNumber) == false then
    portrait_image = "portrait2"
  end
  return portrait_image
end

function Character:portraitIsReversed(stackNumber)
  if stackNumber == 2 and self.images["portrait2"] == nil then
    return true
  end
  return false
end

function Character:drawPortrait(stackNumber, x, y, fade, scale)
  local portraitImage = self:portraitImage(stackNumber)
  local portraitImageWidth, portraitImageHeight = portraitImage:getDimensions()

  local portraitImageX = x
  local portraitMirror = 1
  local portraitWidth = 96
  local portraitHeight = 192
  if self:portraitIsReversed(stackNumber) then
    portraitImageX = portraitImageX + portraitWidth
    portraitMirror = -1
  end
  GraphicsUtil.draw(portraitImage, portraitImageX * scale, y * scale, 0, (portraitWidth / portraitImageWidth) * portraitMirror * scale, portraitHeight / portraitImageHeight * scale)
  if fade > 0 then
    GraphicsUtil.drawRectangle("fill", x * scale, y * scale, portraitWidth * scale, portraitHeight * scale, 0, 0, 0, fade)
  end
end

function Character.reassignLegacySfx(self)
  if self.chain_style == chainStyle.classic then
    local maxIndex = -1
    for i = #self.sounds.chain, 0, -1 do
      if i == 2 and self.sounds.chain[i] then
        self.sounds.chain[4] = self.sounds.chain[2]
        maxIndex = i
      elseif i == 1 and self.sounds.chain[i] then
        self.sounds.chain[2] = self.sounds.chain[1]
        maxIndex = math.max(i, maxIndex)
      else
        self.sounds.chain[i] = nil
      end
    end
    if self.sounds.chain2_echo then
      self.sounds.chain[6] = self.sounds.chain2_echo
      -- shouldn't show up in sound test any longer
      self.sounds.chain2_echo = nil
      maxIndex = 6
    end
    if self.sounds.chain_echo then
      self.sounds.chain[5] = self.sounds.chain_echo
      -- shouldn't show up in sound test any longer
      self.sounds.chain_echo = nil
      maxIndex = math.max(5, maxIndex)
    end
    
    self:fillInMissingSounds(self.sounds.chain, "chain", maxIndex)
  end

  if #self.sounds.shock > 0 then
    -- combo_echo won't get used if shock is present, so it shouldn't show up in sound test any longer
    self.sounds.combo_echo = nil
  end
end

--[[
Explanation for sound loading process

Standard expected structure for sound files is as follows:
self.sounds holds a dictionary with the keys in basic_sfx and other_sfx
The values of that dictionary are SfxGroups that implement a subset of love.Source to interop with SoundController.
self.sounds["win"] = SfxGroup
For some sfx types, sfx can possibly contain sub sfx.
To reflect that mechanic instead of an SfxGroup these sfx types will contain an array of SfxGroups
self.sounds["combo"] = { nil, nil, SfxGroup, SfxGroup, SfxGroup}
The level of sound loading is determined via the presence of the key in "perSizeSfxStart"
]]--

local perSizeSfxStart = { chain = 2, combo = 4, shock = 3}

---@param name string
---@return SfxGroup | table<integer, SfxGroup> | nil
function Character:loadSfx(name)
  if not perSizeSfxStart[name] then
    local fileGroup = FileGroup(self.path, name, fileUtils.SUPPORTED_SOUND_FORMATS)
    if next(fileGroup.matchingFiles) then
      return SfxGroup(fileGroup, self.sfx_volume)
    else
      return nil
    end
  else
    local sfx = {}
    local stringLen = string.len(name)
    local files = tableUtils.filter(self.files, function(file) return string.find(file, name, nil, true) end)

    local maxIndex = -1
    -- load sounds
    for i = 1, #files do
      stringLen = string.len(name)
      local index = tonumber(string.match(files[i], "%d+", stringLen + 1))

      -- for files with no suffix at all, index would be nil but they should go in sfx[1] instead
      local targetIndex = 1
      if index ~= nil then
        -- otherwise use the index as normal
        targetIndex = index
      end


      if sfx[targetIndex] == nil then
        local searchName = name
        if index then
          searchName = searchName .. index
        end
        local fileGroup = FileGroup(self.path, searchName, fileUtils.SUPPORTED_SOUND_FORMATS, "_")
        if next(fileGroup.matchingFiles) then
          sfx[targetIndex] = SfxGroup(fileGroup, self.sfx_volume)
        end
      end

      if sfx[targetIndex] then
        maxIndex = math.max(maxIndex, targetIndex)
      end
    end

    self:fillInMissingSounds(sfx, name, maxIndex)
    return sfx
  end
end

function Character.fillInMissingSounds(self, sfxTable,  name, maxIndex)
  local fillUpSound = nil
  if maxIndex > 0 then
    -- fallback sound for combos/chains higher than the highest available file is the file with the maximum index
    -- unless set differently (such as for chains via the chain0 file)
    sfxTable[0] = sfxTable[maxIndex]
  end
  -- fill up missing indexes up to the highest recorded one
  for i = 0, maxIndex do
    if sfxTable and sfxTable[i] then
      fillUpSound = sfxTable[i]
    else
      if i >= perSizeSfxStart[name] then
        sfxTable[i] = fillUpSound
      else
        -- leave it empty
        sfxTable[i] = nil
      end
    end
  end

  if sfxTable[0] == nil then
    if default_character.sounds[name] and default_character.sounds[name][0] then
      sfxTable[0] = default_character.sounds[name][0]
    end
  else
    -- shock falls back to combo if nil
    -- combo falls back to chain if nil
    -- chain is bundled with the default character and should never be nil
  end
end

-- sound playing / sound control

function Character.playSelectionSfx(self)
  if self.sounds.selection then
    self.sounds.selection:play()
  else
    GAME.theme:playValidationSfx()
  end
end

function Character.playComboSfx(self, size)
  -- self.sounds.combo[0] is the fallback combo sound which is guaranteed to be set if there is a combo sfx
  if self.sounds.combo[0] == nil then
    -- no combos loaded, try to fallback to the fallback chain sound
    if self.sounds.chain[0] == nil then
      -- technically we should always have a default chain sound from the default_character
      -- so if this error ever occurs, something is seriously cursed
      error("Found neither chain nor combo sfx upon trying to play combo sfx")
    else
      self.sounds.chain[0]:play()
    end
  else
    -- combo sfx available!
    if self.combo_style == comboStyle.classic then
      -- roll among all combos in case a per_combo style character had its combostyle changed to classic
      local rolledIndex = math.random(#self.sounds.combo)
      self.sounds.combo[rolledIndex]:play()
    else
      -- use fallback sound if the combo size is higher than the highest combo sfx
      -- an alternative scenario is if in per_combo style the shock sfx redirects here for a 3 shock match
      if self.sounds.combo[size] then
        self.sounds.combo[size]:play()
      else
        self.sounds.combo[0]:play()
      end
    end
  end
end

function Character.playChainSfx(self, length)
  -- chain[0] always exists by virtue of the default character SFX
  if self.sounds.chain[length] then
    self.sounds.chain[length]:play()
  else
    self.sounds.chain[0]:play()
  end
end

function Character.playShockSfx(self, size)
  if #self.sounds.shock > 0 then
    if self.sounds.shock[size] then
      self.sounds.shock[size]:play()
    else
      self.sounds.shock[0]:play()
    end
  else
    if size >= 6 and self.sounds.combo_echo then
      self.sounds.combo_echo:play()
    else
      self:playComboSfx(size)
    end
  end
end

-- Stops old combo / chain sounds and plays the appropriate chain or combo sound
function Character.playAttackSfx(self, attack)
  -- stop previous attack sounds if any
  local function stopAttackSounds()
    for _, v in pairs(self.sounds.combo) do
      SoundController:stopSfx(v)
    end

    if tableUtils.length(self.sounds.shock) > 0 then
      for _, v in pairs(self.sounds.shock) do
        SoundController:stopSfx(v)
      end
    elseif self.sounds.combo_echo then
      SoundController:stopSfx(self.sounds.combo_echo)
    end

    for _, v in pairs(self.sounds.chain) do
      SoundController:stopSfx(v)
    end
  end

  if self.sounds.chain then
    stopAttackSounds()

    -- play combos or chains
    if attack.type == consts.ATTACK_TYPE.combo then
      self:playComboSfx(attack.size)
    elseif attack.type == consts.ATTACK_TYPE.shock then
      self:playShockSfx(attack.size)
    else --elseif chain_combo.type == consts.ATTACK_TYPE.chain then
      self:playChainSfx(attack.size)
    end
  end
end

function Character.playGarbageMatchSfx(self)
  if self.sounds.garbage_match then
    self.sounds.garbage_match:play()
  end
end

function Character.playGarbageLandSfx(self)
  if self.sounds.garbage_land then
    self.sounds.garbage_land:play()
  end
end

-- tauntUp is rolled externally in order to send the exact same taunt index to the enemy as plays locally
function Character.playTauntUpSfx(self, tauntUp)
  if self.sounds.taunt_up then
    self.sounds.taunt_up:play()
  end
end

function Character.playTauntDownSfx(self, tauntDown)
  if self.sounds.taunt_down then
    self.sounds.taunt_down:play()
  end
end

function Character.playTaunt(self, tauntType, index)
  -- find instead of equals for forward compatibility
  if string.find(tauntType, "up", nil, true) then
    self:playTauntUpSfx(index)
  elseif string.find(tauntType, "down", nil, true) then
    self:playTauntDownSfx(index)
  end
end

function Character:playWinSfx()
  if self.sounds.win then
    self.sounds.win:play()
  else
    themes[config.theme].sounds.fanfare1:play()
  end
end

function Character.applyConfigVolume(self)
  SoundController:applySfxVolume(self.sounds)
  SoundController:applyMusicVolume(self.musics)
end

return Character