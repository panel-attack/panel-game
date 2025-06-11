--[[
A library to provide a relative require.
Makes sense to use wherever we have grouped files that assuredly only ever move together.
Otherwise require is probably still better.

MIT License

Copyright (c) 2023 Justin van der Leij

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local function extractPathComponents(path)
  local components = {}
  for component in path:gmatch("[^/]+") do
      table.insert(components, component)
  end

  return components
end

local import = function(path)
  local callerPath = debug.getinfo(2, "S").source:sub(2)

  local pathStack = {}

  if (path:sub(1, 1) == ".") then
      local components = extractPathComponents(callerPath)

      for i = 1, #components - 1 do
          pathStack[i] = components[i]
      end
  end

  local components = extractPathComponents(path)

  for _, component in ipairs(components) do
      if (component == ".") then
          -- Skip
      elseif (component == "..") then
          table.remove(pathStack, #pathStack)
      else
          table.insert(pathStack, component)
      end
  end

  local out = table.concat(pathStack, ".")

  return require(out)
end

return import