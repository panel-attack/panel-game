local class = require("common.lib.class")
local KeyDataEncoding = require("common.data.KeyDataEncoding")

local dummyConfig = { ['DummyConfig'] = { Log = 4 } }

DummyCpu = class(function(self, stack)
  self.name = "DummyCpu"
  self.stack = stack
end)

function DummyCpu.getInput(self)
  return KeyDataEncoding.base64encode[21]
end

function DummyCpu.setConfig(self, config)
  self.config = dummyConfig
  return
end

function DummyCpu.getConfigs(self)
  return dummyConfig
end