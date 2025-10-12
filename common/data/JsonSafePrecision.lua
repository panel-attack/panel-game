-- Helper module to generate JSON-safe precision values for floating-point numbers
-- This ensures that floating-point values survive JSON encode/decode cycles without precision loss
--
-- In practice all Lua implementations use a truncated 14 digit floating point string, we assert this
-- in tests and provide this helper to make sure numbers are truncated, we also double check
-- JSON as we encode it in debug builds
-- We also check that the integers are not too big in practice.

local JsonSafePrecision = {}

---Convert a floating-point number to JSON-safe precision
---@param value number The original floating-point value
---@return number The value rounded to JSON-safe precision
function JsonSafePrecision.toSafePrecision(value)
  -- If it's an integer, check if it's within safe range
  if math.floor(value) == value then
    assert(math.abs(value) <= (2^53), "Integer too large for safe JSON representation: " .. value)
    return value
  end

  -- Use string formatting like Lua's internal number-to-string conversion
  -- This matches how dkjson and Lua actually format floating-point numbers
  local formatted = string.format("%.14g", value)
  local number = tonumber(formatted)
  assert(number)
  return number
end

---Convert a fraction to JSON-safe precision
---@param numerator number
---@param denominator number
---@return number The fraction rounded to JSON-safe precision
function JsonSafePrecision.fractionToSafePrecision(numerator, denominator)
  return JsonSafePrecision.toSafePrecision(numerator / denominator)
end

---Debug validation function to check if a number has too much precision for JSON
---@param value number The number to check
function JsonSafePrecision.assertJsonSafePrecision(value)
  if DEBUG_ENABLED and type(value) == "number" then
    local safeValue = JsonSafePrecision.toSafePrecision(value)
    assert(value == safeValue,
           string.format("Safe precision failed: %.17g vs %.17g",
                        value, safeValue))
  end
end

return JsonSafePrecision