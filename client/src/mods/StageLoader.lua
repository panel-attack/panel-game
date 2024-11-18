local Stage = require("client.src.mods.Stage")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local fileUtils = require("client.src.FileUtils")

local StageLoader = {}

-- recursively adds stages from the path given to the passed stages table
function StageLoader.addStagesFromDirectoryRecursively(path, stages)
  local lfs = love.filesystem
  local raw_dir_list = fileUtils.getFilteredDirectoryItems(path)
  for i, v in ipairs(raw_dir_list) do
    local current_path = path .. "/" .. v
    if lfs.getInfo(current_path) and lfs.getInfo(current_path).type == "directory" then
      -- call recursively: facade folder
      StageLoader.addStagesFromDirectoryRecursively(current_path)

      -- init stage: 'real' folder
      local stage = Stage(current_path, v)
      local success = stage:json_init()

      if success then
        if stages[stage.id] ~= nil then
          logger.trace(current_path .. " has been ignored since a stage with this id has already been found")
        else
          stages[stage.id] = stage
        end
      end
    end
  end

  return stages
end

-- Iterates through the stages table and adds the ids of all valid mods to a new stageIds table
-- returns: 
--   stageIds table
--   table of invalid stage bundles
function StageLoader.fillStageIds(stages)
  local invalid = {}
  local stageIds = {}

  for stageId, stage in pairs(stages) do
    -- bundle stage (needs to be filtered if invalid)
    if stage:is_bundle() then
      if StageLoader.validateBundle(stage) then
        stageIds[#stageIds + 1] = stageId
        logger.debug(stage.id .. " (bundle) has been added to the stage list!")
      else
        invalid[#invalid + 1] = stageId -- stage is invalid
        logger.warn(stage.id .. " (bundle) is being ignored since it's invalid!")
      end
    else
      -- normal stage
      stageIds[#stageIds + 1] = stageId
      logger.debug(stage.id .. " has been added to the stage list!")
    end
  end

  -- for consistency while manual sorting is not possible
  table.sort(stageIds, function(a, b)
    return stages[a].path < stages[b].path
  end)

  return stageIds, invalid
end

function StageLoader.validateBundle(stage)
  for i = #stage.sub_stages, 1, -1 do
    local subStage = allStages[stage.sub_stages[i]]
    if subStage and #subStage.sub_stages == 0 then -- inner bundles are prohibited
      logger.trace(stage.id .. " has " .. subStage.id .. " as part of its sub stages.")
    else
      logger.warn(stage.sub_stages[i] .. " is not a valid sub stage of " .. stage.id .. " because it does not  exist or has own sub stages.")
      table.remove(stage.sub_stages, i)
    end
  end

  return #stage.sub_stages >= 2
end

-- all stages are default enabled until they're actively disabled upon which they are added to this blacklist
function StageLoader.loadBlacklist()
  local blacklist = {}
  if love.filesystem.getInfo("stages/blacklist.txt", "file") then
    for line in love.filesystem.lines("stages/blacklist.txt") do
      blacklist[#blacklist+1] = line
    end
  end
  return blacklist
end

function StageLoader.enable(stage, enable)
  if enable and not stages[stage.id] then
    local i = tableUtils.indexOf(StageLoader.blacklist, stage.id)
    table.remove(StageLoader.blacklist, i)
    stages[stage.id] = stage
    stages_ids_for_current_theme[#stages_ids_for_current_theme+1] = stage.id
  elseif not enable and stages[stage.id] then
    local i = tableUtils.indexOf(stages_ids_for_current_theme, stage.id)
    table.remove(stages_ids_for_current_theme, i)
    StageLoader.blacklist[#StageLoader.blacklist+1] = stage.id
    stages[stage.id] = nil
  end
  love.filesystem.write("stages/blacklist.txt", table.concat(StageLoader.blacklist, "\n"))
end

-- initializes the stage class
function StageLoader.initStages()
  allStages = {} -- holds all stages, most of them will not be fully loaded
  stages_ids_for_current_theme = {} -- holds stages ids for the current theme, those stages will appear in the selection

  -- load bundled assets first so they are not ignored in favor of user mods
  StageLoader.addStagesFromDirectoryRecursively("client/assets/default_data/stages", allStages)
  -- load user mods
  StageLoader.addStagesFromDirectoryRecursively("stages", allStages)
  stageIds = StageLoader.fillStageIds(allStages)
  stages = shallowcpy(allStages)
  StageLoader.blacklist = StageLoader.loadBlacklist()
  for _, stageId in ipairs(StageLoader.blacklist) do
    -- blacklisted characters are removed from stages
    -- but we keep them in allStages/stageIds for reference
    stages[stageId] = nil
  end

  if tableUtils.length(stages) == 0 then
    -- fallback for configurations in which all stages have been disabled
    stages = shallowcpy(allStages)
  end

  if love.filesystem.getInfo(themes[config.theme].path .. "/stages.txt") then
    for line in love.filesystem.lines(themes[config.theme].path .. "/stages.txt") do
      line = trim(line) -- remove whitespace
      -- found at least a valid stage in a stages.txt file
      if stages[line] then
        stages_ids_for_current_theme[#stages_ids_for_current_theme + 1] = line
      end
    end
  else
    for _, stageId in ipairs(stageIds) do
      if stages[stageId] and stages[stageId].is_visible then
        stages_ids_for_current_theme[#stages_ids_for_current_theme + 1] = stageId
      end
    end
  end

  if #stages_ids_for_current_theme == 0 then
    -- fallback in case there were no stages left
    stages_ids_for_current_theme = shallowcpy(stageIds)
  end

  -- fix config stage if it's missing
  if not config.stage or (config.stage ~= consts.RANDOM_STAGE_SPECIAL_VALUE and not stages[config.stage]) then
    config.stage = tableUtils.getRandomElement(stages_ids_for_current_theme) -- it's legal to pick a bundle here, no need to go further
  end

  Stage.loadDefaultStage()

  local randomStage = Stage.getRandomStage()
  stageIds[#stageIds+1] = randomStage.id
  stages[randomStage.id] = randomStage

  for _, stage in pairs(allStages) do
    stage:preload()
  end

  StageLoader.loadBundleThumbnails()
end

function StageLoader.loadBundleThumbnails()
-- bundles without stage thumbnail display up to 4 thumbnails of their substages
  -- there is no guarantee the substages had been loaded previously so do it after everything got preloaded
  for _, stage in pairs(stages) do
    if not stage.images.thumbnail then
      if stage:is_bundle() then
        stage.images.thumbnail = stage:createBundleThumbnail()
      else
        error("Can't find a thumbnail for stage " .. stage.id)
      end
    end
  end
end

function StageLoader.resolveStageSelection(stageId)
  if not stageId or not stages[stageId] then
    -- resolve via random selection
    stageId = tableUtils.getRandomElement(stages_ids_for_current_theme)
  end

  return stageId
end

function StageLoader.resolveBundle(stageId)
  while stages[stageId]:is_bundle() do
    stageId = tableUtils.getRandomElement(stages[stageId].sub_stages)
  end

  return stageId
end

function StageLoader.fullyResolveStageSelection(stageId)
  logger.debug("Resolving stageId " .. (stageId or ""))
  stageId = StageLoader.resolveStageSelection(stageId)
  stageId = StageLoader.resolveBundle(stageId)
  logger.debug("Resolved stageId to " .. stageId)
  return stageId
end

return StageLoader