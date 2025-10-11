---@meta

---@class love.Quad
local Quad = {}

---Sets the texture coordinates according to a viewport within the Quad's texture.
---Available in Love2D 12.0. This method allows you to change the Quad's viewport after creation.
---@param x number The top-left position along the x-axis.
---@param y number The top-left position along the y-axis.
---@param w number The width of the viewport.
---@param h number The height of the viewport.
---@param sw? number Optional new reference width, the width of the Texture. Must be greater than 0 if set.
---@param sh? number Optional new reference height, the height of the Texture. Must be greater than 0 if set.
function Quad:setViewport(x, y, w, h, sw, sh) end

return Quad