---@meta

---Extend the existing love.graphics module with Love2D 12.0 function signatures

---@class love.graphics : love.graphics

---Gets the currently set Font.
---Love2D 12.0 version - returns Font object.
---@return love.Font font The currently set Font object.
function love.graphics.getFont() end

---Gets the height of the currently set Font.
---Love2D 12.0 version - no parameters needed.
---@return number height The height of the Font in pixels.
function love.graphics.getFont():getHeight() end

---@class love.Font : love.Font

---Gets the height of the Font.
---Love2D 12.0 version - no parameters needed.
---@return number height The height of the Font in pixels.
function love.Font:getHeight() end