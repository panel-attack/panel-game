---@meta

---Extend the existing love.data module with Love2D 12.0 function signatures

---@class love.data : love.data

---@alias HashAlgorithm 
---| "md5"
---| "sha1" 
---| "sha224"
---| "sha256"
---| "sha384"
---| "sha512"

---@alias ContainerType
---| "data"
---| "string"

---@alias EncodeFormat
---| "base64"
---| "hex"

---Compute the message digest of a string using a specified hash algorithm.
---Love2D 12.0 version with container type parameter.
---@overload fun(container: "string", hashAlgorithm: HashAlgorithm, string: string): string
---@overload fun(container: "data", hashAlgorithm: HashAlgorithm, string: string): love.Data
---@param container ContainerType The type to return the hash as.
---@param hashAlgorithm HashAlgorithm The hash algorithm to use.
---@param string string The input string to hash.
---@return string|love.Data digest The resulting hash digest.
function love.data.hash(container, hashAlgorithm, string) end

---Encode Data or a string to a Data or string in one of several encoding formats.
---Love2D 12.0 version - when container is "string", returns string.
---@overload fun(container: "string", format: EncodeFormat, sourceData: string|love.Data, linelength?: number): string
---@overload fun(container: "data", format: EncodeFormat, sourceData: string|love.Data, linelength?: number): love.Data  
---@param container ContainerType The type to return the encoded data as.
---@param format EncodeFormat The format to encode the string with.
---@param sourceData string|love.Data The raw data to encode.
---@param linelength? number The maximum line length of the encoded string (only applicable to base64).
---@return string|love.Data encoded The encoded data.
function love.data.encode(container, format, sourceData, linelength) end