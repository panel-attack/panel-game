local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local tableUtils = require("common.lib.tableUtils")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")

-- Scene for the sound test
local SoundTest = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

SoundTest.name = "SoundTest"

local BUTTON_WIDTH = 70
local BUTTON_HEIGHT = 25

local menuValidateSound

local function playMusic(source, id, musicType)
  local musicSource
  if source == "character" then
    if not characters[id].fullyLoaded and not characters[id].musics[musicType] then
      characters[id]:sound_init(true, false)
    end
    musicSource = characters[id]
  elseif source == "stage" then
    if not stages[id].fullyLoaded and not stages[id].musics[musicType] then
      stages[id]:sound_init(true, false)
    end
    musicSource = stages[id]
  end

  if musicSource.stageTrack then
    musicSource.stageTrack:changeMusic(musicType == "danger_music")
    SoundController:playMusic(musicSource.stageTrack)
  else
    SoundController:stopMusic()
  end
end

local function createSfxMenuInfo(characterId)
  local characterFiles = love.filesystem.getDirectoryItems(characters[characterId].path)
  local musicFiles = {normal_music = true, normal_music_start = true, danger_music = true, danger_music_start = true}
  local supportedSoundFormats = {mp3 = true, ogg = true, wav = true, it = true, flac = true}
  local soundFiles = tableUtils.filter(characterFiles, function(fileName) return not musicFiles[string.match(fileName, "(.*)[.]")] and supportedSoundFormats[string.match(fileName, "[.](.*)")] end)
  local sfxLabels = {}
  local sfxValues = {}
  for _, sfx in ipairs(soundFiles) do
    sfxLabels[#sfxLabels + 1] = ui.Label({
        text = string.match(sfx, "(.*)[.]"),
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT,
        isVisible = false})
    sfxValues[#sfxValues + 1] = sfx
  end
  return sfxLabels, sfxValues
end

function SoundTest:load()
  local characterLabels = {}
  local characterIds = {}
  for _, character in pairs(characters) do
    characterLabels[#characterLabels + 1] = ui.Label({
        text = character.display_name,
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT})
    characterIds[#characterIds + 1] = character.id
  end
  
  local playButtonGroup
  local musicTypeButtonGroup
  local sfxStepper
  local characterStepper = ui.Stepper(
    {
      labels = characterLabels,
      values = characterIds,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()

        local labels, values = createSfxMenuInfo(value)
        sfxStepper:setLabels(labels, values, 1)
        
        -- redraw sfx stepper
        self.soundTestMenu:removeMenuItemAtIndex(5);
        self.soundTestMenu:addMenuItem(5, ui.MenuItem.createStepperMenuItem("op_music_sfx", nil, nil, sfxStepper))

        if playButtonGroup.value == "character" then
          playMusic("character", value, musicTypeButtonGroup.value)
        end
      end
    }
  )
  
  
  local stageLabels = {}
  local stageIds = {}
  for _, stage in pairs(stages) do
    stageLabels[#stageLabels + 1] = ui.Label({
        text = stage.display_name,
        translate = false,
        width = BUTTON_WIDTH,
        height = BUTTON_HEIGHT})
    stageIds[#stageIds + 1] = stage.id
  end
  local stageStepper = ui.Stepper(
    {
      labels = stageLabels,
      values = stageIds,
      selectedIndex = 1,
      onChange = function(value) 
        GAME.theme:playMoveSfx()
        if playButtonGroup.value == "stage" then
          playMusic("stage", value, musicTypeButtonGroup.value)
        end
      end
    }
  )
  
  musicTypeButtonGroup = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({text = "Normal", translate = false})}),
        ui.TextButton({label = ui.Label({text = "Danger", translate = false})}),
      },
      values = {"normal_music", "danger_music"},
      selectedIndex = 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        if playButtonGroup.value == "character" then
          playMusic(playButtonGroup.value, characterStepper.value, value)
        elseif playButtonGroup.value == "stage" then
          playMusic(playButtonGroup.value, stageStepper.value, value)
        end
      end
    }
  )
  
  playButtonGroup = ui.ButtonGroup(
    {
      buttons = {
        ui.TextButton({label = ui.Label({id = "op_off"})}),
        ui.TextButton({label = ui.Label({id = "character"})}),
        ui.TextButton({label = ui.Label({id = "stage"})}),
      },
      values = {"", "character", "stage"},
      selectedIndex = 1,
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        if value == "character" then
          playMusic(value, characterStepper.value, musicTypeButtonGroup.value)
        elseif value == "stage" then
          playMusic(value, stageStepper.value, musicTypeButtonGroup.value)
        else
          SoundController:stopMusic()
        end
      end
    }
  )

  local labels, values = createSfxMenuInfo(characterStepper.value)

  sfxStepper = ui.Stepper(
    {
      labels = labels,
      values = values,
      selectedIndex = 1,
      onChange = function(value)
        GAME.theme:playMoveSfx()
      end
    }
  )

  local playCharacterSFXFn = function()
    if #sfxStepper.labels > 0 then
      love.audio.play(love.audio.newSource(characters[characterStepper.value].path.."/"..sfxStepper.value, "static"))
    end
  end

  local characterSelection = ui.MenuItem.createStepperMenuItem("character", nil, nil, characterStepper)
  local stageSelection = ui.MenuItem.createStepperMenuItem("stage", nil, nil, stageStepper)
  local musicType = ui.MenuItem.createToggleButtonGroupMenuItem("op_music_type", nil, nil, musicTypeButtonGroup)
  local musicPlayback = ui.MenuItem.createToggleButtonGroupMenuItem("Background", nil, false, playButtonGroup)
  local sfxSelection = ui.MenuItem.createStepperMenuItem("op_music_sfx", nil, nil, sfxStepper)
  local sfxPlayback = ui.MenuItem.createButtonMenuItem("op_music_play", nil, nil, playCharacterSFXFn)
  local back = ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
    SoundController:stopMusic()
    love.audio.stop()
    themes[config.theme].sounds.menu_validate = menuValidateSound
    GAME.navigationStack:pop()
  end)

  self.soundTestMenu = ui.VerticalMenu({
    hAlign = "center",
    minHeight = 480,
    maxHeight = 540,
    childGap = 8,
    padding = 32,
    width = 600,
  })

  self.soundTestMenu:addChild(characterSelection)
  self.soundTestMenu:addChild(stageSelection)
  self.soundTestMenu:addChild(musicType)
  self.soundTestMenu:addChild(musicPlayback)
  self.soundTestMenu:addChild(sfxSelection)
  self.soundTestMenu:addChild(sfxPlayback)
  self.soundTestMenu:addChild(back)

  self.uiRoot:addChild(self.soundTestMenu)
  self.cursor = ui.Cursor(self.soundTestMenu)

  self.backgroundImg = themes[config.theme].images.bg_main

  -- stop main music
  SoundController:stopMusic()

  -- disable the menu_validate sound and keep a copy of it to restore later
  menuValidateSound = themes[config.theme].sounds.menu_validate
  themes[config.theme].sounds.menu_validate = themes[config.theme].zero_sound

  GraphicsUtil.print(loc("op_music_load"), unpack(themes[config.theme].main_menu_screen_pos))
end

function SoundTest:update(dt)
  self.cursor:receiveInputs(dt)
  self.backgroundImg:update(dt)
end

function SoundTest:draw()
  self.backgroundImg:draw()
  self.cursor:draw()
  self.uiRoot:draw()
end

return SoundTest