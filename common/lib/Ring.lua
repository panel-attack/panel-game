local class = require("common.lib.class")

--- A simple class for limiting the amount of memory taken up by transient data (e.g. logs)
---@class Ring
---@field size integer
---@field currentIndex integer
---@field content any[]
local Ring = class(
function(self, size)
  self.size = size
  self.currentIndex = 1
  self.content = table.new(size, 0)
end)

function Ring:push(item)
  self.content[self.currentIndex] = item

  self.currentIndex = self.currentIndex + 1

  if self.currentIndex > self.size then
    self.currentIndex = 1
  end
end

function Ring:__tostring()
  local t = {}
  for i = self.currentIndex + 1, self.currentIndex + self.size do
    local index = wrap(1, i, self.size)
    t[#t+1] = tostring(self.content[index])
  end

  return table.concat(t)
end

return Ring