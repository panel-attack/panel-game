---@param v number
---@return (1 | -1)
function math.sign(v)
	return (v >= 0 and 1) or -1
end

---@param number number
---@param numberOfDecimalPlaces integer
---@return number
function math.round(number, numberOfDecimalPlaces)
  if number == 0 then
    return number
  end
  local multiplier = 10^(numberOfDecimalPlaces or 0)
  if number > 0 then
    return math.floor(number * multiplier + 0.5) / multiplier
  else
    return math.ceil(number * multiplier - 0.5) / multiplier
  end
end

function math.integerAwayFromZero(number)
  if number == 0 then
    return number
  end
  if number > 0 then
    return math.ceil(number)
  else
    return math.floor(number)
  end
end

-- Returns if two floats are equal within a certain number of decimal places
---@param a number
---@param b number
---@param decimalPrecision integer the number of decimal places to compare
---@return boolean equal
function math.floatsEqualWithPrecision(a, b, decimalPrecision)
  assert(type(a) == "number", "floatsEqualWithPrecision expects a number argument for the first argument")
  assert(type(b) == "number", "floatsEqualWithPrecision expects a number argument for the second argument")
  assert(type(decimalPrecision) == "number", "floatsEqualWithPrecision expects a number argument for the third argument")

  local threshold = math.pow(0.1, decimalPrecision)
  local diff = math.abs(a - b) -- Absolute value of difference
  return diff < threshold
end

---@param value number
---@return boolean
function math.isNaN(value)
  return value ~= value
end