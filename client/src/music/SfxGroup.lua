local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local FileUtils = require("client.src.FileUtils")

-- A group of SFX that belong together
-- Only 1 SFX in the group may play at the same time
-- playing another SFX from the group will interrupt other ongoing SFX
---@class SfxGroup
---@field fileGroup FileGroup
---@field sources love.Source[]
---@field volumeMultiplier number
---@field lastPlaying love.Source
---@overload fun(fileGroup: FileGroup, volumeMultiplier: number?): SfxGroup
local SfxGroup = class(
---@param fileGroup FileGroup
function(self, fileGroup, volumeMultiplier)
  self.fileGroup = fileGroup
  self.volumeMultiplier = volumeMultiplier or 1

  -- fileGroup.indexedFiles may have gaps; this may be relevant to a SfxGroupGroup but not for a SfxGroup, just use all files
  local continuouslyIndexedFiles = tableUtils.toContinuouslyIndexedTable(fileGroup.indexedFiles)
  self.sources = {}
  -- if there are gaps in indexedFiles, tough luck, they'll get ignored
  for i, filename in ipairs(continuouslyIndexedFiles) do
    self.sources[i] = love.audio.newSource(fileGroup.path .. "/" .. filename, "static")
  end
end)

function SfxGroup:setVolume(volume)
  for _, source in ipairs(self.sources) do
    source:setVolume(volume * self.volumeMultiplier)
  end
end

function SfxGroup:play()
  if self.lastPlaying then
    self.lastPlaying:stop()
  end

  self.lastPlaying = self.sources[math.random(#self.sources)]
  self.lastPlaying:play()
end

function SfxGroup:isPlaying()
  if not self.lastPlaying then
    return false
  else
    return self.lastPlaying:isPlaying()
  end
end

function SfxGroup:stop()
  if self.lastPlaying then
    self.lastPlaying:stop()
  end
end

function SfxGroup:clone()
---@diagnostic disable-next-line: param-type-mismatch
  local clone = setmetatable({}, SfxGroup)
  clone.fileGroup = self.fileGroup
  clone.volumeMultiplier = self.volumeMultiplier
  clone.sources = {}
  for i, source in ipairs(self.sources) do
    clone.sources[i] = source:clone()
  end

  return clone
end

return SfxGroup