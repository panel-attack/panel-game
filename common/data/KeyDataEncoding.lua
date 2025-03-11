-- Not actually for encoding/decoding byte streams as base64.
-- Rather, it's for encoding streams of 6-bit symbols in printable characters.
base64encode = procat("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890+/")
base64decode = {}
for i = 1, 64 do
  local val = i - 1
  base64decode[base64encode[i]] = {}
  local bit = 32
  for j = 1, 6 do
    base64decode[base64encode[i]][j] = (val >= bit)
    val = val % bit
    bit = bit / 2
  end
end

local KeyDataEncoding = {
  base64encode = base64encode,
  base64decode = base64decode,
  left = base64encode[3],
  right = base64encode[2],
  up = base64encode[9],
  down = base64encode[5],
  swap = base64encode[17],
  raise = base64encode[33]
}

return KeyDataEncoding