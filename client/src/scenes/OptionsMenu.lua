local Scene = require("client.src.scenes.Scene")
local ui = require("client.src.ui")
local inputManager = require("client.src.inputManager")
local save = require("client.src.save")
local consts = require("common.engine.consts")
local fileUtils = require("client.src.FileUtils")
local analytics = require("client.src.analytics")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local SoundTest = require("client.src.scenes.SoundTest")
local SetUserIdMenu = require("client.src.scenes.SetUserIdMenu")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local util = require("common.lib.util")
local ModManagement = require("client.src.scenes.ModManagement")
local system = require("client.src.system")
local logger = require("common.lib.logger")
local prof = require("common.lib.zoneProfiler")

-- Scene for the options menu
local OptionsMenu = class(function(self, sceneParams)
  self.music = "main"
  self.activeMenuName = "baseMenu"
  self:load(sceneParams)
end, Scene)

OptionsMenu.name = "OptionsMenu"

local SCROLL_STEP = 14

function OptionsMenu:loadScreens()
  local menus = {}

  menus.baseMenu = self:loadBaseMenu()
  menus.generalMenu = self:loadGeneralMenu()
  menus.graphicsMenu = self:loadGraphicsMenu()
  menus.audioMenu = self:loadSoundMenu()
  menus.debugMenu = self:loadDebugMenu()
  menus.aboutMenu = self:loadAboutMenu()
  menus.modifyUserIdMenu = self:loadModifyUserIdMenu()
  menus.systemInfo = self:loadInfoScreen(self:getSystemInfo())
  menus.aboutThemes = self:loadInfoScreen(save.read_txt_file("docs/themes.md"))
  menus.aboutCharacters = self:loadInfoScreen(save.read_txt_file("docs/characters.md"))
  menus.aboutStages = self:loadInfoScreen(save.read_txt_file("docs/stages.md"))
  menus.aboutPanels = self:loadInfoScreen(save.read_txt_file("docs/panels.md"))
  menus.aboutAttackFiles = self:loadInfoScreen(save.read_txt_file("docs/training.txt"))
  menus.installingMods = self:loadInfoScreen(save.read_txt_file("docs/installMods.md"))

  if #menus.modifyUserIdMenu.menuItems == 1 then
    menus.baseMenu:removeMenuItemAtIndex(7)
  end

  return menus
end

function OptionsMenu.exit()
  if not themes[config.theme].fullyLoaded then
    themes[config.theme]:load()
    for _, theme in pairs(themes) do
      if theme.name ~= config.theme and theme.fullyLoaded then
        -- unload previous theme to free resources
        theme:preload()
      end
    end
  end
  GAME.theme:playValidationSfx()
  GAME.navigationStack:pop()
end

function OptionsMenu:updateMenuLanguage()
  for _, menu in pairs(self.menus) do
    menu:refreshLocalization()
  end
  for _, scene in ipairs(GAME.navigationStack.scenes) do
    scene:refreshLocalization()
  end
end

function OptionsMenu:switchToScreen(screenName)
  self.menus[self.activeMenuName]:detach()
  self.uiRoot:addChild(self.menus[screenName])
  self.activeMenuName = screenName
end

local function createToggleButtonGroup(configField, onChangeFn)
  return ui.ButtonGroup({
    buttons = {ui.TextButton({width = 60, label = ui.Label({text = "op_off"})}), ui.TextButton({width = 60, label = ui.Label({text = "op_on"})})},
    values = {false, true},
    selectedIndex = config[configField] and 2 or 1,
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config[configField] = value
      if onChangeFn then
        onChangeFn()
      end
    end
  })
end

local function createConfigSlider(configField, min, max, onValueChangeFn, value)
  return ui.Slider({
    min = min,
    max = max,
    value = value or config[configField] or 0,
    tickLength = math.ceil(100 / max),
    onValueChange = function(slider)
      config[configField] = slider.value
      if onValueChangeFn then
        onValueChangeFn(slider)
      end
    end
  })
end

function OptionsMenu:getSystemInfo()
  self.backgroundImage = themes[config.theme].images.bg_readme
  local rendererName, rendererVersion, graphicsCardVendor, graphicsCardName = love.graphics.getRendererInfo()
  local sysInfo = {}
  sysInfo[#sysInfo + 1] = {name = "Operating System", value = love.system.getOS()}
  sysInfo[#sysInfo + 1] = {name = "Renderer", value = rendererName .. " " .. rendererVersion}
  sysInfo[#sysInfo + 1] = {name = "Graphics Card", value = graphicsCardName}
  sysInfo[#sysInfo + 1] = {name = "LOVE Version", value = system.loveVersionString()}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Engine Version", value = consts.ENGINE_VERSION}
  sysInfo[#sysInfo + 1] = {name = "Panel Attack Release Version", value = GAME.updater and tostring(GAME.updater.activeVersion.version) or nil}
  sysInfo[#sysInfo + 1] = {name = "Save Data Directory Path", value = love.filesystem.getSaveDirectory()}
  sysInfo[#sysInfo + 1] = {name = "Characters [Visible/Enabled]", value = #visibleCharacters .. "/" .. tableUtils.length(characters)}
  sysInfo[#sysInfo + 1] = {name = "Stages [Visible/Enabled]", value = #visibleStages .. "/" .. tableUtils.length(stages)}
  sysInfo[#sysInfo + 1] = {name = "Total Panel Sets", value = #panels_ids}
  sysInfo[#sysInfo + 1] = {name = "Total Themes", value = #themeIds}

  local infoString = ""
  for index, info in ipairs(sysInfo) do
    infoString = infoString .. info.name .. ": " .. (info.value or "Unknown") .. "\n"
  end
  return infoString
end

function OptionsMenu:loadInfoScreen(text)
  local label = ui.Label({text = text, translate = false, vAlign = "top", x = 6, y = 6})
  local infoScreen = ui.ScrollText({hFill = true, vFill = true, label = label})
  infoScreen.onBackCallback = function()
    GAME.theme:playCancelSfx()
    self.backgroundImage = themes[config.theme].images.bg_main
    self:switchToScreen("aboutMenu")
  end
  infoScreen.yieldFocus = function() end

  return infoScreen
end

function OptionsMenu:loadBaseMenu()
  local languageNumber
  local languageName = {}
  for k, v in ipairs(Localization:get_list_codes()) do
    languageName[#languageName + 1] = {v, Localization.data[v]["LANG"]}
    if Localization:get_language() == v then
      languageNumber = k
    end
  end
  local languageLabels = {}
  for k, v in ipairs(languageName) do
    local lang = config.language_code
    GAME:setLanguage(v[1])
    languageLabels[#languageLabels + 1] = ui.Label({text = v[2], translate = false, width = 70, height = 25})
    GAME:setLanguage(lang)
  end

  local languageStepper = ui.Stepper({
    labels = languageLabels,
    values = languageName,
    selectedIndex = languageNumber,
    onChange = function(value)
      GAME.theme:playMoveSfx()
      GAME:setLanguage(value[1])
      self:updateMenuLanguage()
    end
  })

  local baseMenuOptions = {
      ui.MenuItem.createStepperMenuItem("op_language", nil, nil, languageStepper),
      ui.MenuItem.createButtonMenuItem("op_general", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("generalMenu")
        end), 
      ui.MenuItem.createButtonMenuItem("op_graphics", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("graphicsMenu")
        end),
      ui.MenuItem.createButtonMenuItem("op_audio", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("audioMenu")
        end),
      ui.MenuItem.createButtonMenuItem("op_debug", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("debugMenu")
        end),
      ui.MenuItem.createButtonMenuItem("op_about", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("aboutMenu")
        end),
      ui.MenuItem.createButtonMenuItem("Modify User ID", nil, false, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("modifyUserIdMenu")
        end),
      ui.MenuItem.createButtonMenuItem("Manage Mods", nil, false, function()
        GAME.theme:playValidationSfx()
        GAME.navigationStack:push(ModManagement())
      end),
      ui.MenuItem.createButtonMenuItem("back", nil, nil, self.exit)
    }

  local menu = ui.Menu.createCenteredMenu(baseMenuOptions)
  return menu
end

function OptionsMenu:loadGeneralMenu()
  local saveReplaysPubliclyIndexMap = {["with my name"] = 1, ["anonymously"] = 2, ["not at all"] = 3}
  local publicReplayButtonGroup = ui.ButtonGroup({
    buttons = {
      ui.TextButton({label = ui.Label({text = "op_replay_public_with_name"})}),
      ui.TextButton({label = ui.Label({text = "op_replay_public_anonymously"})}), ui.TextButton({label = ui.Label({text = "op_replay_public_no"})})
    },
    values = {"with my name", "anonymously", "not at all"},
    selectedIndex = saveReplaysPubliclyIndexMap[config.save_replays_publicly],
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config.save_replays_publicly = value
    end
  })

  local releaseStreamSelection

  if GAME.updater and GAME.updater.releaseStreams and GAME_UPDATER_STATES then
    ---@type string[]
    local releaseStreams = {}

    for name, _ in pairs(GAME.updater.releaseStreams) do
      releaseStreams[#releaseStreams+1] = name
    end

    -- in case the version was changed earlier and we return to options again, reset to the currently launched version
    -- this is so whatever the user leaves the setting on when quitting options that will be what is launched with next time
    GAME.updater:writeLaunchConfig(GAME.updater.activeVersion)

    local buttons = {}

    for i = 1, #releaseStreams do
      buttons[#buttons+1] = ui.TextButton({label = ui.Label({text = releaseStreams[i], translate = false})})
    end

    local function updateReleaseStreamConfig(releaseStreamName)
      local releaseStream = GAME.updater.releaseStreams[releaseStreamName]
      local version = GAME.updater.getLatestInstalledVersion(releaseStream)
      if not version then
        if not GAME.updater:updateAvailable(releaseStream) then
          GAME.updater:getAvailableVersions(releaseStream)
          while GAME.updater.state ~= GAME_UPDATER_STATES.idle do
            GAME.updater:update()
          end
        end
        if GAME.updater:updateAvailable(releaseStream) then
          table.sort(releaseStream.availableVersions, function(a,b) return a.version > b.version end)
          version = releaseStream.availableVersions[1]
        else
          return false
        end
      end
      GAME.updater:writeLaunchConfig(version)

      return true
    end

    releaseStreamSelection = ui.ButtonGroup({
      buttons = buttons,
      values = releaseStreams,
      selectedIndex = tableUtils.indexOf(releaseStreams, GAME.updater.activeVersion.releaseStream.name),
      onChange = function(group, value)
        GAME.theme:playMoveSfx()
        local success = updateReleaseStreamConfig(value)
        if not success then
          -- there are no versions for the picked stream
          -- for safety reasons remove the option for that button so the updater does not start in a potentially unsalvageable configuration
          local index = tableUtils.indexOf(releaseStreams, value)
          group:removeButtonByValue(value)
          ---@cast index integer
          index = util.bound(1, index, #group.buttons)
          -- simulate changing to the button that replaces the one that got removed due to no attached versions
          group.buttons[index]:onClick(nil, 0)
        end
      end
    })
  end

  local generalMenuOptions = {
    ui.MenuItem.createToggleButtonGroupMenuItem("op_fps", nil, nil, createToggleButtonGroup("show_fps")),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_ingame_infos", nil, nil, createToggleButtonGroup("show_ingame_infos")),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_analytics", nil, nil, createToggleButtonGroup("enable_analytics", function()
      analytics.init()
    end)),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_replay_public", nil, nil, publicReplayButtonGroup),
  }

  if releaseStreamSelection then
    generalMenuOptions[#generalMenuOptions+1] = ui.MenuItem.createToggleButtonGroupMenuItem("Release Stream", nil, false, releaseStreamSelection)
  end

  generalMenuOptions[#generalMenuOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil,
  function()
    GAME.theme:playCancelSfx()
    self:switchToScreen("baseMenu")
    if GAME.updater and GAME.updater.releaseStreams then
      if releaseStreamSelection.value ~= GAME.updater.activeReleaseStream.name then
        love.window.showMessageBox("Changing Release Stream", "Please restart the game to launch the selected release stream")
      end
    end
  end)

  local menu = ui.Menu.createCenteredMenu(generalMenuOptions)
  return menu
end

function OptionsMenu:loadGraphicsMenu()
  local themeIndex
  local themeLabels = {}
  for i, v in ipairs(themeIds) do
    themeLabels[#themeLabels + 1] = ui.Label({text = v, translate = false})
    if config.theme == v then
      themeIndex = i
    end
  end
  local themeStepper = ui.Stepper({
    labels = themeLabels,
    values = themeIds,
    selectedIndex = themeIndex,
    onChange = function(value)
      GAME.theme:playMoveSfx()
      themes[value]:preload()
      config.theme = value
      GAME.theme = themes[value]
      SoundController:stopMusic()
      GraphicsUtil.setGlobalFont(themes[config.theme].font.path, themes[config.theme].font.size)
      self:updateMenuLanguage()
      self.backgroundImage = themes[config.theme].images.bg_main
      self:applyMusic()
    end
  })

  local function scaleSettingsChanged()
    GAME.showGameScaleUntil = GAME.timer + 10
    local newPixelWidth, newPixelHeight = love.graphics.getDimensions()
    local previousXScale = GAME.canvasXScale
    logger.debug("Updating canvas scale from options")
    GAME:updateCanvasPositionAndScale(newPixelWidth, newPixelHeight)
    if previousXScale ~= GAME.canvasXScale then
      GAME:refreshCanvasAndImagesForNewScale()
    end
  end

  local function getFixedScaleSlider()
    local slider = ui.Slider({
      min = 0.5,
      max = 3,
      value = config.gameScaleFixedValue or 1,
      tickAmount = 0.01,
      tickLength = 1,
      onlyChangeOnRelease = true, -- performance is bad so don't change till release
      onValueChange = function(slider)
        config.gameScaleFixedValue = slider.value
        scaleSettingsChanged()
      end
    })
    return slider
  end

  local fixedScaleSlider = ui.MenuItem.createSliderMenuItem("op_scale_fixed_value", nil, true,
    getFixedScaleSlider())
  local function updateFixedButtonGroupVisibility()
    if config.gameScaleType ~= "fixed" then
      self.menus.graphicsMenu:removeMenuItem(fixedScaleSlider.id)
    else
      if self.menus.graphicsMenu:containsMenuItemID(fixedScaleSlider.id) == false then
        self.menus.graphicsMenu:addMenuItem(3, fixedScaleSlider)
      end
    end
  end

  local scaleTypeData = {
    {value = "auto", text = "op_scale_auto"}, {value = "fit", text = "op_scale_fit"}, {value = "fixed", text = "op_scale_fixed"}
  }
  for index, value in ipairs(scaleTypeData) do
    value.index = index
  end

  local scaleButtonGroup = ui.ButtonGroup({
    buttons = tableUtils.map(scaleTypeData, function(scaleType)
      return ui.TextButton({label = ui.Label({text = scaleType.text})})
    end),
    values = tableUtils.map(scaleTypeData, function(scaleType)
      return scaleType.value
    end),
    selectedIndex = tableUtils.first(scaleTypeData, function(scaleType)
      return scaleType.value == config.gameScaleType
    end).index,
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      config.gameScaleType = value
      updateFixedButtonGroupVisibility()
      scaleSettingsChanged()
    end
  })

  local function getShakeIntensitySlider()
    local slider = ui.Slider({
      min = 50,
      max = 100,
      value = (config.shakeIntensity * 100) or 100,
      tickAmount = 5,
      tickLength = 10,
      onValueChange = function(slider)
        config.shakeIntensity = slider.value / 100
      end
    })
    return slider
  end

  local graphicsMenuOptions = {
    ui.MenuItem.createStepperMenuItem("op_theme", nil, nil, themeStepper),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_scale", nil, nil, scaleButtonGroup),
    ui.MenuItem.createSliderMenuItem("op_portrait_darkness", nil, nil, createConfigSlider("portrait_darkness", 0, 100)),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_popfx", nil, nil, createToggleButtonGroup("popfx")),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_renderTelegraph", nil, nil, createToggleButtonGroup("renderTelegraph")),
    ui.MenuItem.createToggleButtonGroupMenuItem("op_renderAttacks", nil, nil, createToggleButtonGroup("renderAttacks")),
    ui.MenuItem.createSliderMenuItem("op_shakeIntensity", nil, nil, getShakeIntensitySlider()),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.showGameScaleUntil = GAME.timer
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end)
  }

  local menu = ui.Menu.createCenteredMenu(graphicsMenuOptions)
  if config.gameScaleType == "fixed" then
    menu:addMenuItem(3, fixedScaleSlider)
  end
  return menu
end

function OptionsMenu:loadSoundMenu()
  local musicFrequencyIndexMap = {["stage"] = 1, ["often_stage"] = 2, ["either"] = 3, ["often_characters"] = 4, ["characters"] = 5}
  local musicFrequencyStepper = ui.Stepper({
    labels = {
      ui.Label({text = "op_only_stage"}), ui.Label({text = "op_often_stage"}), ui.Label({text = "op_stage_characters"}),
      ui.Label({text = "op_often_characters"}), ui.Label({text = "op_only_characters"})
    },
    values = {"stage", "often_stage", "either", "often_characters", "characters"},
    selectedIndex = musicFrequencyIndexMap[config.use_music_from],
    onChange = function(value)
      GAME.theme:playMoveSfx()
      config.use_music_from = value
    end
  })

  local audioMenuOptions = {
    ui.MenuItem.createSliderMenuItem("op_vol", nil, nil, createConfigSlider("master_volume", 0, 100, function(slider)
        SoundController:setMasterVolume(slider.value)
      end)),
    ui.MenuItem.createSliderMenuItem("op_vol_sfx", nil, nil, createConfigSlider("SFX_volume", 0, 100, function()
        SoundController:applyConfigVolumes()
      end)),
    ui.MenuItem.createSliderMenuItem("op_vol_music", nil, nil, createConfigSlider("music_volume", 0, 100, function()
        SoundController:applyConfigVolumes()
      end)),
      ui.MenuItem.createToggleButtonGroupMenuItem("op_menu_music", nil, nil, createToggleButtonGroup("enableMenuMusic", function() self:applyMusic() end)),
      ui.MenuItem.createStepperMenuItem("op_use_music_from", nil, nil, musicFrequencyStepper),
      ui.MenuItem.createToggleButtonGroupMenuItem("op_music_delay", nil, nil, createToggleButtonGroup("danger_music_changeback_delay")),
    ui.MenuItem.createButtonMenuItem("mm_music_test", nil, nil, function()
        GAME.navigationStack:push(SoundTest())
      end),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
        GAME.theme:playCancelSfx()
        self:switchToScreen("baseMenu")
      end)
  }

  local menu = ui.Menu.createCenteredMenu(audioMenuOptions)
  return menu
end

function OptionsMenu:loadDebugMenu()
  local debugMenuOptions = {
    ui.MenuItem.createToggleButtonGroupMenuItem("op_debug", nil, nil, createToggleButtonGroup("debug_mode")),
    ui.MenuItem.createSliderMenuItem("VS Frames Behind", nil, false, createConfigSlider("debug_vsFramesBehind", 0, 200)),
    ui.MenuItem.createToggleButtonGroupMenuItem("Show Debug Servers", nil, false, createToggleButtonGroup("debugShowServers")),
    ui.MenuItem.createToggleButtonGroupMenuItem("Show Design Helper", nil, false, createToggleButtonGroup("debugShowDesignHelper")),
    ui.MenuItem.createButtonMenuItem("Window Size Tester", nil, false, function()
      GAME.navigationStack:push(require("client.src.scenes.WindowSizeTester")())
    end),
    ui.MenuItem.createToggleButtonGroupMenuItem("Profile frame times", nil, false, createToggleButtonGroup("debugProfile",
      function()
        prof.enable(config.debugProfile)
        prof.setDurationFilter(config.debugProfileThreshold / 1000)
      end)),
    ui.MenuItem.createSliderMenuItem("Discard frames below duration (ms)", nil, false, createConfigSlider("debugProfileThreshold", 0, 100,
      function()
        prof.setDurationFilter(config.debugProfileThreshold / 1000)
      end)),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end),
  }

  return ui.Menu.createCenteredMenu(debugMenuOptions)
end

function OptionsMenu:loadAboutMenu()
  local aboutMenuOptions = {
    ui.MenuItem.createButtonMenuItem("op_about_themes", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/themes.md")
        end),
    ui.MenuItem.createButtonMenuItem("op_about_characters", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/characters.md")
        end),
    ui.MenuItem.createButtonMenuItem("op_about_stages", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/stages.md")
        end),
    ui.MenuItem.createButtonMenuItem("op_about_panels", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/panels.md")
        end),
    ui.MenuItem.createButtonMenuItem("About Attack Files", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/training.txt")
        end),
    ui.MenuItem.createButtonMenuItem("Installing Mods", nil, nil, function()
          GAME.theme:playValidationSfx()
          love.system.openURL("https://github.com/panel-attack/panel-game/blob/beta/docs/installMods.md")
        end),
    ui.MenuItem.createButtonMenuItem("System Info", nil, nil, function()
          GAME.theme:playValidationSfx()
          self:switchToScreen("systemInfo")
        end),
    ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
          GAME.theme:playCancelSfx()
          self:switchToScreen("baseMenu")
        end)
  }

  local menu = ui.Menu.createCenteredMenu(aboutMenuOptions)
  return menu
end

function OptionsMenu:loadModifyUserIdMenu()
  local modifyUserIdOptions = {}
  local userIDDirectories = fileUtils.getFilteredDirectoryItems("servers")
  for i = 1, #userIDDirectories do
    if love.filesystem.getInfo("servers/" .. userIDDirectories[i] .. "/user_id.txt", "file") then
      modifyUserIdOptions[#modifyUserIdOptions + 1] = ui.MenuItem.createButtonMenuItem(userIDDirectories[i], nil, false, function()
          GAME.navigationStack:push(SetUserIdMenu({serverIp = userIDDirectories[i]}))
        end)
    end
  end
  modifyUserIdOptions[#modifyUserIdOptions + 1] = ui.MenuItem.createButtonMenuItem("back", nil, nil, function()
        GAME.theme:playCancelSfx()
        self:switchToScreen("baseMenu")
      end)

  return ui.Menu.createCenteredMenu(modifyUserIdOptions)
end

function OptionsMenu:load()
  self.menus = self:loadScreens()

  self.backgroundImage = themes[config.theme].images.bg_main
  self.uiRoot:addChild(self.menus.baseMenu)
end

function OptionsMenu:update(dt)
  self.backgroundImage:update(dt)
  self.menus[self.activeMenuName]:receiveInputs(inputManager)
end

function OptionsMenu:draw()
  self.backgroundImage:draw()
  self.uiRoot:draw()
end

return OptionsMenu
