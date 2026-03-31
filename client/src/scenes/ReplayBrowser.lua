local Scene = require("client.src.scenes.Scene")
local input = require("client.src.inputManager")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local fileUtils = require("client.src.FileUtils")
local ReplayV3 = require("common.data.ReplayV3")
local class = require("common.lib.class")
local GameModes = require("common.data.GameModes")
local ReplayGame = require("client.src.scenes.ReplayGame")
local ClientMatch = require("client.src.ClientMatch")

local ReplayBrowser = class(
  function (self, sceneParams)
    self.keepMusic = true
    self:load(sceneParams)
  end,
  Scene
)

ReplayBrowser.name = "ReplayBrowser"

local selection = nil
local base_path = "replays"
local current_path = "/"
local path_contents = {}
local filename = nil
local state = "browser"
-- technically this should start as nil but it drives the language server a bit crazy
---@type ReplayV3
local selectedReplay

local menu_x = 400
local menu_y = 280
local menu_h = 14
local menu_cursor_offset = 16

local cursor_pos = 0

local replay_id_top = 0

local function replayMenu()
  if (replay_id_top == 0) then
    if current_path ~= "/" then
      GraphicsUtil.print("< " .. loc("rp_browser_up") .. " >", menu_x, menu_y)
    else
      GraphicsUtil.print("< " .. loc("rp_browser_root") .. " >", menu_x, menu_y)
    end
  else
    GraphicsUtil.print("^ " .. loc("rp_browser_more") .. " ^", menu_x, menu_y)
  end

  for i, p in pairs(path_contents) do
    if (i > replay_id_top) and (i <= replay_id_top + 20) then
      GraphicsUtil.print(p, menu_x, menu_y + (i - replay_id_top) * menu_h)
    end
  end

  if #path_contents > replay_id_top + 20 then
    GraphicsUtil.print("v " .. loc("rp_browser_more") .. " v", menu_x, menu_y + 21 * menu_h)
  end

  GraphicsUtil.print(">", menu_x - menu_cursor_offset + math.sin(love.timer.getTime() * 8) * 5, menu_y + (cursor_pos - replay_id_top) * menu_h)
end

local function moveCursor(dir)
  cursor_pos = wrap(0, cursor_pos + dir, #path_contents)
  if cursor_pos <= replay_id_top then
    replay_id_top = math.max(cursor_pos, 1) - 1
  end
  if replay_id_top < cursor_pos - 20 then
    replay_id_top = cursor_pos - 20
  end
end

local function updateBrowsingPath(new_path)
  if new_path then
    cursor_pos = 0
    replay_id_top = 0
    if new_path == "" then
      new_path = "/"
    end
    current_path = new_path
  end
  path_contents = fileUtils.getFilteredDirectoryItems(base_path .. current_path)
  if not path_contents[cursor_pos] then
    cursor_pos = replay_id_top
  end
end
  
local function setPathToParentDir()
  updateBrowsingPath(current_path:gsub("(.*/).*/$", "%1"))
end

local function selectMenuItem()
  if cursor_pos == 0 then
    setPathToParentDir()
  else
    selection = base_path .. current_path .. path_contents[cursor_pos]
    local file_info = love.filesystem.getInfo(selection)
    if file_info then
      if file_info.type == "file" then
        filename = selection
        local replay = ReplayV3.createFromTable(fileUtils.readJsonFile(selection), true)
        if replay then
          selectedReplay = replay
        else
          GAME.theme:playCancelSfx()
        end
        return not not replay
      elseif file_info.type == "directory" then
        updateBrowsingPath(current_path .. path_contents[cursor_pos] .. "/")
      else
        --print(loc("rp_browser_error_unknown_filetype", file_info.type, selection))
      end
    else
      --print(loc("rp_browser_error_file_not_found", selection))
    end
  end
end

function ReplayBrowser:load()
  if GAME.lastReplayPath then
    current_path = string.sub(GAME.lastReplayPath, (string.len(base_path) + 1)) .. "/"
  end

  state = "browser"
  updateBrowsingPath(current_path)
end

function ReplayBrowser:update()
  if state == "browser" then
    if input.isDown["MenuEsc"] then
      GAME.theme:playCancelSfx()
      GAME.navigationStack:pop()
    end
    if input.isDown["MenuSelect"] then
      GAME.theme:playValidationSfx()
      if selectMenuItem() then
        state = "info"
      end
    end
    if input.isDown["MenuBack"] then
      if current_path == "/" then
        GAME.theme:playCancelSfx()
      else
        GAME.theme:playValidationSfx()
        setPathToParentDir()
      end
    end
    if input:isPressedWithRepeat("MenuUp") then
      GAME.theme:playMoveSfx()
      moveCursor(-1)
    end
    if input:isPressedWithRepeat("MenuDown") then
      GAME.theme:playMoveSfx()
      moveCursor(1)
    end
  elseif state == "info" then
    if input.isDown["MenuEsc"] or input.isDown["MenuBack"] then
      GAME.theme:playValidationSfx()
      state = "browser"
    end
    if input.isDown["MenuSelect"] then
      if ReplayV3.replayCanBeViewed(selectedReplay) then
        GAME.theme:playValidationSfx()
        SoundController:stopMusic()
        local match = ClientMatch.createFromReplay(selectedReplay)
        match.renderDuringPause = true
        match.supportsPause = true
        match:start()
        GAME.navigationStack:push(ReplayGame({match = match}))
      else
        GAME.theme:playCancelSfx()
      end
    end
  end
end

function ReplayBrowser:draw()
  themes[config.theme].images.bg_main:draw()

  if state == "browser" then
    GraphicsUtil.print(loc("rp_browser_header"), menu_x + 170, menu_y - 40)
    GraphicsUtil.print(loc("rp_browser_current_dir", base_path .. current_path), menu_x, menu_y - 40 + menu_h)
    replayMenu()
  elseif state == "info" then
    local next_func = nil
    if ReplayV3.replayCanBeViewed(selectedReplay) == false then
      GraphicsUtil.print(loc("rp_browser_wrong_version"), menu_x - 150, menu_y - 80 + menu_h)
    end

    GraphicsUtil.print(loc("rp_browser_info_header"), menu_x + 170, menu_y - 40)
    GraphicsUtil.print(filename, menu_x - 150, menu_y - 40 + menu_h)

    local modeText
    if selectedReplay.metadata.gameModeName == "VS" then
      modeText = loc("rp_browser_info_2p_vs")
    elseif selectedReplay.metadata.gameModeName == "challenge" then
      modeText = loc("mm_1_challenge_mode")
    elseif selectedReplay.metadata.gameModeName == "vsSelf" then
      modeText = loc("mm_1_vs")
    elseif selectedReplay.metadata.gameModeName == "training" then
      modeText = loc("mm_1_training")
    elseif selectedReplay.metadata.gameModeName == "puzzle" then
      modeText = loc("mm_1_puzzle")
    elseif selectedReplay.metadata.gameModeName == "timeattack" then
      modeText = loc("mm_1_time")
    elseif selectedReplay.metadata.gameModeName == "endless" then
      modeText = loc("mm_1_endless")
    else
      modeText = "Unknown"
    end

    GraphicsUtil.print(modeText, menu_x + 220, menu_y + 20)

    local offsetX = 0
    for i, player in ipairs(selectedReplay.metadata.stacks) do
      local stack = selectedReplay.stacks[player.stackIndex]
      GraphicsUtil.print(loc("rp_browser_info_" .. i .. "p"), menu_x + offsetX, menu_y + 50)
      GraphicsUtil.print(loc("rp_browser_info_name", player.name or ("Player " .. i)), menu_x + offsetX, menu_y + 65)
      GraphicsUtil.print(loc("rp_browser_info_character", player.characterId or ""), menu_x + offsetX, menu_y + 80)
      if stack.stackType == 1 then
        ---@cast player StackMetadata
        ---@cast stack ReplayStack
        if player.level then
          GraphicsUtil.print(loc("rp_browser_info_level", player.level), menu_x + offsetX, menu_y + 95)
        else
          if player.difficulty then
            GraphicsUtil.print(loc("rp_browser_info_speed", stack.levelData.startingSpeed), menu_x + offsetX, menu_y + 95)
            GraphicsUtil.print(loc("rp_browser_info_difficulty", player.difficulty), menu_x + offsetX, menu_y + 110)
          end
        end
      else
        ---@cast player SimulatedStackMetadata
        if player.challengeModeDifficulty then
          GraphicsUtil.print(loc("challenge_difficulty_" .. player.challengeModeDifficulty), menu_x + offsetX, menu_y + 95)
        end
        if player.stageIndex then
          GraphicsUtil.print(loc("stage") .. " " .. player.stageIndex, menu_x + offsetX, menu_y + 110)
        end
      end
      offsetX = offsetX + 300
    end

    if selectedReplay.metadata.ranked then
      GraphicsUtil.print(loc("rp_browser_info_ranked"), menu_x + 200, menu_y + 130)
    end

    if ReplayV3.replayCanBeViewed(selectedReplay) then
      GraphicsUtil.print(loc("rp_browser_watch"), menu_x + 75, menu_y + 150)
    end
  end
end

return ReplayBrowser