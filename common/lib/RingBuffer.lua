local class = require("common.lib.class")
table.new = require("table.new")

--- A simple class for limiting the amount of memory taken up by transient data (e.g. logs)
---@class RingBuffer
---@field size integer
---@field currentIndex integer
---@field content any[]
local RingBuffer = class(
function(self, size)
  self.size = size
  self.currentIndex = 1
  self.content = table.new(size, 0)
end)

function RingBuffer:push(item)
  self.content[self.currentIndex] = item

  self.currentIndex = self.currentIndex + 1

  if self.currentIndex > self.size then
    self.currentIndex = 1
  end
end

function RingBuffer:__tostring()
  local t = {}
  for i = self.currentIndex + 1, self.currentIndex + self.size do
    local index = wrap(1, i, self.size)
    if self.content[index] then
      t[#t+1] = tostring(self.content[index])
    end
  end

  return table.concat(t, "\n")
end

return RingBuffer