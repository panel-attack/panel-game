local Stage = require("client.src.mods.Stage")
local consts = require("common.engine.consts")
local tableUtils = require("common.lib.tableUtils")
local logger = require("common.lib.logger")
local ModLoader = require("client.src.mods.ModLoader")

local StageLoader = {}

-- initializes the stage class
function StageLoader.initStages()
  allStages, stageIds, stages, visibleStages = ModLoader.initMods(Stage)

  StageLoader.loadBundleThumbnails()
end

function StageLoader.loadBundleThumbnails()
-- bundles without stage thumbnail display up to 4 thumbnails of their substages
  -- there is no guarantee the substages had been loaded previously so do it after everything got preloaded
  for _, stage in pairs(allStages) do
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
    stageId = tableUtils.getRandomElement(visibleStages)
  end

  return stageId
end

function StageLoader.resolveBundle(stageId)
  while stages[stageId]:is_bundle() do
    local subMods = stages[stageId]:getSubMods()
    stageId = tableUtils.getRandomElement(subMods).id
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