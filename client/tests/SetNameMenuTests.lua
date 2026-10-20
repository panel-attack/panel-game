local SetNameMenu = require("client.src.scenes.SetNameMenu")
local logger = require("common.lib.logger")

-- runs testFunction without touching the saved config or the navigation stack
local function withStubbedState(testFunction)
  local originalName = config.name
  local originalLocalPlayerName = GAME.localPlayer.name
  local originalWriteConfFile = write_conf_file
  local originalPop = GAME.navigationStack.pop
  local popCount = 0

  write_conf_file = function() end
  -- same parameters as NavigationStack:pop so the language server does not infer a different signature for every caller
  GAME.navigationStack.pop = function(_navigationStack, _transition, _callback) popCount = popCount + 1 end

  local success, err = pcall(testFunction, function() return popCount end)

  write_conf_file = originalWriteConfFile
  GAME.navigationStack.pop = originalPop
  config.name = originalName
  GAME.localPlayer.name = originalLocalPlayerName

  if not success then
    error(err, 0)
  end
end

local function testConfirmWithoutCallbackReturnsToPreviousScene()
  withStubbedState(function(getPopCount)
    local menu = SetNameMenu()
    menu.nameField.value = "tester"
    menu:confirmName()
    assert(config.name == "tester", "Confirming should save the name")
    assert(getPopCount() == 1, "Confirming without onNameSet should return to the previous scene")
  end)
  logger.trace("passed test testConfirmWithoutCallbackReturnsToPreviousScene")
end

local function testConfirmWithCallbackContinuesInsteadOfReturning()
  withStubbedState(function(getPopCount)
    local callbackCount = 0
    local menu = SetNameMenu({onNameSet = function() callbackCount = callbackCount + 1 end})
    menu.nameField.value = "tester"
    menu:confirmName()
    assert(config.name == "tester", "Confirming should save the name")
    assert(callbackCount == 1, "Confirming should call onNameSet")
    assert(getPopCount() == 0, "Confirming with onNameSet should not return to the previous scene")
  end)
  logger.trace("passed test testConfirmWithCallbackContinuesInsteadOfReturning")
end

local function testBlankNameDoesNotContinue()
  withStubbedState(function(getPopCount)
    local callbackCount = 0
    local menu = SetNameMenu({onNameSet = function() callbackCount = callbackCount + 1 end})
    menu.nameField.value = ""
    menu:confirmName()
    assert(callbackCount == 0, "A blank name should not continue")
    assert(getPopCount() == 0, "A blank name should not leave the menu")
  end)
  logger.trace("passed test testBlankNameDoesNotContinue")
end

-- names the server would refuse are caught before they are saved, not only blank ones
local function testNameTheServerRefusesIsNotSaved()
  withStubbedState(function(getPopCount)
    local callbackCount = 0
    config.name = "before"
    local menu = SetNameMenu({onNameSet = function() callbackCount = callbackCount + 1 end})
    menu.nameField.value = "anonymous"
    menu:confirmName()
    assert(config.name == "before", "A name the server refuses should not be saved")
    assert(callbackCount == 0, "A name the server refuses should not continue")
    assert(getPopCount() == 0, "A name the server refuses should not leave the menu")
  end)
  logger.trace("passed test testNameTheServerRefusesIsNotSaved")
end

testConfirmWithoutCallbackReturnsToPreviousScene()
testConfirmWithCallbackContinuesInsteadOfReturning()
testBlankNameDoesNotContinue()
testNameTheServerRefusesIsNotSaved()
