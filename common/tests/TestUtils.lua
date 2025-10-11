-- General testing utilities for Panel Attack tests
-- These functions provide common functionality needed across different test suites

local TestUtils = {}

---Expect an error without tripping Local Lua Debugger
---@param thunk function Function that should throw an error
---@param pattern string|nil Optional pattern to match in the error message
---@return boolean success True if error was caught and pattern matched (if provided)
---@return string errorMessage Error message if test failed
function TestUtils.expectErrorQuiet(thunk, pattern)
  pcall(function() require("lldebugger").stop() end)

  -- run the code in protected mode so we capture the error
  local ok, err = xpcall(thunk, function(e) return e end)

  -- always try to re-enable the debugger; pass false so it doesn't break on re-start
  pcall(function() require("lldebugger").start(false) end)

  if ok then return false, "no error was raised" end
  if pattern and not tostring(err):match(pattern) then
    return false, ("unexpected error: %s"):format(err)
  end
  return true
end

return TestUtils