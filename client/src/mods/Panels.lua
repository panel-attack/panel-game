local logger = require("common.lib.logger")
local tableUtils = require("common.lib.tableUtils")
local fileUtils = require("client.src.FileUtils")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local class = require("common.lib.class")

local ANIMATION_STATES = {
  "normal", "landing", "swapping",
  "flash", "face", "popping",
  "hovering", "falling",
  "dimmed", "dead",
  "danger",
  "garbagePop"
}

local OPTIONAL_ANIMATION_STATES = {
  "garbageBounce",
}

local DEFAULT_PANEL_ANIM =
{
  -- currently not animatable
	normal = {frames = {1}},
  -- doesn't loop, fixed duration of 12 frames
	landing = {frames = {4, 3, 2, 1}, durationPerFrame = 3},
  -- doesn't loop, fixed duration of 4 frames
  swapping = {frames = {1}},
  -- loops
	flash = {frames = {5, 1}},
  -- doesn't loop
  face = {frames = {6}},
  -- doesn't loop
	popping = {frames = {6}},
  -- too short to reasonably animate
	hovering = {frames = {1}},
  -- currently not animatable
	falling = {frames = {1}},
  -- currently not animatable
  dimmed = {frames = {7}},
  -- currently not animatable
	dead = {frames = {6}},
  -- loops; frames play back to front, fixed to 18 frames
  -- danger is special in that there is a frame offset depending on column offset
  -- col 1 and 2 start on frame 3, col 3 and 4 start on frame 4 and col 5 and 6 start on frame 5 of the animation
	danger = {frames = {4, 1, 2, 3, 2, 1}, durationPerFrame = 3},
  -- currently not animatable
  garbagePop = {frames = {1}},
  -- doesn't loop; fixed to 12 frames
	garbageBounce = {frames = {1, 4, 3, 2}, durationPerFrame = 3},
}

-- The class representing the panel image data
-- Not to be confused with "Panel" which is one individual panel in the game stack model
Panels =
  class(
  function(self, full_path, folder_name)
    self.path = full_path -- string | path to the panels folder content
    self.id = folder_name -- string | id of the panel set, is also the name of its folder by default, may change in json_init
    self.images = {}
    -- sprite sheets indexed by color
    self.sheets = {}
    -- mapping each animation state to a row on the sheet
    self.sheetConfig = {}
    self.batches = {}
    self.size = 16
  end
)

Panels.TYPE = "panels"
-- name of the top level save directory for mods of this type
Panels.SAVE_DIR = "panels"

function Panels:json_init()
  local read_data = fileUtils.readJsonFile(self.path .. "/config.json")
  if read_data then
    if read_data.id then
      self.id = read_data.id

      self.name = read_data.name or self.id
      self.type = read_data.type or "single"
      self.animationConfig = read_data.animationConfig or DEFAULT_PANEL_ANIM

      return true
    end
  end

  return false
end

-- Recursively load all panel images from the given directory
local function add_panels_from_dir_rec(path)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path, "directory") then
      -- call recursively: facade folder
      add_panels_from_dir_rec(current_path)

      -- init stage: 'real' folder
      local panel_set = Panels(current_path, v)
      local success = panel_set:json_init()

      if success then
        if panels[panel_set.id] ~= nil then
          logger.trace(current_path .. " has been ignored since a panel set with this id has already been found")
        else
          panels[panel_set.id] = panel_set
          panels_ids[#panels_ids + 1] = panel_set.id
        end
      end
    end
  end
end

function panels_init()
  panels = {} -- holds all panels, all of them will be fully loaded
  panels_ids = {} -- holds all panels ids

  -- add default panel set
  local defaultPanels = Panels("client/assets/panels/__default", "__default")
  local success = defaultPanels:json_init()

  if success then
      panels[defaultPanels.id] = defaultPanels
      panels_ids[#panels_ids + 1] = defaultPanels.id
  end
  add_panels_from_dir_rec("client/assets/default_data/panels")
  add_panels_from_dir_rec("panels")

  -- fix config panel set if it's missing
  if not config.panels or not panels[config.panels] then
    if panels["pacci"] then
      config.panels = "pacci"
    else
      config.panels = tableUtils.getRandomElement(panels_ids)
    end
  end

  for _, panel in pairs(panels) do
    panel:load()
  end
end

local function load_panel_img(path, name)
  local img = GraphicsUtil.loadImageFromSupportedExtensions(path .. "/" .. name)
  if not img then
    img = GraphicsUtil.loadImageFromSupportedExtensions("client/assets/panels/__default/" .. name)

    if not img then
      error("Could not find default panel image")
    end
  end

  return img
end

function Panels:loadSheets()
  for color = 1, 8 do
    self.sheets[color] = load_panel_img(self.path, "panel-" .. color)
    assert(self.sheets[color], "Failed to load sheet for color " .. color .. " on panel set " .. self.id)
  end
  local maxRowUsed = 0
  self.sheetConfig = self.animationConfig
  for animationState, config in pairs(self.sheetConfig) do
    if not config.durationPerFrame then
      config.durationPerFrame = 2
    end
    config.totalFrames = config.frames * config.durationPerFrame
    maxRowUsed = math.max(maxRowUsed, config.row)
    if not config.row or config.row <= 0 then
      error("Animation state " .. animationState .. " of panel set " .. self.id .. " specifies an invalid row")
    end
  end

  self.size = self.sheets[1]:getHeight() / maxRowUsed
end

-- 
function Panels:convertSinglesToSheetTexture(images, animationStates)
  local canvas = love.graphics.newCanvas(self.size * 10, self.size * #animationStates,  {dpiscale = images[1]:getDPIScale()})
  if self.size <= 24 then
    -- none of the panels is bigger than 24x24 so we can assume pixel art style panels
    canvas:setFilter("nearest", "nearest")
  end
  canvas:renderTo(function()
    local row = 1
    -- ipairs over a static table so the ordering is definitely consistent
    for _, animationState in ipairs(animationStates) do
      local animationConfig = self.animationConfig[animationState]
      for frameNumber, imageIndex in ipairs(animationConfig.frames) do
        local widthScale = self.size / images[imageIndex]:getWidth()
        local heightScale = self.size / images[imageIndex]:getHeight()
        if heightScale > 1 or widthScale > 1 then
          images[imageIndex]:setFilter("nearest", "nearest")
        end
        love.graphics.draw(images[imageIndex], self.size * (frameNumber - 1), self.size * (row - 1),nil, widthScale, heightScale)
      end
      row = row + 1
    end
  end)

  return canvas
end

local function validateSingleFilesAgainstConfig(imagesByColorAndIndex, animationConfig)
  local configIndexes = {}
  local problems = {}

  for _, config in pairs(animationConfig) do
    for i = 1, #config.frames do
      -- the indexes of the images used for the config are saved here, mark as being in use
      configIndexes[config.frames[i]] = true
    end
  end

  for color = 1, 8 do
    local imagesByIndex = imagesByColorAndIndex[color]
    for index, _ in pairs(configIndexes) do
      if not imagesByIndex[index] then
        problems[#problems+1] = "Failed to find image with index " .. index .. " for color " .. color
      end
    end
  end

  return problems
end

function Panels:loadSingles()
  local panelFiles = fileUtils.getFilteredDirectoryItems(self.path, "file")
  panelFiles = tableUtils.filter(panelFiles, function(f)
    return string.match(f, "panel%d%d+%.")
  end)
  local images = {}
  for color = 1, 8 do
    images[color] = {}

    local files = tableUtils.filter(panelFiles, function(f)
      local start, finish = string.find(f, "panel" .. color .. "%d+%.")
      local lastDotIndex = string.find(f, "%.")
      -- only add them if they aren't pre- or postfixed in some way
      return  start == 1 and finish == lastDotIndex
    end)

    local indexToFile = {}

    local maxIndex = 0
    for i = 1, #files do
      local file = fileUtils.getFileNameWithoutExtension(files[i])
      local index = tonumber(file:sub(7))
      if index then
        maxIndex = math.max(maxIndex, index)
        indexToFile[index] = file
      end
    end

    -- always go to at least 7 because the default single config uses 7 panels
    -- and likewise there are fallbacks up to panel 7
    for i = 1, math.max(maxIndex, 7) do
      if indexToFile[i] or i <= 7 then
        images[color][i] = load_panel_img(self.path, indexToFile[i] or ("panel" .. color .. i))
        if images[color][i] then
          self.size = math.max(images[color][i]:getWidth(), self.size) -- for scaling
        end
      end
    end
  end

  local problems = validateSingleFilesAgainstConfig(images, self.animationConfig)
  if #problems > 0 then
    error("Error loading panel set " .. self.id ..  " at path " .. love.filesystem.getRealDirectory(self.path)
          .. ":\n\t" .. table.concat(problems, "\n\t"))
  end

  -- because config is shared between all colors, we need to establish a fixed order of the configured states
  -- so that row assignments will be consistent across all colors
  local animationStates = shallowcpy(ANIMATION_STATES)
  for _, optionalAnimationState in ipairs(OPTIONAL_ANIMATION_STATES) do
    if self.animationConfig[optionalAnimationState] then
      animationStates[#animationStates+1] = optionalAnimationState
    end
  end

  for color, panelImages in ipairs(images) do
    self.sheets[color] = self:convertSinglesToSheetTexture(panelImages, animationStates)
  end

  for i, animationState in ipairs(animationStates) do
    self.sheetConfig[animationState] =
    {
      row = i,
      durationPerFrame = self.animationConfig[animationState].durationPerFrame or 2,
      frames = #self.animationConfig[animationState].frames
    }
    self.sheetConfig[animationState].totalFrames =
        self.sheetConfig[animationState].frames * self.sheetConfig[animationState].durationPerFrame
  end
end

function Panels:validateConfig()
  for _, animationState in ipairs(ANIMATION_STATES) do
    assert(self.animationConfig[animationState],
      "Panel set " .. self.id .. " at path " .. love.filesystem.getRealDirectory(self.path) ..
     " has to define a frame for animation state " .. animationState)
  end
end

function Panels:load()
  logger.debug("loading panels " .. self.id)

  self:validateConfig()

  self.greyPanel = load_panel_img(self.path, "panel00")
  self.size = self.greyPanel:getWidth()

  self.images.metals = {
    left = load_panel_img(self.path, "metalend0"),
    mid = load_panel_img(self.path, "metalmid"),
    right = load_panel_img(self.path, "metalend1"),
    flash = load_panel_img(self.path, "garbageflash")
  }


  if self.type == "single" then
    self:loadSingles()
  else
    self:loadSheets()
  end

  self.scale = 16 / self.size

  self.quad = love.graphics.newQuad(0, 0, self.size, self.size, self.sheets[1])
  self.displayIcons = {}
  for color = 1, 8 do
    local canvas = love.graphics.newCanvas(self.size, self.size)
    canvas:renderTo(function()
      self:drawPanelFrame(color, "normal", 0, 0)
    end)
    self.displayIcons[color] = canvas
    --fileUtils.saveTextureToFile(self.sheets[color], self.path .. "/panel-" .. color, "png")
    self.batches[color] = love.graphics.newSpriteBatch(self.sheets[color], 100, "stream")
  end
end


------------------------------------------
--[[
  Next section is only to verify 
  that the new system's default settings 
  are 100% identical with the current behaviour
--]]
------------------------------------------

local function shouldFlashForFrame(frame)
  local flashFrames = 1
  flashFrames = 2 -- add config
  return frame % (flashFrames * 2) < flashFrames
end

-- frames to use for bounce animation
local BOUNCE_TABLE = {1, 1, 1, 1,
                2, 2, 2,
                3, 3, 3,
                4, 4, 4}

-- frames to use for garbage bounce animation
local GARBAGE_BOUNCE_TABLE = {2, 2, 2,
                              3, 3, 3,
                              4, 4, 4,
                              1, 1}

-- frames to use for in danger animation
local DANGER_BOUNCE_TABLE = {4, 4, 4,
                              1, 1, 1,
                              2, 2, 2,
                              3, 3, 3,
                              2, 2, 2,
                              1, 1, 1}

local oldDrawImplementation = function(panelSet, panel, x, y, danger_col, col, dangerTimer)
  local draw_frame = 1
  if panel.isGarbage then
    if panel.state == "matched" then
      local flash_time = panel.initial_time - panel.timer
      if flash_time >= panel.frameTimes.FLASH then
        if panel.timer > panel.pop_time then
          if panel.metal then
          else
          end
        elseif panel.y_offset == -1 then
          draw_frame = 1
          -- hardcoded reference to panel 1
          -- GraphicsUtil.drawGfxScaled(panels[self.panels_dir].images.classic[panel.color][1], draw_x, draw_y, 0, 16 / p_w, 16 / p_h)
        end
      end
    end
  else
    if panel.state == "matched" then
      local flash_time = panel.frameTimes.FACE - panel.timer
      if flash_time >= 0 then
        draw_frame = 6
      elseif shouldFlashForFrame(flash_time) == false then
        draw_frame = 1
      else
        draw_frame = 5
      end
    elseif panel.state == "popping" then
      draw_frame = 6
    elseif panel.state == "landing" then
      draw_frame = BOUNCE_TABLE[panel.timer + 1]
    elseif panel.state == "swapping" then
      if panel.isSwappingFromLeft then
        x = x - panel.timer * 4
      else
        x = x + panel.timer * 4
      end
    elseif panel.state == "dead" then
      draw_frame = 6
    elseif panel.state == "dimmed" then
      draw_frame = 7
    elseif panel.fell_from_garbage then
      draw_frame = GARBAGE_BOUNCE_TABLE[panel.fell_from_garbage] or 1
    elseif danger_col[col] then
      draw_frame = DANGER_BOUNCE_TABLE[wrap(1, dangerTimer + 1 + math.floor((col - 1) / 2), #DANGER_BOUNCE_TABLE)]
    else
      draw_frame = 1
    end
  end

  return draw_frame
end

----------------------------------------

local floor = math.floor
local min = math.min
local ceil = math.ceil

local function getGarbageBounceProps(panelSet, panel)
  local conf = panelSet.sheetConfig.garbageBounce
  -- fell_from_garbage counts down from 12 to 0
  if panel.fell_from_garbage > 0 then
    return conf, min(floor((12 - panel.fell_from_garbage) / conf.durationPerFrame) + 1, conf.frames)
  else
    return conf, 1
  end
end

local function getDangerBounceProps(panelSet, panel, dangerTimer)
  local conf = panelSet.sheetConfig.danger
  -- dangerTimer counts up from 0 but top out and getting out of danger force it back to 0
  local frame = ceil(wrap(1, dangerTimer + 1 + floor((panel.column - 1) / 2), conf.durationPerFrame * conf.frames) / conf.durationPerFrame)
  return conf, frame
end

function Panels:getDrawProps(panel, x, y, dangerCol, dangerTimer)
  local conf
  local frame
  local animationName
  if panel.state == "normal" then
    if dangerCol[panel.column] then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "normal"
      -- normal has no timer at the moment, therefore restricted to 1 frame
      conf = self.sheetConfig.normal
      frame = 1
    end
  elseif panel.state == "matched" then
    if panel.isGarbage then
      animationName = "garbagePop"
      conf = self.sheetConfig.garbagePop
      frame = 1
    else
      -- divide between flash and face
      -- matched timer counts down to 0
      if panel.timer <= panel.frameTimes.FACE then
        animationName = "face"
        conf = self.sheetConfig.face
        local faceTime = (panel.frameTimes.FACE - panel.timer)
        -- nonlooping animation that is counting up
        if faceTime < conf.totalFrames then
          -- starting at the beginning of the timer
          -- floor and +1 because the timer starts at 0 (could instead also +1 the timer and ceil)
          frame = floor(faceTime / conf.durationPerFrame) + 1
        else
          -- and then sticking to the final frame for the remainder
          frame = conf.frames
        end
      else
        animationName = "flash"
        conf = self.sheetConfig.flash
        -- matched panels flash until they counted down to panel.frameConstants.FACE
        -- so to find out which frame of flash we're on, add face and subtract the timer
        local flashTime = panel.frameTimes.FLASH + panel.frameTimes.FACE - panel.timer
        frame = floor((flashTime % conf.totalFrames) / conf.durationPerFrame) + 1
      end
    end
  elseif panel.state == "swapping" then
    animationName = "swapping"
    conf = self.sheetConfig.swapping
    frame = 1
    if panel.isSwappingFromLeft then
      x = x - panel.timer * 4
    else
      x = x + panel.timer * 4
    end
  elseif panel.state == "popped" then
    -- draw nothing
    return
  elseif panel.state == "landing" then
    animationName = "landing"
    conf = self.sheetConfig.landing
    -- landing always counts down from 12, ending at 0
    frame = min(floor((12 - panel.timer) / conf.durationPerFrame) + 1, conf.frames)
  elseif panel.state == "hovering" then
    if panel.fell_from_garbage and self.sheetConfig.garbageBounce then
      animationName = "garbageBounce"
      conf, frame = getGarbageBounceProps(self, panel)
    elseif dangerCol[panel.column] and self.sheetConfig.garbageBounce then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "hovering"
      conf = self.sheetConfig.hovering
      frame = 1
    end
    -- hover is too short to reasonably animate (as short as 3 frames)
    -- if conf.frames == 1 then
    --   frame = 1
    -- else
    --   -- we don't really know if this started with hover or garbage hover time
    --   -- so gotta do it this way
    --   frame = ceil(panel.timer / conf.durationPerFrame)
    --   frame = math.abs(frame - conf.frames) + 1
    -- end
  elseif panel.state == "falling" then
    if panel.fell_from_garbage and self.sheetConfig.garbageBounce then
      animationName = "garbageBounce"
      conf, frame = getGarbageBounceProps(self, panel)
    elseif dangerCol[panel.column] then
      animationName = "danger"
      conf, frame = getDangerBounceProps(self, panel, dangerTimer)
    else
      animationName = "falling"
      conf = self.sheetConfig.falling
      -- falling has no timer at the moment, therefore restricted to 1 frame
      frame = 1
    end
  elseif panel.state == "popping" then
    animationName = "popping"
    -- popping runs at the end of its timer, not at the start
    -- 6 is the hard limit for when it starts to run because it is the lowest preset value for pop time
    if panel.timer > 6 or self.sheetConfig.popping.frames == 1 then
      -- before that, popping will keep rendering the final face frame
      conf = self.sheetConfig.face
      frame = conf.frames
    else
      conf = self.sheetConfig.popping
      frame = floor((6 - panel.timer) / conf.durationPerFrame) + 1
    end
  elseif panel.state == "dimmed" then
    animationName = "dimmed"
    conf = self.sheetConfig.dimmed
    frame = 1
  elseif panel.state == "dead" then
    animationName = "dead"
    conf = self.sheetConfig.dead
    frame = 1
  end

  -- verify that the default frame we get from the new config and the old frame are the same
  if DEBUG_ENABLED and self.animationConfig == DEFAULT_PANEL_ANIM and conf ~= self.sheetConfig.flash then
  -- flash in particular started on a different frame depending on level
  -- on levels with FLASH % 4 == 0 it would start with frame 5
  -- on levels with FLASH % 4 == 2 it would start with frame 1
  -- new baseline will be for it to always start with frame 5 to communicate earlier that the panels matched
  -- with level 8 (FLASH % 4 == 0), this condition can removed and it all validates
  -- but with level 10 (FLASH % 4 == 2), it fails on every single flash

    local oldFrame = oldDrawImplementation(self, panel, x, y, dangerCol, panel.column, dangerTimer)
    -- only assert if the default anim defines that frame
    if DEFAULT_PANEL_ANIM[animationName].frames[frame] then
      assert(DEFAULT_PANEL_ANIM[animationName].frames[frame] == oldFrame)
    else
      -- otherwise it's going to be a custom animation that wasn't possible before
    end
  end

  return conf, frame, x, y
end

-- adds the panel to a batch for later drawing
-- x, y: relative coordinates on the stack canvas
-- clock: Stack.clock to calculate animation frames
-- danger: nil - no danger, false - regular danger, true - panic
-- dangerTimer: remaining time for which the danger animation continues 
function Panels:addToDraw(panel, x, y, stackScale, danger, dangerTimer)
  if panel.color == 9 then
    love.graphics.draw(self.greyPanel, x * stackScale, y * stackScale, 0, self.scale * stackScale)
  else
    local batch = self.batches[panel.color]
    local conf, frame
    conf, frame, x, y = self:getDrawProps(panel, x, y, danger, dangerTimer)

    self.quad:setViewport((frame - 1) * self.size, (conf.row - 1) * self.size, self.size, self.size)
    -- scale / 3 because for the current standard size of 16
    batch:add(self.quad, x * stackScale, y * stackScale, 0, self.scale * stackScale)
  end
end

-- draws all panel draws that have been added to the batch thus far
function Panels:drawBatch()
  for color = 1, 8 do
    love.graphics.draw(self.batches[color])
  end
end

-- clears the last batch
function Panels:prepareDraw()
  for color = 1, 8 do
    self.batches[color]:clear()
  end
end

-- draws the first frame of a panel's state and color in the specified size at the passed location
function Panels:drawPanelFrame(color, state, x, y, size)
  local sheetConfig = self.sheetConfig[state]
  -- always draw the first frame
  self.quad:setViewport(0, (sheetConfig.row - 1) * self.size, self.size, self.size)
  local scale = (size or self.size) / self.size
  GraphicsUtil.drawQuad(self.sheets[color], self.quad, x, y, 0, scale)
end

return Panels
