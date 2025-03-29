-- Taken from https://stackoverflow.com/questions/19984291/pure-lua-hashing-method
-- need to figure out license or use a different one

local bit = require 'bit'
local ffi = require 'ffi'

local type = type

local band, bnot, bswap, bxor, rol, ror, rshift, tobit =
  bit.band, bit.bnot, bit.bswap, bit.bxor, bit.rol, bit.ror, bit.rshift, bit.tobit

local min, max = math.min, math.max

local C = ffi.C
local istype, new, fill, copy, cast, sizeof, ffi_string =
  ffi.istype, ffi.new, ffi.fill, ffi.copy, ffi.cast, ffi.sizeof, ffi.string

local sha256 = {}

ffi.cdef [[
  void *malloc(size_t size);
  void free(void *ptr);
]]

local ctHashState = ffi.typeof 'uint32_t[8]'
local cbHashState = ffi.sizeof(ctHashState)
local ctBlock = ffi.typeof 'uint32_t[64]'
local cbBlock = ffi.sizeof(ctBlock)
local ctpu8 = ffi.typeof 'uint8_t *'
local ctpcu8 = ffi.typeof 'const uint8_t *'
local ctpu32 = ffi.typeof 'uint32_t *'
local ctpu64 = ffi.typeof 'uint64_t *'

-- This struct is used by the 'preprocess' iterator function.  It keeps track
-- of the end of the input string + the total input length in bits + a pointer
-- to the block buffer (where expansion takes place.)
local ctBlockIter
local cmtBlockIter = {}
function cmtBlockIter.__sub(a, b)
  if istype(ctBlockIter, a) then a = a.limit end
  if istype(ctBlockIter, b) then b = b.limit end
  return a - b
end
function cmtBlockIter:__tostring()
  return string.format("<ctBlockIter: limit=%s; keyLength=%s>",
                       tostring(self.base), tostring(self.keyLength))
end
ctBlockIter = ffi.metatype([[
  struct {
    const uint8_t *limit;
    uint32_t *blockBuffer;
    uint64_t keyLength;
  }
]], cmtBlockIter)

-- Initial state of the hash
local init_h = new('const uint32_t[8]', {
   0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
   0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
})

-- Constants used in the add step of the compression function
local k = new('const uint32_t[64]', {
   0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
   0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
   0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
   0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
   0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
   0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
   0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
   0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
   0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
   0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
   0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
   0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
   0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
   0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
   0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
   0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
})

-- Expand block from 512 to 2048 bits
local function expand(w)
  for i = 16, 63 do
    local s0 = bxor(ror(w[i-15], 7), ror(w[i-15], 18), rshift(w[i-15], 3))
    local s1 = bxor(ror(w[i-2], 17), ror(w[i-2], 19), rshift(w[i-2], 10))
    w[i] = w[i-16] + s0 + w[i-7] + s1
  end
end

-- Process one expanded block and update the hash state
local function compress(hh, w)
  local a, b, c, d, e, f, g, h =
    hh[0],hh[1],hh[2],hh[3],hh[4],hh[5],hh[6],hh[7]
  for i = 0, 63 do
    local S1 = bxor(ror(e, 6), ror(e, 11), ror(e, 25))
    local ch = bxor(band(e, f), band(bnot(e), g))
    local t = tobit(h + S1 + ch + k[i] + w[i])
    local S0 = bxor(ror(a, 2), ror(a, 13), ror(a, 22))
    local maj = bxor(band(a, bxor(b, c)), band(b, c))
    a, b, c, d, e, f, g, h =
      tobit(t + S0 + maj),
      a, b, c,
      tobit(d + t),
      e, f, g
  end
  hh[0],hh[1],hh[2],hh[3],hh[4],hh[5],hh[6],hh[7] =
    hh[0]+a, hh[1]+b, hh[2]+c, hh[3]+d,
    hh[4]+e, hh[5]+f, hh[6]+g, hh[7]+h
end

-- Take a 512-bit chunk from the input.
-- If it is the final chunk, also add padding
local keyLengthOfs = ffi.offsetof(ctBlockIter, 'keyLength')
local function nextBlock(state, input)
  local w = state.blockBuffer
  local cLen = min(state - input, 64)
  if cLen < -8 then return nil end
  fill(w, 256, 0)
  copy(w, input, max(0, cLen))
  if 0 <= cLen and cLen < 64 then
    copy(cast(ctpu8, w)+cLen, '\128', 1)
  end
  for i = 0, 15 do w[i] = bswap(w[i]) end
  if cLen <= (64-8-1) then
    copy(cast(ctpu64, w) + 7, cast(ctpu8, state) + keyLengthOfs, 8)
    w[14], w[15] = w[15], w[14]
  end
  input = input + 64
  return input
end

-- Iterator that yields one block (possibly padded) at a time from the input
local function preprocess(input, len, w)
  len = len or (type(input) == 'string' and #input or sizeof(input))
  input = cast(ctpu8, input)
  local it = new(ctBlockIter)
  it.blockBuffer = w
  it.limit = input+len
  it.keyLength = len*8
  return nextBlock, it, input
end

-- Compute a binary hash (32-byte binary string) from the input
function sha256.binFromBin(input, len)
  local h = new(ctHashState)
  local w = cast(ctpu32, C.malloc(cbBlock))
  copy(h, init_h, cbHashState)
  for _ in preprocess(input, len, w) do
    expand(w)
    compress(h, w)
  end
  for i = 0, 7 do h[i] = bswap(h[i]) end
  C.free(w)
  return ffi_string(h, 32)
end

local hexDigits = new('char[16]', "0123456789abcdef")
local hexOut = new('char[65]')

-- Compute the hash and convert to hexadecimal
function sha256.hexFromBin(input, len)
  local h = new(ctHashState)
  local w = cast(ctpu32, C.malloc(cbBlock))
  copy(h, init_h, cbHashState)
  for _ in preprocess(input, len, w) do
    expand(w)
    compress(h, w)
  end
  for i = 0, 7 do
    local w = h[i]
    for j = 0, 3 do
      w = rol(w, 8)
      hexOut[i*8 + j*2] = hexDigits[band(rshift(w, 4), 15)]
      hexOut[i*8 + j*2 + 1] = hexDigits[band(w, 15)]
    end
  end
  C.free(w)
  return ffi_string(hexOut, 64)
end

return sha256