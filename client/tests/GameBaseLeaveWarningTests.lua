local GameBase = require("client.src.scenes.GameBase")
local tableUtils = require("common.lib.tableUtils")

-- a game scene with only its pause menu, recording whether the match was aborted and the scene left
---@param leaveWarning string?
local function pausedGame(leaveWarning)
  local state = {aborted = false, left = false}
  local match = {abort = function() state.aborted = true end}
  local scene = GameBase({match = match, leaveWarning = leaveWarning})
  scene.startNextScene = function() state.left = true end
  scene:createPauseMenu()
  return scene, state
end

local function itemText(menuItem)
  local label = menuItem.textButton and menuItem.textButton.label or menuItem.children[1]
  return label.text
end

local function itemTexts(scene)
  return tableUtils.map(scene.pauseMenu.menuItems, itemText)
end

local function press(scene, text)
  for _, menuItem in ipairs(scene.pauseMenu.menuItems) do
    if itemText(menuItem) == text and menuItem.textButton then
      menuItem.textButton.onClick()
      return
    end
  end
  error("the pause menu has no button " .. text .. ", it has " .. table.concat(itemTexts(scene), ", "))
end

local function withoutAWarningBackLeavesTheGame()
  local scene, state = pausedGame()

  press(scene, "back")

  assert(state.aborted and state.left)
end

local function withAWarningThePauseMenuOffersLeaveInsteadOfBack()
  local scene = pausedGame("challenge_leave_warning")

  assert(tableUtils.contains(itemTexts(scene), "leave"))
  assert(not tableUtils.contains(itemTexts(scene), "back"))
end

local function pickingLeaveShowsTheWarningInPlaceOfThePauseHeading()
  local scene, state = pausedGame("challenge_leave_warning")

  press(scene, "leave")

  assert(not state.aborted and not state.left, "the game keeps going until the player confirms")
  assert(scene.pauseTitle == "warning", tostring(scene.pauseTitle))
  assert(scene.pauseSubtitle == "challenge_leave_warning", tostring(scene.pauseSubtitle))
end

local function theWarningOffersOnlyLeaveAndBack()
  local scene = pausedGame("challenge_leave_warning")

  press(scene, "leave")

  local texts = itemTexts(scene)
  assert(#texts == 2 and texts[1] == "leave" and texts[2] == "back", table.concat(texts, ", "))
end

local function confirmingTheWarningLeavesTheGame()
  local scene, state = pausedGame("challenge_leave_warning")
  press(scene, "leave")

  press(scene, "leave")

  assert(state.aborted and state.left)
end

local function backingOutOfTheWarningReturnsToThePauseMenu()
  local scene, state = pausedGame("challenge_leave_warning")
  press(scene, "leave")

  press(scene, "back")

  assert(not state.aborted and not state.left)
  assert(tableUtils.contains(itemTexts(scene), "pause_resume"))
  assert(scene.pauseTitle == "pause" and scene.pauseSubtitle == "pl_pause_help")
end

withoutAWarningBackLeavesTheGame()
withAWarningThePauseMenuOffersLeaveInsteadOfBack()
pickingLeaveShowsTheWarningInPlaceOfThePauseHeading()
theWarningOffersOnlyLeaveAndBack()
confirmingTheWarningLeavesTheGame()
backingOutOfTheWarningReturnsToThePauseMenu()
